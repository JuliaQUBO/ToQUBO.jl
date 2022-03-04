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

Base.@kwdef mutable struct VirtualQUBOModelMOI{T <: Any}
    # - ObjectiveValue (Avaliar somente ℍ₀(s) ou também ℍᵢ(s)?)
    objective_value::T = zero(T)
    # - SolveTimeSec
    solve_time_sec::Float64 = NaN
    # - TerminationStatus (não está 100% claro na minha cabeça o que deve retornado aqui)
    termination_status::MOI.TerminationStatusCode = MOI.OPTIMIZE_NOT_CALLED
    # - PrimalStatus (idem)
    primal_status::MOI.ResultStatusCode = MOI.NO_SOLUTION
    # - RawStatusString
    raw_status_string::String  = ""
end

function Base.empty!(moi::VirtualQUBOModelMOI{T}) where T
    moi.objective_value = zero(T)
    moi.solve_time_sec = NaN
    moi.termination_status = MOI.OPTIMIZE_NOT_CALLED
    moi.primal_status = MOI.NO_SOLUTION
    moi.raw_status_string = ""

    nothing
end

@doc raw"""
    VirtualQUBOModel{T}(
        optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
        tol::T=zero(T),
        bits::Int=4,
    )

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct VirtualQUBOModel{T} <: AbstractVirtualModel{T}

    # -*- Virtual Model Interface -*-
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    
    varvec::Vector{VirtualMOIVariable{T}}
    source::Dict{VI, VirtualMOIVariable{T}}
    target::Dict{VI, VirtualMOIVariable{T}}

    # - Slack Variables
    slacks::Vector{VirtualMOIVariable{T}}

    # - Underlying Optimizer
    optimizer::Union{Nothing, MOI.AbstractOptimizer}
    
    ℍ::ℱ{T}          # Total Energy
    ℍ₀::ℱ{T}         # Objective
    ℍᵢ::Vector{ℱ{T}} # Constraints

    # -*- MathOptInterface -*-
    moi::VirtualQUBOModelMOI{T}

    # -*- Settings -*-
    tol::T

    # :: Cache for PBF degree reduction ::
    # cache::Dict{Set{VI}, ℱ{T}}

    function VirtualQUBOModel{T}(
            optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
            tol::T = T(1e-6)
        ) where {T}

        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),

            VirtualMOIVariable{T}[],
            Dict{VI, VirtualMOIVariable{T}}(),
            Dict{VI, VirtualMOIVariable{T}}(),

            VirtualMOIVariable{T}[],

            optimizer,

            ℱ{T}(),
            ℱ{T}(),
            ℱ{T}[],
            
            QUBOMOI{T}(),

            tol,

            # Dict{Set{VI}, ℱ{T}}(),
        )
    end
end

function add_slack(model::AbstractVirtualModel)
    function slack(n::Union{Nothing, Int} = nothing)
        if n === nothing
            return first(target(slack𝔹!(model; name=:w)))
        else
            return [first(target(slack𝔹!(model; name=:w))) for _ = 1:n]
        end
    end
end