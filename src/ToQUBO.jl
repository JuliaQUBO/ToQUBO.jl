module ToQUBO

# -*- ToQUBO.jl -*-
using Documenter, Logging
using MathOptInterface

# MOI Aliases
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const MOIB = MathOptInterface.Bridges

# const SVF = MOI.SingleVariable - Deprecated since MOI >= 0.10
const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}

const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex
const ZO = MOI.ZeroOne
const OS = MOI.ObjectiveSense
const INT = MOI.Integer

export QUBOModel
export toqubo, isqubo, solvequbo, tojson

function subscript(::Any; var::Union{String, Symbol, Nothing}=nothing)::String
    if var === nothing
        return "?"
    else
        return "$var?"
    end
end

function subscript(i::Int; var::Union{String, Symbol, Nothing}=nothing)::String
    if var === nothing
        return join([(i < 0) ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]])
    else
        return join([var; (i < 0) ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]])
    end
end

function subscript(v::VI; var::Union{String, Symbol, Nothing}=:x)
    if var === nothing
        return subscript(v.value)
    else
        return "$var$(subscript(v.value))"
    end
end

# -*- Supported -*-
include("./supported.jl")

# -*- Posiform -*-
include("./posiform.jl")
using .Posiforms

# -*- VirtualVar -*-
include("./virtualvar.jl")
using .VirtualVars

const VV{S, T} = VirtualVar{S, T}

function subscript(v::VV; var::Union{String, Symbol, Nothing}=:x)
    if var === nothing
        return subscript(v.source, var=v.var)
    else
        return subscript(v.source, var=var)
    end
end

function Base.show(io::IO, v::VirtualVar)
    if v.source === nothing
        print(io, v.var)
    else
        print(io, subscript(v.source, var=v.var))
    end
end

function value(model::MOI.ModelLike, v::VV{VI, T})::Union{T, Nothing} where T
    s = convert(T, 0)
    for (cᵢ, vᵢ) in v
        xᵢ = MOI.get(model, MOI.VariablePrimal(), vᵢ)
        s += cᵢ * xᵢ
    end
    return s
end

# -*- QUBO Model -*-
"""
"""
mutable struct QUBOModel{T <: Any} <: MOIU.AbstractModelLike{T}

    model::MOIU.Model{T}
    varvec::Vector{VV{VI, T}}
    source::Dict{VI, VV{VI, T}}
    target::Dict{VI, VV{VI, T}}
    cache::Dict{Set{VI}, Posiform{VI, T}}
    quantum::Bool
    Eₒ::Posiform{VI, T}
    Eᵢ::Posiform{VI, T}
    E::Posiform{VI, T}
    slack::Int

    function QUBOModel{T}(; quantum::Bool=false) where T
        return new{T}(
            MOIU.Model{T}(),
            Vector{VV{VI, T}}(),
            Dict{VI, VV{VI, T}}(),
            Dict{VI, VV{VI, T}}(),
            Dict{Set{VI}, Posiform{VI, T}}(),
            quantum,
            Posiform{VI, T}(),
            Posiform{VI, T}(),
            Posiform{VI, T}(),
            0
        )
    end
end

"""
"""
function addvar(model::QUBOModel{T}, source::Union{VI, Nothing}, bits::Int; offset::Int=0, var::Symbol=:x)::VV{VI, T} where T

    target = MOI.add_variables(model.model, bits)

    if source === nothing
        model.slack += 1
        var = Symbol(subscript(model.slack, var=var))
    else
        var = :x
    end

    v = VV{VI, T}(bits, target, source, offset=offset, var=var)

    for vᵢ in target
        MOI.add_constraint(model.model, vᵢ, ZO())
        MOI.set(model.model, MOI.VariableName(), vᵢ, subscript(vᵢ, var=var))
        model.target[vᵢ] = v
    end

    push!(model.varvec, v)

    return v
end

"""
"""
function addslack(model::QUBOModel{T}, bits::Int; offset::Int=0, var::Symbol=:s)::VV{VI, T} where T
    return addvar(model, nothing, bits, offset=offset, var=var)
end

"""
"""
function expand!(model::QUBOModel{T}, var::VI, bits::Int; offset::Int=0)::VV{VI, T} where T
    model.source[var] = addvar(model, var, bits, offset=offset)
end

"""
"""
function expand(model::QUBOModel{T}, var::VI, bits::Int; offset::Int=0)::VV{VI, T} where T
    expand!(model, var, bits, offset=offset)
    return model.source[var]
end

"""
"""
function mirror!(model::QUBOModel{T}, var::VI)::VV{VI, T} where T
    expand!(model, var, 1)
end

"""
"""
function mirror(model::QUBOModel{T}, var::VI)::VV{VI, T} where T
    mirror!(model, var)
    return model.source[var]
end

