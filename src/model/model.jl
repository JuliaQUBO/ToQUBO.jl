module QUBO
# -*- Imports: MathOptInterface -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const ZO = MOI.ZeroOne
const VI = MOI.VariableIndex
const INT = MOI.Integer

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}

const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}

const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

export Model, toqubo

# -*- Include: Error -*-
include("../lib/error.jl")

# -*- Include: PBO -*-
include("../lib/pbo.jl")
using .PBO

# -*- Include: VarMap -*-
include("../lib/varmap.jl")
using .VarMap

# -*- Alias: PBF -*-
const ℱ{T} = PBF{VI, T}             # ℱ = \scrF[tab]
const 𝒱{T} = VirtualVariable{VI, T} # 𝒱 = \scrV[tab]

# -*- Model: PreQUBOModel -*-
MOIU.@model(PreQUBOModel,                                               # Name of model
    (INT, ZO),                                                  # untyped scalar sets
    (EQ, LT),                                                   #   typed scalar sets
    (),                                                         # untyped vector sets
    (),                                                         #   typed vector sets
    (VI,),                                                       # untyped scalar functions
    (SAF, SQF),                                                 #   typed scalar functions
    (),                                                         # untyped vector functions
    (),                                                         #   typed vector functions
    false
)

# -*- Model: PreQUBOModel -*-
MOIU.@model(QUBOModel,
    (ZO,),                                                       # untyped scalar sets
    (),                                                         #   typed scalar sets
    (),                                                         # untyped vector sets
    (),                                                         #   typed vector sets
    (),                                                         # untyped scalar functions
    (SQF,),                                                      #   typed scalar functions
    (),                                                         # untyped vector functions
    (),                                                         #   typed vector functions
    false
)


mutable struct ModelMOI
    # - ObjectiveValue (Avaliar somente ℍ₀(s) ou também ℍᵢ(s)?)
    objective_value::Float64
    # - SolveTimeSec
    solve_time_sec::Float64
    # - TerminationStatus (não está 100% claro na minha cabeça o que deve retornado aqui)
    termination_status::Any
    # - PrimalStatus (idem)
    primal_status::Any
    # - RawStatusString
    raw_status_str::Union{Nothing, String}

    function ModelMOI(
        objective_value::Float64=NaN,
        solve_time_sec::Float64=NaN,
        termination_status::Any=MOI.OPTIMIZE_NOT_CALLED,
        primal_status::Any=MOI.NO_SOLUTION,
        raw_status_str::Union{Nothing, String}=nothing
    )
        return new(
            objective_value,
            solve_time_sec,
            termination_status,
            primal_status,
            raw_status_str
        )
    end
end

mutable struct VirtualQUBOModel{T} <: MOIU.AbstractModelLike{T}
    # -*- Underlying Model -*-
    preq_model::PreQUBOModel{T}
    qubo_model::QUBOModel{T}

    # - Underlying Optimizer
    optimizer::Union{Nothing, <:MOI.AbstractOptimizer}
    
    ℍ₀::ℱ{T} # Objective
    ℍᵢ::Vector{ℱ{T}} # Constraints

    # :: ℍ(s) = ℍ₀(s) + Σᵢ ρᵢ ℍᵢ(s) ::
    ℍ::ℱ{T} # Total Energy

    # :: Cache for PBF degree reduction ::
    cache::Dict{Set{VI}, ℱ{T}}

    # -*- Virtual Variable Interface -*-
    varvec::Vector{𝒱{T}}
    source::Dict{VI, 𝒱{T}}
    target::Dict{VI, 𝒱{T}}

    # -*- MOI Stuff -*-
    moi::ModelMOI

    function VirtualQUBOModel{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}}=nothing) where {T}
        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),
            optimizer,
            ℱ{T}(),
            Vector{ℱ{T}}(),
            ℱ{T}(),
            Dict{Set{VI}, ℱ{T}}(),
            Vector{𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            Dict{VI, 𝒱{T}}(),
            ModelMOI()
        )
    end
end

# MathOptInterface
include("moi.jl")

# ::: Variable Management :::
"""
    mapvar(model::VirtualQUBOModel{T}, 𝓋::𝒱{T}) where {T}

Variable Mapping
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

"""
    expandℝ!(model::QUBOModel{T}, src::VI; bits::Int, name::Symbol, α::T, β::T) where T

Real Expansion
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

"""
    expandℤ!(model::QUBOModel{T}, src::VI; name::Symbol, α::T, β::T) where T

Integer Expansion
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

"""
    mirror𝔹!(model::QUBOModel{T}, src::Union{VI, Nothing}; name::Symbol) where T

Binary Mirroring
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

end # module