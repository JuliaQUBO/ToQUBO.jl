# -*- Alias: PBF -*-
const ℱ{T} = PBF{VI, T}             # ℱ = \scrF[tab]

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


mutable struct QUBOModelMOI{T <: Any}
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

    function QUBOModelMOI{T}(
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

mutable struct 

@doc raw"""
    VirtualQUBOModel{T}(
        optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
        tol::T=zero(T),
        bits::Int=4,
    )

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct VirtualQUBOModel{T <: Any} <: AbstractVirtualModel{T}

    # -*- Underlying Model -*-
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}

    # -*- Virtual Model Interface -*-
    varvec::Vector{VirtualMOIVariable{T}}
    source::Dict{VI, VirtualMOIVariable{T}}
    target::Dict{VI, VirtualMOIVariable{T}}

    # - Underlying Optimizer
    optimizer::Union{Nothing, MOI.AbstractOptimizer}
    
    ℍ₀::ℱ{T} # Objective
    ℍᵢ::Vector{ℱ{T}} # Constraints

    # :: ℍ(s) = ℍ₀(s) + Σᵢ ρᵢ ℍᵢ(s) ::
    ℍ::ℱ{T} # Total Energy

    tol::T

    # :: Cache for PBF degree reduction ::
    cache::Dict{Set{VI}, ℱ{T}}

    # -*- MathOptInterface -*-
    moi::QUBOModelMOI{T}

    function VirtualQUBOModel{T}(optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing; tol::T=zero(T)) where {T}
        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),
            optimizer,
            ℱ{T}(),
            Vector{ℱ{T}}(),
            ℱ{T}(),
            tol,
            Dict{Set{VI}, ℱ{T}}(),
            Vector{VirtualMOIVariable{T}}(),
            Dict{VI, VirtualMOIVariable{T}}(),
            Dict{VI, VirtualMOIVariable{T}}(),
            ModelMOI{T}()
        )
    end
end

# MathOptInterface
include("moi.jl")

# -*- Include: qubo -*-
include("qubo.jl")