"""
"""
function isqubo(model::QUBOModel)::Bool
    return isqubo(model.model)
end

"""
"""
function vars(model::QUBOModel{T})::Vector{VV{VI, T}} where T
    return Vector{VV{VI, T}}(model.varvec)
end

"""
"""
function slackvars(model::QUBOModel{T})::Vector{VV{VI, T}} where T
    return Vector{VV{VI, T}}([v for v in model.varvec if isslack(v)])
end
    
# -*- -*-

"""
"""
function Base.show(io::IO, s::Set{VI})
    if isempty(s)
        return print(io, "∅")
    else
        return print(io, join([subscript(sᵢ) for sᵢ in s], " "))
    end
end


# -*- Penalty Computation -*- 
"""
"""
function penalty(p::Posiform)
    return sum(abs(v) for (k, v) in p if !isempty(k))
end

"""
"""
function penalty(p::Posiform, ::Posiform)
    return sum(abs(v) for (k, v) in p if !isempty(k))
end

"""
"""
function penalty(ρ::T, ::Posiform{S, T}) where {S, T}
    return ρ
end

@doc raw"""
    reduce_degree(model::QUBOModel{T}, p::Posiform{S, T}; tech::Symbol=:min)::Posiform{S, T} where {S, T}

From [1]

Assume that $x, y, z \in \mathbb{B}$. Then the following equivalences hold:
    $$x y = z \iff x y - 2 x z - 2 y z + 3 z = 0$$
and
    $$x y \neq z \iff x y - 2 x z - 2 y z + 3 z > 0$$



"""
function reduce_degree(model::QUBOModel{T}, p::Posiform{S, T}; tech::Symbol=:min)::Posiform{S, T} where {S, T}
    if p.degree <= 2
        return copy(p)
    else
        q = Posiform{S, T}()

        for (tᵢ, cᵢ) in p
            if length(tᵢ) >= 3
                q += reduce_term(model, tᵢ, cᵢ, tech=tech)
            else
                q[tᵢ] += c
            end
        end
    
        return q
    end
end

"""

tech
    :sub (Substitution)
    :min (Minimum Selection)
"""
function reduce_term(model::QUBOModel{T}, t::Set{S}, c::T; tech::Symbol=:min)::Posiform{S, T} where {S, T}
    if length(t) <= 2
        return Posiform{S, T}(t => c)    
    elseif haskey(model.cache, t)
        return c * model.cache[t]
    else
        if tech === :sub
            # -*- Reduction by Substitution -*-
            w = addslack(model, 1, offset=0, var=:w)

            # Here we take two variables out "at random", not good
            # I suggest some function `pick_two(model, t, cache, ...)`
            # choose based on cached reduction results
            x, y, z... = t 

            α = convert(T, 2) # TODO: How to compute α? (besides α > 1)

            r = reduce_term(model, Set{S}([w, z...]), 1, tech=tech)
            s = Posiform{S, T}([x, y] => 1, [x, w] => -2, [y, w] => -2, [w] => 3)

            p = c * (r + α * s)
        elseif tech === :min
            # -*- Reduction by Minimum Selection -*-
            w = addslack(model, 1, offset=0)

            # TODO: Read comment above about this construct
            x, y, z... = t

            if c < 0
                r = reduce_term(model, Set{S}([w, z...]), c, tech=tech)
                s = Posiform{S, T}([x, w] => c, [y, w] => c, [w] => -2 * c)
                
                p = r + s
            else
                rˣ = reduce_term(model, Set{S}([x, z...]), c, tech=tech)
                rʸ = reduce_term(model, Set{S}([y, z...]), c, tech=tech)
                rᶻ = reduce_term(model, Set{S}([z...]), -c, tech=tech)
                rʷ = reduce_term(model, Set{S}([w, z...]), c, tech=tech)
                s = Posiform{S, T}([x, w] => c, [y, w] => c, [x, y] => c, [x] => -c, [y] => -c, [w] => -c, [] => c)
                
                p = rˣ + rʸ + rᶻ + rʷ + s
            end
        else
            error("Unknown reduction technique '$tech'")
        end

        model.cache[t] = p

        return p
    end
end

