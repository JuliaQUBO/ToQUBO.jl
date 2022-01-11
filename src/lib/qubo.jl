# -*- Pseudo-boolean Functions-*-
include("./pbo.jl")
using .PBO

# -*- Alias -*-
const ℱ{T} = PBF{VI, T}

# -*- Virtual Variables -*-
include("./varmap.jl")
using .VarMap

# -*- Alias -*-
# Bind VirtualVar{S, T}, S to OI.VariableIndex
const 𝒱{T} = VV{VI, T}

# -*- QUBO Model -*-
mutable struct QUBOModel{T <: Any} <: MOIU.AbstractModelLike{T}
    # -*- MOI Model-Like -*-
    model::MOIU.Model{T}

    # -*- Virtual Variable Interface -*-
    varvec::Vector{𝒱{T}}

    source::Dict{VI, 𝒱{T}}
    target::Dict{VI, 𝒱{T}}

    # - For PBF Reduction
    cache::Dict{Set{VI}, ℱ{T}}

    # - Slack Variable Count
    slack::Int
    
    # - Underlying Optimizer
    sampler::Union{Nothing, AbstractSampler{T}}

    # Hamiltonian
    ℍ₀::ℱ{T} # Objective
    ℍᵢ::ℱ{T} # Constraints

    # -*- MOI Stuff -*-
    # - ObjectiveValue (Avaliar somente ℍ₀(s) ou também E(s)?)
    objective_value::Float64
    # - SolveTimeSec
    solve_time_sec::Float64
    # - TerminationStatus (não está 100% claro na minha cabeça o que deve retornado aqui)
    termination_status::Any
    # - PrimalStatus (idem)
    primal_status::Any
    # - RawStatusString
    raw_status_str::Union{Nothing, String}

    function QUBOModel{T}(sampler::Union{Nothing, AbstractSampler{T}}=nothing) where T
        return new{T}(
            MOIU.Model{T}(),
            Vector{𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            Dict{Set{VI}, ℱ{T}}(),
            0,
            sampler,
            ℱ{T}(),
            ℱ{T}(),
            NaN,
            NaN,
            nothing,
            nothing,
            nothing,
        )
    end
end

# -*- Default -*-
function QUBOModel(sampler::AbstractSampler{VI, Bool, Float64})
    return QUBOModel{Float64}(sampler)
end

function QUBOModel()
    return QUBOModel{Float64}()
end

# ::: Variable Management :::

# -*- Add Generic Variable -*-
"""
General Interface for variable inclusion on QUBO Models.


"""
function addvar(model::QUBOModel{T}, source::Union{VI, Nothing}, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T)))::𝒱{T} where T
    # -*- Add MOI Variables to underlying model -*-
    target = MOI.add_variables(model.model, bits)::Vector{VI}

    if source === nothing
        # -*- Slack Variable -*-
        model.slack += 1
        name = Symbol(subscript(model.slack, var=name, par=true))
    else
        name = :x
    end

    # -*- Virtual Variable -*-
    α, β = domain

    v = 𝒱{T}(bits, target, source; name=name, α=α, β=β)

    for vᵢ in target
        # -*- Make Variable Binary -*-
        MOI.add_constraint(model.model, vᵢ, ZO())
        MOI.set(model.model, MOI.VariableName(), vᵢ, subscript(vᵢ, var=name))
        model.target[vᵢ] = v
    end

    push!(model.varvec, v)

    return v
end


# -*- Add Slack Variable -*-
function addslack(model::QUBOModel{T}, bits::Int; name::Symbol=:s, domain::Tuple{T, T}=(zero(T), one(T)))::𝒱{T} where T
    return addvar(model, nothing, bits, name=name, domain=domain)
end

# -*- Expand: Interpret existing variable through its binary expansion -*-
function expand!(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T)))::𝒱{T} where T
    model.source[src] = addvar(model, src, bits; name=name, domain=domain)
end

function expand(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T)))::𝒱{T} where T
    expand!(model, src, bits, name=name, domain=domain)
    return model.source[src]
end

# -*- Mirror: Make existing variable Binary -*-
function mirror!(model::QUBOModel{T}, var::VI; name::Symbol=:x)::𝒱{T} where T
    expand!(model, var, 1, name=name)
end

function mirror(model::QUBOModel{T}, var::VI; name::Symbol=:x)::𝒱{T} where T
    mirror!(model, var, name=name)
    return model.source[var]
end

function vars(model::QUBOModel{T})::Vector{𝒱{T}} where T
    return Vector{𝒱{T}}(model.varvec)
end

function slackvars(model::QUBOModel{T})::Vector{𝒱{T}} where T
    return Vector{𝒱{T}}([v for v in model.varvec if isslack(v)])
end

# -*- QUBO Validation -*-
raw"""
    isqubo(model::MOI.ModelLike)::Bool

Tells if `model` is ready as QUBO Model. A few conditions must be met:
    1. All variables must be binary (VariableIndex-in-ZeroOne)
    2. No other constraints are allowed
    3. The objective function must be either ScalarQuadratic, ScalarAffine or VariableIndex
"""
function isqubo(T::Type{<: Any}, model::MOI.ModelLike)
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

