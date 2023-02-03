MOI.get(::VirtualModel, ::MOI.SolverName)    = "Virtual Model"
MOI.get(::VirtualModel, ::MOI.SolverVersion) = PROJECT_VERSION

const MOI_MODEL_ATTRIBUTE = Union{
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
}

function MOI.get(model::VirtualModel, attr::MOI_MODEL_ATTRIBUTE)
    return MOI.get(model.source_model, attr)
end

function MOI.set(model::VirtualModel, attr::MOI_MODEL_ATTRIBUTE, value::Any)
    MOI.set(model.source_model, attr, value)

    return nothing
end

function MOI.is_empty(model::VirtualModel)
    return MOI.is_empty(model.source_model)
end

function MOI.empty!(model::VirtualModel)
    MOI.empty!(model.source_model)
    MOI.empty!(model.target_model)

    empty!(model.variables)

    return nothing
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

function Base.show(io::IO, model::VirtualModel)
    print(
        io,
        """
        Virtual Model
        with source:
        $(model.source_model)
        with target:
        $(model.target_model)
        """,
    )
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