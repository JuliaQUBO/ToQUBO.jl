MOI.get(::VirtualModel, ::MOI.SolverName)    = "Virtual QUBO Model"
MOI.get(::VirtualModel, ::MOI.SolverVersion) = PROJECT_VERSION

const SOURCE_MODEL_ATTRIBUES{T} = Union{
    MOIB.ListOfNonstandardBridges{T},
    MOI.ListOfConstraintAttributesSet,
    MOI.ListOfConstraintIndices,
    MOI.ListOfConstraintTypesPresent,
    MOI.ListOfModelAttributesSet,
    MOI.ListOfVariableAttributesSet,
    MOI.ListOfVariableIndices,
    MOI.NumberOfConstraints,
    MOI.NumberOfVariables,
    MOI.Name,
    MOI.VariableName,
    MOI.ConstraintName,
    MOI.ObjectiveFunction,
    MOI.ObjectiveFunctionType,
    MOI.ObjectiveSense,
}

function MOI.get(model::VirtualModel{T}, attr::SOURCE_MODEL_ATTRIBUES{T}, args...) where {T}
    return MOI.get(model.source_model, attr, args...)
end

function MOI.set(model::VirtualModel{T}, attr::SOURCE_MODEL_ATTRIBUES{T}, args::Any...) where {T}
    MOI.set(model.source_model, attr, args...)

    return nothing
end

function MOI.supports(::VirtualModel{T}, ::SOURCE_MODEL_ATTRIBUES{T}) where {T}
    return true
end

function MOI.get(
    model::VirtualModel,
    attr::Union{MOI.ConstraintFunction,MOI.ConstraintSet},
    ci::MOI.ConstraintIndex,
)
    return MOI.get(model.source_model, attr, ci)
end

function MOI.get(model::VirtualModel, attr::MOI.VariableName, x::VI)
    return MOI.get(model.source_model, attr, x)
end

function MOI.add_variable(model::VirtualModel)
    return MOI.add_variable(model.source_model)
end

function MOI.add_constraint(
    model::VirtualModel,
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
)
    return MOI.add_constraint(model.source_model, f, s)
end

function MOI.set(
    model::VirtualModel,
    ::MOI.ObjectiveFunction{F},
    f::F,
) where {F<:MOI.AbstractFunction}
    MOI.set(model.source_model, MOI.ObjectiveFunction{F}(), f)

    return nothing
end
