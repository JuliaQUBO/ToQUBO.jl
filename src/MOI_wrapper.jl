function MOI.empty!(model::AbstractVirtualModel)
    # -*- Models -*-
    MOI.empty!(model.source_model)
    MOI.empty!(model.target_model)

    # -*- Virtual Variables -*-
    empty!(model.varvec)
    empty!(model.source)
    empty!(model.target)

    nothing
end

function MOI.empty!(model::VirtualQUBOModel)
    # -*- Models -*-
    MOI.empty!(model.source_model)
    MOI.empty!(model.target_model)

    # -*- Virtual Variables -*-
    empty!(model.varvec)
    empty!(model.source)
    empty!(model.target)

    # -*- Underlying Optimizer -*-
    isnothing(model.optimizer) || MOI.empty!(model.optimizer)

    # -*- PBFs -*-
    empty!(model.ℍ)
    empty!(model.ℍ₀)
    empty!(model.ℍᵢ)

    # -*- MathOptInterface -*-
    empty!(model.moi)

    nothing
end

function MOI.is_empty(model::AbstractVirtualModel)
    return MOI.is_empty(model.source_model) && MOI.is_empty(model.target_model)
end

function MOI.optimize!(model::VirtualQUBOModel)
    if isnothing(model.optimizer)
        error("No Optimizer attached")
    end

    MOI.optimize!(model.optimizer, model.target_model)

    # :: Update MOI ::
    model.moi.objective_value    = MOI.get(model.optimizer, MOI.ObjectiveValue())
    model.moi.solve_time_sec     = MOI.get(model.optimizer, MOI.SolveTimeSec())
    model.moi.termination_status = MOI.get(model.optimizer, MOI.TerminationStatus())
    model.moi.primal_status      = MOI.get(model.optimizer, MOI.PrimalStatus())
    model.moi.dual_status        = MOI.get(model.optimizer, MOI.DualStatus())
    model.moi.raw_status_string  = MOI.get(model.optimizer, MOI.RawStatusString())
    
    return (MOIU.identity_index_map(model.source_model), false)
end

function Base.show(io::IO, model::VirtualQUBOModel)
    print(io, 
    """
    A Virtual QUBO Model
    with source:
        $(model.source_model)
    with target:
        $(model.target_model)
    """
    )
end

function MOI.copy_to(model::VirtualQUBOModel, source::MOI.ModelLike)
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    index_map = MOI.copy_to(model.source_model, source)

    toqubo!(model)

    return index_map
end

# Objective Function Support
MOI.supports(
    ::VirtualQUBOModel{T},
    ::MOI.ObjectiveFunction{SAF{T}},
) where T = true

MOI.supports(
    ::VirtualQUBOModel{T},
    ::MOI.ObjectiveFunction{SQF{T}},
) where T = true

# Constraint Support
MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:VI},
    ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}}},
) where {T} = true

MOI.supports_add_constrained_variable(
    ::VirtualQUBOModel{T},
    ::Type{<:Union{MOI.ZeroOne, MOI.Integer, MOI.Interval{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:MOI.ScalarAffineFunction{T}},
    ::Type{<:Union{MOI.EqualTo{T}, MOI.LessThan{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:MOI.ScalarQuadraticFunction{T}},
    ::Type{<:Union{MOI.EqualTo{T}, MOI.LessThan{T}}},
) where {T} = true

# -*- :: Attributes :: -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintTypesPresent)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfModelAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableAttributesSet)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableIndices)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.NumberOfConstraints)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.NumberOfVariables)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.Name)
    return MOI.get(model.source_model, attr)
end

function MOI.set(model::VirtualQUBOModel, attr::MOI.Name, name::String)
    MOI.set(model.source_model, attr, name)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunction)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunctionType)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveSense)
    return MOI.get(model.source_model, attr)
end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveValue)
    return model.moi.objective_value
end

function MOI.set(model::VirtualQUBOModel{T}, ::MOI.ObjectiveValue, value::T) where {T}
    model.moi.objective_value = value
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec)
    return model.moi.solve_time_sec
end

function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec, time_sec::Float64)
    model.moi.solve_time_sec = time_sec
    nothing
end

MOI.supports(::VirtualQUBOModel, ::MOI.SolveTimeSec) = true

function MOI.get(model::VirtualQUBOModel, ::MOI.PrimalStatus)
    return model.moi.primal_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.PrimalStatus, status::MOI.ResultStatusCode)
    model.moi.primal_status = status
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.DualStatus)
    return model.moi.dual_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.DualStatus, status::MOI.ResultStatusCode)
    model.moi.dual_status = status
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.TerminationStatus)
    return model.moi.termination_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.TerminationStatus, status::MOI.TerminationStatusCode)
    model.moi.termination_status = status
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.RawStatusString)
    return model.moi.raw_status_string
end

function MOI.set(model::VirtualQUBOModel, ::MOI.RawStatusString, str::String)
    model.moi.raw_status_string = str
    nothing
end

function MOI.get(model::VirtualQUBOModel, rc::MOI.ResultCount)
    if model.optimizer === nothing
        return 0
    else
        return MOI.get(model.optimizer, rc)
    end
end

MOI.supports(::VirtualQUBOModel, ::MOI.ResultCount) = true

function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintFunction, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.source_model, attr, cᵢ)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintSet, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.source_model, attr, cᵢ)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.VariableName, xᵢ::VI)
    return MOI.get(model.source_model, attr, xᵢ)
end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunction{F}) where {F}
    return MOI.get(model.source_model, MOI.ObjectiveFunction{F}())
end

function MOI.get(model::VirtualQUBOModel{T}, vp::MOI.VariablePrimal, xᵢ::VI) where {T}
    if isnothing(model.optimizer)
        throw(ErrorException("No underlying optimizer for model"))
    end

    return sum((prod(MOI.get(model.optimizer, vp, yⱼ) for yⱼ ∈ ωⱼ; init=one(T)) * cⱼ for (ωⱼ, cⱼ) ∈ model.source[xᵢ]); init=zero(T))
end

function MOI.get(::VirtualQUBOModel, ::MOI.SolverName)
    return "Virtual QUBO Model"
end

function MOI.get(::VirtualQUBOModel, ::MOI.SolverVersion)
    return v"0.1.0"
end

function MOI.get(model::VirtualQUBOModel, rs::MOI.RawSolver)
    return MOI.get(model.optimizer, rs)
end

# TODO: Get rid of this type piracy example.
Base.isless(u::VI, v::VI) = isless(u.value, v.value)

# IDEA: Implement some higher-level varcmp(::S, ::S) with a
#       fallback call to isless(::S, ::S). Then, implement
#       varcmp(::VI, ::VI).                               □