function isqubo(model::QUBOModel{T}) where {T}
    return isqubo(T, model.model)
end

# ::: QUBO Conversion :::

# -*- Variables -*-
function toqubo_variables!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}) where {T}
    # ::: Variable Analysis :::

    # Set of all source variables
    Ω = Set{VI}(MOI.get(ℳ, MOI.ListOfVariableIndices()))

    𝕋 = Union{Missing, T}

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Set{VI}()
    ℤ = Dict{VI, Tuple{𝕋, 𝕋}}()
    ℝ = Dict{VI, Tuple{𝕋, 𝕋}}()

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.ZeroOne()}())
        # -*- Binary Variable 😄 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)

        # Add to set
        push!(𝔹, xᵢ)
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.Integer()}())
        # -*- Integer Variable 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)

        # Add to dict as unbounded
        ℤ[xᵢ] = (missing, missing)
    end

    for xᵢ in setdiff(Ω, 𝔹, ℤ)
        # -*- Real Variable 😢 -*-
        ℝ[xᵢ] = (missing, missing)
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.Interval()}())
        # -*- Interval 😄 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ) 

        aᵢ = Iᵢ.lower
        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, bᵢ)
        end
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.LessThan()}())
        # -*- Upper Bound 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ) 

        bᵢ = Iᵢ.upper

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (ℤ[xᵢ][0], bᵢ)
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (ℝ[xᵢ][0], bᵢ)
        end
    end

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{VI, MOI.GreaterThan()}())
        # -*- Lower Bound 🤔 -*-
        xᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        Iᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ)

        aᵢ = Iᵢ.lower

        if haskey(ℤ, xᵢ)
            ℤ[xᵢ] = (aᵢ, ℤ[xᵢ][1])
        elseif haskey(ℝ, xᵢ)
            ℝ[xᵢ] = (aᵢ, ℤ[xᵢ][1])
        end
    end

    # STRONG TODO: bits magic
    bits = 3 # WHY ????!!!!!!

    # -*- Discretize Real Ones 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℝ
        if aᵢ === missing || bᵢ === missing
            error("Unbounded variable $xᵢ ∈ ℤ")
        else
            expand!(𝒬, xᵢ, bits; domain=(aᵢ, bᵢ))
        end
    end

    # -*- Discretize Integer Variables 🤔 -*-
    for (xᵢ, (aᵢ, bᵢ)) in ℤ
        if aᵢ === missing || bᵢ === missing
            error("Unbounded variable $xᵢ ∈ ℤ")
        else
            expand!(𝒬, xᵢ, bits; domain=(aᵢ, bᵢ))
        end
    end

    # -*- Mirror Boolean Variables 😄 -*-
    for xᵢ in 𝔹
        mirror!(𝒬, xᵢ)
    end
end

# -*- Objective Function -*-
function toqubo_objective!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, ::VI) where {T}
    # -*- Single Variable -*-
    xᵢ = MOI.get(ℳ, MOI.ObjectiveFunction{VI}())
    vᵢ = 𝒬.source[xᵢ]

    for (xᵢⱼ, cᵢⱼ) in vᵢ
        𝒬.ℍ₀[xᵢⱼ] += cᵢⱼ
    end
end

function toqubo_objective!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, ::SAF{T}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(ℳ, MOI.ObjectiveFunction{SAF{T}}())

    for aᵢ in f.terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        vᵢ = 𝒬.source[xᵢ]

        for (xᵢⱼ, dᵢⱼ) in vᵢ
            𝒬.ℍ₀[xᵢⱼ] += cᵢ * dᵢⱼ
        end
    end

    # -*- Constant -*-
    𝒬.ℍ₀ += f.constant
end

function toqubo_objective!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, F::Type{<: SAF{T}}) where {T}
    # -*- Affine Terms -*-
    f = MOI.get(ℳ, MOI.ObjectiveFunction{F}())

    # Quadratic Terms
    for Qᵢ in f.quadratic_terms
        cᵢ = Qᵢ.coefficient
        xᵢ = Qᵢ.variable_1
        yᵢ = Qᵢ.variable_2

        vᵢ = 𝒬.source[xᵢ]
        wᵢ = 𝒬.source[yᵢ]

        for (xᵢⱼ, dᵢⱼ) in vᵢ
            for (yᵢₖ, dᵢₖ) in wᵢ
                zⱼₖ = Set{VI}([xᵢⱼ, yᵢₖ])
                𝒬.ℍ₀[zⱼₖ] += cᵢ * dᵢⱼ * dᵢₖ
            end
        end
    end

    for aᵢ in f.affine_terms
        cᵢ = aᵢ.coefficient
        xᵢ = aᵢ.variable

        vᵢ = 𝒬.source[xᵢ]

        for (xᵢⱼ, dᵢⱼ) in vᵢ
            𝒬.ℍ₀[xᵢⱼ] += cᵢ * dᵢⱼ
        end
    end

    # -*- Constant -*-
    𝒬.ℍ₀ += f.constant
end

