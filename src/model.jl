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

mutable struct VirtualQUBOModelMOI{T}
    # - ObjectiveValue (Avaliar somente ℍ₀(s) ou também ℍᵢ(s)?)
    objective_value::T
    # - SolveTimeSec
    solve_time_sec::Float64
    # - TerminationStatus (não está 100% claro na minha cabeça o que deve retornado aqui)
    termination_status::MOI.TerminationStatusCode
    # - PrimalStatus (idem)
    primal_status::MOI.ResultStatusCode
    # - DualStatus (idem)
    dual_status::MOI.ResultStatusCode
    # - RawStatusString
    raw_status_string::String

    function VirtualQUBOModelMOI{T}(;
            objective_value::T = zero(T),
            solve_time_sec::Float64 = NaN,
            termination_status::MOI.TerminationStatusCode = MOI.OPTIMIZE_NOT_CALLED,
            primal_status::MOI.ResultStatusCode = MOI.NO_SOLUTION,
            dual_status::MOI.ResultStatusCode = MOI.NO_SOLUTION,
            raw_status_string::String = "",
        ) where {T}

        return new{T}(
            objective_value,
            solve_time_sec,
            termination_status,
            primal_status,
            dual_status,
            raw_status_string,
        )
    end
end

function Base.empty!(moi::VirtualQUBOModelMOI{T}) where {T}
    moi.objective_value = zero(T)
    moi.solve_time_sec = NaN
    moi.termination_status = MOI.OPTIMIZE_NOT_CALLED
    moi.primal_status = MOI.NO_SOLUTION
    moi.dual_status = MOI.NO_SOLUTION
    moi.raw_status_string = ""

    nothing
end

@doc raw"""
    VirtualQUBOModel{T}(
        optimizer::Union{Nothing, MOI.AbstractOptimizer}=nothing;
        tol::T = T(1e-6),
    ) where {T}

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct VirtualQUBOModel{T} <: MOI.AbstractOptimizer

    # -*- Virtual Model Interface -*-
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    
    varvec::Vector{VirtualMOIVariable{T}}
    source::Dict{VI, VirtualMOIVariable{T}}
    target::Dict{VI, VirtualMOIVariable{T}}

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
            optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing;
            tol::T = T(1e-6),
        ) where {T}

        return new{T}(
            PreQUBOModel{T}(),
            QUBOModel{T}(),

            VirtualMOIVariable{T}[],
            Dict{VI, VirtualMOIVariable{T}}(),
            Dict{VI, VirtualMOIVariable{T}}(),
            
            optimizer(),

            ℱ{T}(),
            ℱ{T}(),
            ℱ{T}[],
            
            VirtualQUBOModelMOI{T}(),

            tol,

            # Dict{Set{VI}, ℱ{T}}(),
        )
    end

    function VirtualQUBOModel(
            optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing;
            tol::Float64 = 1e-6,
        )
        return VirtualQUBOModel{Float64}(optimizer; tol = tol)
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