"""
"""
function toqubo(model::MOI.ModelLike; quantum::Bool=false)::QUBOModel

    T = Float64 # TODO: Use MOIU.Model{T} where T ??

    # -*- Support Validation -*-
    supported_objective(model)
    supported_constraints(model)

    # -*- Create QUBO Model -*-
    # This allows one to use MOI.copy_to afterwards
    qubo = QUBOModel{T}(quantum=quantum)

    # -*- Variable Analysis -*-

    # Vector of all model variables
    X = Vector{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Vectors of Binary, Integer and Real Variables (Bounded)
    B = Vector{VI}()
    I = Vector{VI}()
    R = Vector{VI}()

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, ZO}())
        # -*- Binary Variable 😄 -*-
        push!(B, MOI.get(model, MOI.ConstraintFunction(), cᵢ))
    end

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, INT}())
        # -*- Integer Variable
        push!(I, MOI.get(model, MOI.ConstraintFunction(), cᵢ))
    end

    # Unbounded Variables
    U = setdiff(X, B, R, I)

    for bᵢ in B
        # Create Virtual Variable in QUBO Model
        mirror!(qubo, bᵢ)
    end

    # TODO: bit size heuristics
    bits = 3

    for uᵢ in U
        @warn "Expanding variable $uᵢ with $bits bits according to no reasonable criteria"
        # This expansion could rely on VariableIndex-in-Interval constraints.
        # Quadratures ??
        expand!(qubo, uᵢ, bits)
    end

    # -*- Objective Analysis -*-

    F = MOI.get(model, MOI.ObjectiveFunctionType())

    # -*- Objective Function Posiform -*-

    if F === VI
        # -*- Single Variable -*-
        x = MOI.get(model, MOI.ObjectiveFunction{F}())

        for (xᵢ, cᵢ) in qubo.source[x] # TODO: enhance syntax
            qubo.Eₒ[xᵢ] += cᵢ
        end

    elseif F === SAF{T}
        # -*- Affine Terms -*-
        f = MOI.get(model, MOI.ObjectiveFunction{F}())

        for aᵢ in f.terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            for (xᵢⱼ, dⱼ) in qubo.source[xᵢ] # TODO: enhance syntax
                qubo.Eₒ[xᵢⱼ] += cᵢ * dⱼ
            end
        end

        # Constant
        qubo.Eₒ += f.constant

    elseif F === SQF{T}
        # -*- Affine Terms -*-
        f = MOI.get(model, MOI.ObjectiveFunction{F}())

        # Quadratic Terms
        for Qᵢ in f.quadratic_terms
            cᵢ = Qᵢ.coefficient
            xᵢ = Qᵢ.variable_1
            yᵢ = Qᵢ.variable_2

            for (xᵢⱼ, dⱼ) in qubo.source[xᵢ] # TODO: enhance syntax
                for (yᵢₖ, dₖ) in qubo.source[yᵢ] # TODO: enhance syntax
                    zⱼₖ = Set{VI}([xᵢⱼ, yᵢₖ])
                    qubo.Eₒ[zⱼₖ] += cᵢ * dⱼ * dₖ
                end
            end
        end

        for aᵢ in f.affine_terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            for (xᵢⱼ, dⱼ) in qubo.source[xᵢ] # TODO: enhance syntax
                qubo.Eₒ[xᵢⱼ] += cᵢ * dⱼ
            end
        end

        # Constant
        qubo.Eₒ += f.constant
    else
        error("I Don't know how to deal with objective functions of type '$F'")
    end

    # * Objective Gap *
    ρ = penalty(qubo.Eₒ)

    # -*- Constraint Analysis -*-

    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if F === VI
            # -*- Single Variable -*-
            if S === ZO
                continue # These were already accounted for..
            else
                error("Panic! I don't know how to deal with non-binary constraints over variables (yet...)")
            end

        elseif F === SAF{T}
            # -*- Scalar Affine Function -*-
            if S === EQ{T} # Ax = b :)
                for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                    rᵢ = Posiform{VI, T}()

                    Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                    bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).value

                    for aⱼ in Aᵢ.terms
                        cⱼ = aⱼ.coefficient
                        vⱼ = aⱼ.variable

                        for (vⱼₖ, dₖ) in qubo.source[vⱼ] # TODO: enhance syntax
                            rᵢ[vⱼₖ] += cⱼ * dₖ
                        end 
                    end

                    qᵢ = reduce_degree(qubo, (rᵢ - bᵢ) ^ 2)
                    ρᵢ = penalty(ρ, qᵢ)
                    qubo.Eᵢ += ρᵢ * qᵢ
                end

            elseif S === LT{T} # Ax <= b :(
                for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                    rᵢ = Posiform{VI, T}()

                    Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                    bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).upper

                    for aⱼ in Aᵢ.terms
                        cⱼ = aⱼ.coefficient
                        vⱼ = aⱼ.variable

                        for (vⱼₖ, dₖ) in qubo.source[vⱼ] # TODO: enhance syntax
                            rᵢ[vⱼₖ] += cⱼ * dₖ
                        end
                    end

                    # -*- Introduce Slack Variable -*-
                    sᵢ = Posiform{VI, T}()

                    # TODO: Heavy Inference going on!
                    bits = ceil(Int, log(2, bᵢ))

                    for (sⱼ, dⱼ) in addslack(qubo, bits)
                        sᵢ[sⱼ] += dⱼ
                    end

                    qᵢ = reduce_degree(qubo, (rᵢ + sᵢ - bᵢ) ^ 2)
                    ρᵢ = penalty(ρ, qᵢ)
                    qubo.Eᵢ += ρᵢ * qᵢ
                end

            elseif S === GT{T} # Ax >= b :(
                for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                    rᵢ = Posiform{VI, T}()

                    Aᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                    bᵢ = MOI.get(model, MOI.ConstraintSet(), cᵢ).lower

                    for aⱼ in Aᵢ.terms
                        cⱼ = aⱼ.coefficient
                        vⱼ = aⱼ.variable

                        for (vⱼₖ, dₖ) in qubo.source[vⱼ] # TODO: enhance syntax
                            rᵢ[vⱼₖ] += cⱼ * dₖ
                        end
                    end

                    # -*- Introduce Slack Variable -*-
                    sᵢ = Posiform{VI, T}()

                    # TODO: Heavy Inference going on!
                    # Hmmm... I think its actually ok...
                    
                    # NO! I'm missing non-integer stuff :(
                    bits = ceil(Int, log(2, bᵢ))

                    for (sⱼ, dⱼ) in addslack(qubo, bits)
                        sᵢ[sⱼ] += dⱼ
                    end

                    qᵢ = reduce_degree(qubo, (rᵢ - sᵢ - bᵢ) ^ 2)
                    ρᵢ = penalty(ρ, qᵢ)
                    qubo.Eᵢ += ρᵢ * qᵢ
                end

            else
                error("Panic! I'm confused with this kind of constraint set: '$S'")
            end
        else
            error("Unkown Constraint Type $F")
        end
    end

    # -*- Objective Function Assembly -*-
    sense = MOI.get(model, OS())

    # p (objective)
    # q (constraints with penalties)
    if sense === MOI.MAX_SENSE
        if qubo.quantum
            qubo.E = qubo.Eᵢ - qubo.Eₒ
            MOI.set(qubo.model, OS(), MOI.MIN_SENSE)
        else
            qubo.E = qubo.Eₒ - qubo.Eᵢ
            MOI.set(qubo.model, OS(), MOI.MAX_SENSE)
        end
    elseif sense === MOI.MIN_SENSE
        qubo.E = qubo.Eₒ + qubo.Eᵢ
        MOI.set(qubo.model, OS(), MOI.MIN_SENSE)
    end

    qubo.E /= maximum(abs.(values(qubo.E)))

    Q = []
    a = []
    b = convert(T, 0)

    for (xᵢ, cᵢ) in qubo.E
        n = length(xᵢ)
        if n == 0
            b += cᵢ
        elseif n == 1
            push!(a, SAT{T}(cᵢ, xᵢ...))
        elseif n == 2
            push!(Q, SQT{T}(cᵢ, xᵢ...))
        else
            error("Degree reduction failed")
        end
    end

    MOI.set(
        qubo.model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )

    return qubo   
