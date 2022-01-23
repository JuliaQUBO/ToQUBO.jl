# -*- Alias: PBF -*-
const ℱ{T} = PBF{VI, T}             # ℱ = \scrF[tab]
const 𝒱{T} = VirtualVariable{VI, T} # 𝒱 = \scrV[tab]

# -*- Model: PreQUBOModel -*-
MOIU.@model(PreQUBOModel,                                       # Name of model
    (MOI.Integer, MOI.ZeroOne),                                 # untyped scalar sets
    (EQ, LT),                                                   #   typed scalar sets
    (),                                                         # untyped vector sets
    (),                                                         #   typed vector sets
    (VI,),                                                      # untyped scalar functions
    (SAF, SQF),                                                 #   typed scalar functions
    (),                                                         # untyped vector functions
    (),                                                         #   typed vector functions
    false
)

# -*- Model: PreQUBOModel -*-
MOIU.@model(QUBOModel,
    (MOI.ZeroOne,),                                             # untyped scalar sets
    (),                                                         #   typed scalar sets
    (),                                                         # untyped vector sets
    (),                                                         #   typed vector sets
    (),                                                         # untyped scalar functions
    (SQF,),                                                     #   typed scalar functions
    (),                                                         # untyped vector functions
    (),                                                         #   typed vector functions
    false
)


mutable struct ModelMOI{T <: Any}
    # - ObjectiveValue (Avaliar somente ℍ₀(s) ou também ℍᵢ(s)?)
    objective_value::T
    # - SolveTimeSec
    solve_time_sec::Float64
    # - TerminationStatus (não está 100% claro na minha cabeça o que deve retornado aqui)
    termination_status::MOI.TerminationStatusCode
    # - PrimalStatus (idem)
    primal_status::MOI.ResultStatusCode
    # - RawStatusString
    raw_status_str::String  

    function ModelMOI{T}(
        objective_value::T=zero(T),
        solve_time_sec::Float64=NaN,
        termination_status::MOI.TerminationStatusCode=MOI.OPTIMIZE_NOT_CALLED,
        primal_status::Any=MOI.NO_SOLUTION,
        raw_status_str::String=""
    ) where {T}
        return new(
            objective_value,
            solve_time_sec,
            termination_status,
            primal_status,
            raw_status_str
        )
    end
end

@doc raw"""
    VirtualQUBOModel{T}(
        optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
        ϵ::T=zero(T)
    )

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct VirtualQUBOModel{T} <: MOIU.AbstractModelLike{T}
    # -*- Underlying Model -*-
    preq_model::PreQUBOModel{T}
    qubo_model::QUBOModel{T}

    # - Underlying Optimizer
    optimizer::Union{Nothing, MOI.AbstractOptimizer}
    
    ℍ₀::ℱ{T} # Objective
    ℍᵢ::Vector{ℱ{T}} # Constraints

    # :: ℍ(s) = ℍ₀(s) + Σᵢ ρᵢ ℍᵢ(s) ::
    ℍ::ℱ{T} # Total Energy

    ϵ::T

    # :: Cache for PBF degree reduction ::
    cache::Dict{Set{VI}, ℱ{T}}

    # -*- Virtual Variable Interface -*-
    varvec::Vector{𝒱{T}}
    source::Dict{VI, 𝒱{T}}
    target::Dict{VI, 𝒱{T}}

    # -*- MOI Stuff -*-
    moi::ModelMOI{T}

    function VirtualQUBOModel{T}(optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing; ϵ::T=zero(T)) where {T}
        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),
            optimizer,
            ℱ{T}(),
            Vector{ℱ{T}}(),
            ℱ{T}(),
            ϵ,
            Dict{Set{VI}, ℱ{T}}(),
            Vector{𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            ModelMOI{T}()
        )
    end
end

# MathOptInterface
include("moi.jl")

# ::: Variable Management :::
@doc raw"""
    mapvar!(model::VirtualQUBOModel{T}, 𝓋::𝒱{T}) where {T}

Maps newly created virtual variable `𝓋` within the virtual model structure. It follows these steps:
 
 1. Maps `𝓋`'s source to it in the model's `source` mapping.
 2. For every one of `𝓋`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `𝓋` to the end of the model's `varvec`.  
"""
function mapvar!(model::VirtualQUBOModel{T}, 𝓋::𝒱{T}) where {T}
    x = source(𝓋)

    if x !== nothing # not a slack variable
        model.source[x] = 𝓋
    end

    for yᵢ in target(𝓋)
        # MOI.set(model.qubo_model, MOI.VariableName(), yᵢ, String(name(𝓋)))
        MOI.add_constraint(model.qubo_model, yᵢ, MOI.ZeroOne())
        model.target[yᵢ] = 𝓋
    end

    push!(model.varvec, 𝓋)

    return 𝓋
end

@doc raw"""
    expandℝ!(model::QUBOModel{T}, src::VI; bits::Int, name::Symbol, α::T, β::T) where T

Real Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
"""
function expandℝ!(model::VirtualQUBOModel{T}, src::Union{VI, Nothing}; bits::Int, name::Symbol, α::T, β::T) where T
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        src;
        tech=:ℝ₂,
        bits=bits,
        name=name,
        α=α,
        β=β
    ))
end

function slackℝ!(model::VirtualQUBOModel{T}; bits::Int, name::Symbol, α::T, β::T) where T
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        nothing;
        tech=:ℝ₂,
        bits=bits,
        name=name,
        α=α,
        β=β
    ))
end

@doc raw"""
    expandℤ!(model::QUBOModel{T}, src::VI; name::Symbol, α::T, β::T) where T

Integer Binary Expansion within the closed interval ``[\left\lceil{\alpha}\right\rceil, \left\lfloor{\beta}\right\rfloor]``.
"""
function expandℤ!(model::VirtualQUBOModel{T}, src::Union{VI, Nothing}; name::Symbol, α::T, β::T) where T
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        src;
        tech=:ℤ₂,
        name=name,
        α=α,
        β=β
    ))
end

@doc raw"""
    slackℤ!(model::VirtualQUBOModel{T}; name::Symbol, α::T, β::T) where {T}

Adds integer slack variable according to [`expandℤ!`](@ref)'s expansion method.
"""
function slackℤ!(model::VirtualQUBOModel{T}; name::Symbol, α::T, β::T) where {T}
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        nothing;
        tech=:ℤ₂,
        name=name,
        α=α,
        β=β
    ))
end

@doc raw"""
    mirror𝔹!(model::VirtualQUBOModel{T}, src::Union{VI, Nothing}; name::Symbol) where T

Simply crates a virtual-mapped *Doppelgänger* into the destination model.
"""
function mirror𝔹!(model::VirtualQUBOModel{T}, src::Union{VI, Nothing}; name::Symbol) where T
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        src;
        tech=:𝔹,
        name=name
    ))
end

function slack𝔹!(model::VirtualQUBOModel{T}; name::Symbol) where {T}
    return mapvar!(model, 𝒱{T}(
        (n) -> MOI.add_variables(model.qubo_model, n),
        nothing;
        tech=:𝔹,
        name=name
    ))
end

# -*- Include: toqubo -*-
include("qubo.jl")