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

export QUBOModel
export toqubo, isqubo

# -*- Supported -*-
include("./supported.jl")

# -*- Posiform -*-
include("./posiform.jl")
using .Posiforms

# -*- VirtualVar -*-
include("./virtualvar.jl")
using .VirtualVars

const VV{S, T} = VirtualVar{S, T}

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
    cache::Dict{Set{S}, Posiform{S, T}}
    quantum::Bool

    function QUBOModel{T}(; quantum::Bool=false) where T
        model = MOIU.Model{T}()
        varvec = Vector{VV{VI, T}}()
        source = Dict{VI, VV{VI, T}}()
        target = Dict{VI, VV{VI, T}}()
        cache = Dict{Set{S}, Posiform{S, T}}()
        return new{T}(model, varvec, source, target, cache, quantum)
    end
end

"""
"""
function addvar(model::QUBOModel{T}, source::Union{VI, Nothing}, bits::Int; offset::Int=0)::VV{VI, T} where T

    target = MOI.add_variables(model.model, bits)

    v = VV{VI, T}(bits, target, source, offset=offset)

    if source === nothing
        x = "s"
    else
        x = "x"
    end

    for vᵢ in target
        MOI.add_constraint(model.model, vᵢ, ZO())
        MOI.set(model.model, MOI.VariableName(), vᵢ, subscript(vᵢ, var=x))
        model.target[vᵢ] = v
    end

    push!(model.varvec, v)

    return v
end

"""
"""
function addslack(model::QUBOModel{T}, bits::Int; offset::Int=0)::VV{VI, T} where T
    return addvar(model, nothing, bits, offset=offset)
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
    subscript(v::VI)

Adds support for VariableIndex Subscript Visualization.
"""
function Posiforms.subscript(v::VI; var::Union{String, Symbol, Nothing}=:x)
    if var === nothing
        return subscript(v.value)
    else
        return "$var$(subscript(v.value))"
    end
end

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

"""
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
            w = addslack(model, 1, offset=0)

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

        cache[t] = p

        return p
    end
end

"""
"""
function toqubo(model::MOI.ModelLike, quantum::Bool=false)::QUBOModel

    T = Float64 # TODO: Use MOIU.Model{T} where T ??

    # -*- Support Validation -*-
    supported_objective(model)
    supported_constraints(model)

    # -*- Create QUBO Model -*-
    # This allows one to use MOI.copy_to afterwards
    qubo = QUBOModel{T}(quantum=quantum)

    # -*- Variable Analysis -*-

    # Set of all model variables
    X = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Set of binary variables
    B = Set{VI}()

    for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{VI, ZO}())
        # Account for variable as binary
        push!(B, MOI.get(model, MOI.ConstraintFunction(), cᵢ))
    end

    # Non-binary variables
    W = setdiff(X, B)

    @info "Original Binary Variables: $B"

    @info "Variables for expansion: $W"

    for bᵢ in B
        mirror!(qubo, bᵢ)
    end

    # TODO: bit size heuristics
    bits = 3

    for wᵢ in W
        expand!(qubo, wᵢ, bits)
    end

    # -*- Objective Analysis -*-

    # OS() -> ObjectiveSense()
    MOI.set(qubo.model, OS(), MOI.get(model, OS()))

    F = MOI.get(model, MOI.ObjectiveFunctionType())

    # -*- Objective Function Posiform -*-
    p = Posiform{VI, T}()

    if F === VI
        # -*- Single Variable -*-
        x = MOI.get(model, MOI.ObjectiveFunction{F}())

        for (xᵢ, cᵢ) in qubo.source[x] # TODO: enhance syntax
            p[xᵢ] += cᵢ
        end

    elseif F === SAF{T}
        # -*- Affine Terms -*-
        f = MOI.get(model, MOI.ObjectiveFunction{F}())

        for aᵢ in f.terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            for (xᵢⱼ, dⱼ) in qubo.source[xᵢ] # TODO: enhance syntax
                p[xᵢⱼ] += cᵢ * dⱼ
            end
        end

        # Constant
        p += f.constant

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
                    p[zⱼₖ] += cᵢ * dⱼ * dₖ
                end
            end
        end

        for aᵢ in f.affine_terms
            cᵢ = aᵢ.coefficient
            xᵢ = aᵢ.variable

            for (xᵢⱼ, dⱼ) in qubo.source[xᵢ] # TODO: enhance syntax
                p[xᵢⱼ] += cᵢ * dⱼ
            end
        end

        # Constant
        p += f.constant
    else
        error("I Don't know how to deal with objective functions of type '$F'")
    end

    # -*- Constraint Analysis -*-
    q = Posiform{VI, T}()

    # Constraints
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

                    qᵢ = (rᵢ - bᵢ) ^ 2
                    ρᵢ = penalty(p, qᵢ)
                    q += ρᵢ * qᵢ
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

                    @info "C = $bᵢ ($(bits) bits)"

                    for (sⱼ, dⱼ) in addslack(qubo, bits)
                        sᵢ[sⱼ] += dⱼ
                    end

                    qᵢ = (rᵢ + sᵢ - bᵢ) ^ 2
                    ρᵢ = penalty(p, qᵢ)
                    q += ρᵢ * qᵢ
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

                    qᵢ = (rᵢ - sᵢ - bᵢ) ^ 2
                    ρᵢ = penalty(p, qᵢ)
                    q += ρᵢ * qᵢ
                end

            else
                error("Panic! I'm confused with this kind of constraint set: '$S'")
            end
        else
            error("Unkown Constraint Type $F")
        end
    end

    # -*- Objective Function Assembly -*-
    sense = MOI.get(qubo.model, OS()) 

    # p (objective)
    # q (constraints with penalties)
    if sense === MOI.MAX_SENSE
        e = p - q
    elseif sense === MOI.MIN_SENSE
        e = p + q
    end

    e /= maximum(values(e))

    Q = []
    a = []
    b = convert(T, 0)

    for (xᵢ, cᵢ) in e
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

end # module