function MOI.is_empty(model::AbstractVirtualModel)
    all([
        MOI.is_empty(MOI.get(model, SourceModel())),
        MOI.is_empty(MOI.get(model, TargetModel())),
        isempty(MOI.get(model, Variables()))
    ])
end

function MOI.empty!(model::AbstractVirtualModel)
    MOI.empty!(MOI.get(model, SourceModel()))
    MOI.empty!(MOI.get(model, TargetModel()))
    empty!(MOI.get(model, Variables()))

    nothing
end

function MOI.get(
    model::AbstractVirtualModel,
    attr::Union{
        MOI.ListOfConstraintAttributesSet,
        MOI.ListOfConstraintIndices,
        MOI.ListOfConstraintTypesPresent,
        MOI.ListOfModelAttributesSet,
        MOI.ListOfVariableAttributesSet,
        MOI.ListOfVariableIndices,
        MOI.NumberOfConstraints,
        MOI.NumberOfVariables,
        MOI.Name,
        MOI.ObjectiveFunction,
        MOI.ObjectiveFunctionType,
        MOI.ObjectiveSense,
    })
    MOI.get(MOI.get(model, SourceModel()), attr)
end

function MOI.get(
    model::AbstractVirtualModel,
    attr::Union{
        MOI.ConstraintFunction,
        MOI.ConstraintSet,
    },
    ci::MOI.ConstraintIndex,
    )
    MOI.get(MOI.get(model, SourceModel()), attr, ci)
end

function MOI.set(
    model::AbstractVirtualModel,
    attr::Union{
        MOI.ObjectiveFunction,
        MOI.ObjectiveSense,
    },
    value::Any)
    MOI.get(MOI.get(model, SourceModel()), attr, value)
end

function MOI.get(model::AbstractVirtualModel, attr::MOI.VariableName, x::VI)
    MOI.get(MOI.get(model, VM.SourceModel()), attr, x)
end