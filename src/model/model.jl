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

export Model, toqubo

# -*- Include: Error -*-
include("../lib/error.jl")

# -*- Include: PBO -*-
include("../lib/pbo.jl")

# -*- Include: VarMap -*-
include("../lib/varmap.jl")
using .VarMap

# -*- Alias: PBF -*-
const ℱ{T} = PBO.PBF{VI, T} # ℱ = \scrF[tab]
const 𝒱{T} = VirtualVariable{VI, T}

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


mutable struct MOIModelOptions
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
end

mutable struct Model{T} <: MOIU.AbstractModelLike{T}
    # -*- Underlying Model -*-
    preq_model::PreQUBOModel{T}
    qubo_model::QUBOModel{T}

    # - Underlying Optimizer
    optimizer::Union{Nothing, MOI.AbstractOptimizer}
    
    ℍ₀::ℱ{T} # Objective
    ℍᵢ::Vector{ℱ{T}} # Constraints

    # ℍ(s) = ℍ₀(s) + Σᵢ ρᵢ ℍᵢ(s)
    ℍ::ℱ{T} # Total Energy

    # -*- Virtual Variable Interface -*-
    varvec::Vector{𝒱{T}}

    source::Dict{VI, 𝒱{T}}
    target::Dict{VI, 𝒱{T}}

    # - For PBF Reduction
    cache::Dict{Set{VI}, ℱ{T}}

    function Model{T}() where {T}
        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),
            nothing,
            ℱ{T}(),
            Vector{ℱ{T}}(),
            ℱ{T}()
        )
    end
end

# -*- Alias -*-
function Model()
    return Model{Float64}()
end

# -*- Include: toqubo -*-
include("qubo.jl")

end # module