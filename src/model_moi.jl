
# function MOI.get(model::VirtualQUBOModel, ::MOI.ListOfVariableIndices)
#     return Vector{VI}([source(𝓋) for 𝓋 ∈ model.varvec if !isslack(𝓋)])
# end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveValue)
    return model.moi.objective_value
end

function MOI.set(model::VirtualQUBOModel{T}, ::MOI.ObjectiveValue, value::T) where {T}
    model.moi.objective_value = value
    nothing
end

# -*- SolveTimeSec
function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec)
    return model.moi.solve_time_sec
end

function MOI.get(model::VirtualQUBOModel, ::MOI.SolveTimeSec, time_sec::Float64)
    model.moi.solve_time_sec = time_sec
    nothing
end

MOI.supports(::VirtualQUBOModel, ::MOI.SolveTimeSec) = true

# -*- PrimalStatus -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.PrimalStatus)
    return model.moi.primal_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.PrimalStatus, status::MOI.ResultStatusCode)
    model.moi.primal_status = status
    nothing
end

# -*- TerminationStatus -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.TerminationStatus)
    return model.moi.termination_status
end

function MOI.set(model::VirtualQUBOModel, ::MOI.TerminationStatus, status::MOI.TerminationStatusCode)
    model.moi.termination_status = status
    nothing
end

function MOI.get(model::VirtualQUBOModel, ::MOI.RawStatusString)
    return model.moi.raw_status_str
end

function MOI.set(model::VirtualQUBOModel, ::MOI.RawStatusString, str::String)
    model.moi.raw_status_str = str
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

# -*- Get: ObjectiveFunctionType -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveSense)
    return MOI.get(model.preq_model, MOI.ObjectiveSense())
end

function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunctionType)
    return MOI.get(model.preq_model, MOI.ObjectiveFunctionType())
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ObjectiveFunction{F}) where F <: MOI.AbstractScalarFunction
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfVariableIndices -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfVariableIndices)
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfConstraints -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintTypesPresent)
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ListOfConstraintIndices{S, T} -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices)
    return MOI.get(model.preq_model, attr)
end

function MOI.get(model::VirtualQUBOModel, attr::MOI.ListOfConstraintIndices{MOI.VariableIndex, S}) where {S}
    return MOI.get(model.preq_model, attr)
end

# -*- Get: ConstraintFunction -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintFunction, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.preq_model, attr, cᵢ)
end

# -*- Get: ConstraintSet -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.ConstraintSet, cᵢ::MOI.ConstraintIndex)
    return MOI.get(model.preq_model, attr, cᵢ)
end

# -*- Get: VariablePrimal -*-
function MOI.get(model::VirtualQUBOModel, attr::MOI.VariableName, xᵢ::MOI.VariableIndex)
    return MOI.get(model.preq_model, attr, xᵢ)
end

# -*- Get: ObjectiveFunction{F} -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunction{F}) where {F}
    return MOI.get(model.preq_model, MOI.ObjectiveFunction{F}())
end

function MOI.get(model::VirtualQUBOModel{T}, vp::MOI.VariablePrimal, xᵢ::MOI.VariableIndex) where {T}
    if model.optimizer === nothing
        throw(ErrorException("No underlying optimizer for model"))
    end

    return sum((MOI.get(model.optimizer, vp, yⱼ) * cⱼ for (yⱼ, cⱼ) ∈ model.source[xᵢ]); init=zero(T))
end

