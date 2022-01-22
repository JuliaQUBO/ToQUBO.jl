# :: Input Model Support ::

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

# -*- Get: ObjectiveFunctionType -*-
function MOI.get(model::VirtualQUBOModel, ::MOI.ObjectiveFunctionType)
    return MOI.get(model.preq_model, MOI.ObjectiveFunctionType())
end

function MOI.get(model::VirtualQUBOModel{T}, ::MOI.VariablePrimal, xᵢ::MOI.VariableIndex) where {T}
    return sum(
        (MOI.get(model.qubo_model, MOI.VariablePrimal(), yⱼ) * cⱼ for (yⱼ, cⱼ) ∈ model.source[xᵢ]);
        init=zero(T)
    )
end