# -*- Constraints -*-
function toqubo_constraint!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, F::SAF{T}, S::EQ{T}) where {T}
    # -*- Scalar Affine Function: Ax = b 😄 -*-
    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{F, S}())
        rᵢ = ℱ{T}()

        Aᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ).value

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            vⱼ = 𝒬.source[xⱼ]

            for (yⱼₖ, dⱼₖ) in vⱼ
                rᵢ[yⱼₖ] += cⱼ * dⱼₖ
            end 
        end

        qᵢ = reduce_degree(
            (rᵢ - bᵢ) ^ 2;
            cache=𝒬.cache,
            slack=()->addslack(𝒬, 1, name=:w)
        )

        𝒬.ℍᵢ += qᵢ
    end
end

function toqubo_constraint!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, F::SAF{T}, S::LT{T}) where {T}
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-

    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{F, S}())
        rᵢ = Posiform{VI, T}()

        Aᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ).upper

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            vⱼ = 𝒬.source[xⱼ]

            for (yⱼₖ, dⱼₖ) in vⱼ
                rᵢ[yⱼₖ] += cⱼ * dⱼₖ
            end 
        end

        # -*- Introduce Slack Variable -*-
        sᵢ = ℱ{T}()

        # TODO: Heavy Inference going on!
        bits = ceil(Int, log(2, bᵢ))

        α = zero(T)
        β = bᵢ

        for (sᵢⱼ, dᵢⱼ) in addslack(𝒬, bits, domain=(α, β), name=:s)
            sᵢ[sᵢⱼ] += dᵢⱼ
        end

        qᵢ = reduce_degree(
            (rᵢ + sᵢ - bᵢ) ^ 2;
            cache=𝒬.cache,
            slack=()->addslack(𝒬, 1, name=:w)
        )

        𝒬.ℍᵢ += qᵢ
    end
end

function toqubo_constraint!(ℳ::MOI.ModelLike, 𝒬::QUBOModel{T}, F::SAF{T}, S::GT{T}) where {T}
    # -*- Scalar Affine Function: Ax >= b 🤔 -*-
    for cᵢ in MOI.get(ℳ, MOI.ListOfConstraintIndices{F, S}())
        rᵢ = Posiform{VI, T}()

        Aᵢ = MOI.get(ℳ, MOI.ConstraintFunction(), cᵢ)
        bᵢ = MOI.get(ℳ, MOI.ConstraintSet(), cᵢ).lower

        for aⱼ in Aᵢ.terms
            cⱼ = aⱼ.coefficient
            xⱼ = aⱼ.variable

            vⱼ = 𝒬.source[xⱼ]

            for (yⱼₖ, dⱼₖ) in vⱼ
                rᵢ[yⱼₖ] += cⱼ * dⱼₖ
            end 
        end

        # -*- Introduce Slack Variable -*-
        sᵢ = ℱ{T}()

        # TODO: Heavy Inference going on!
        bits = ceil(Int, log(2, bᵢ))

        α = zero(T)
        β = bᵢ

        for (sᵢⱼ, dᵢⱼ) in addslack(𝒬, bits, domain=(α, β), name=:s)
            sᵢ[sᵢⱼ] += dᵢⱼ
        end

        qᵢ = reduce_degree(
            (rᵢ - sᵢ - bᵢ) ^ 2;
            slack=()->addslack(𝒬, 1, name=:w),
            cache=𝒬.cache
        )

        𝒬.ℍᵢ += qᵢ
    end
end

# -*- From ModelLike to QUBO -*-
function toqubo(T::Type{<: Any}, ℳ::MOI.ModelLike; sampler::Union{Nothing, AbstractSampler}=nothing)
    # -*- Support Validation -*-
    supported_objective(ℳ)
    supported_constraints(ℳ)

    # -*- Create QUBO Model -*-
    # This allows one to use MOI.copy_to afterwards
    𝒬 = QUBOModel{T}(sampler)

    toqubo_variables!(ℳ, 𝒬)

    # ::: Objective Analysis :::
    F = MOI.get(ℳ, MOI.ObjectiveFunctionType())

    # -*- Objective Function Posiform -*-
    toqubo_objective!(ℳ, 𝒬, F)

    # ::: Constraint Analysis :::

    for (F, S) in MOI.get(ℳ, MOI.ListOfConstraints())
        toqubo_constraint!(ℳ, 𝒬, F, S)
    end

    # -*- Objective Function Assembly -*-
    MOI.set(
        𝒬.model,
        MOI.ObjectiveSense(),
        MOI.get(ℳ, MOI.ObjectiveSense())
    )

    Q = []
    a = []
    b = zero(T)

    ℍ = (𝒬.ℍ₀ + 𝒬.ℍᵢ) # Total Energy

    for (ω, c) in ℍ
        n = length(ω)

        if n == 0
            b += c
        elseif n == 1
            push!(a, SAT{T}(c, ω...))
        elseif n == 2
            push!(Q, SQT{T}(c, ω...))
        else
            error("Degree reduction failed!")
        end
    end

    MOI.set(
        𝒬.model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b)
    )

    return 𝒬   
end