end


"""
    function isqubo(model::MOI.ModelLike)::Bool

Tells if `model` is ready as QUBO Model. A few conditions must be met:
    1. All variables must be binary (VariableIndex-in-ZeroOne)
    2. No other constraints are allowed
    3. The objective function must be either ScalarQuadratic, ScalarAffine or VariableIndex
"""
function isqubo(model::MOI.ModelLike)::Bool
    
    T = Float64 # TODO?

    F = MOI.get(model, MOI.ObjectiveFunctionType()) 
    
    if !(F === SQF{T} || F === SAF{T} || F === VI)
        return false
    end

    # List of Variables
    v = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if !(F === VI && S === ZO)
            # Non VariableIndex-in-ZeroOne Constraint
            return false
        else
            for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                vᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                
                # Account for variable as binary
                delete!(v, vᵢ)
            end

            if !isempty(v)
                # Some variable is not covered by binary constraints
                return false
            end
        end
    end

    return true
end

function solvequbo(qubo::QUBOModel{T}; model::MOI.ModelLike)::Vector{Pair{VV{VI, T}, T}} where T    
    varmap = MOI.copy_to(model, qubo.model)

    MOI.optimize!(model)

    Vector{Pair{VV{VI, T}, T}}([v => sum(cᵢ * MOI.get(model, MOI.VariablePrimal(), varmap[vᵢ]) for (vᵢ, cᵢ) in v) for v in vars(qubo)])
end

function tojson(qubo::QUBOModel{T})::String where T
    terms = Vector{String}()

    for (t, c) in qubo.E
        x = [i.value for i in t]
        if length(x) == 0
            term ="\"\":$c"
        elseif length(x) == 1
            i, = x
            term = "\"$i $i\":$c"
        elseif length(x) == 2
            i, j = x
            term = "\"$i $j\":$c"
        else
            error("Invalid QUBO Model (degree >= 3)") 
        end

        push!(terms, term)
    end

    return "{$(join(terms, ","))}"
end

end # module