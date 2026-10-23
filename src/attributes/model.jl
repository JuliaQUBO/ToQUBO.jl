MOI.get(::Virtual.Model, ::MOI.SolverName)    = "Virtual QUBO Model"
MOI.get(::Virtual.Model, ::MOI.SolverVersion) = "v$(__version__())"

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

function MOI.get(model::Virtual.Model{T}, attr::SOURCE_MODEL_ATTRIBUES{T}, args...) where {T}
    return MOI.get(model.source_model, attr, args...)
end

function MOI.set(model::Virtual.Model{T}, attr::SOURCE_MODEL_ATTRIBUES{T}, args::Any...) where {T}
    MOI.set(model.source_model, attr, args...)

    return nothing
end

function MOI.supports(::Virtual.Model{T}, ::SOURCE_MODEL_ATTRIBUES{T}) where {T}
    return true
end

function MOI.get(
    model::Virtual.Model,
    attr::Union{MOI.ConstraintFunction,MOI.ConstraintSet},
    ci::MOI.ConstraintIndex,
)
    return MOI.get(model.source_model, attr, ci)
end

function MOI.get(model::Virtual.Model, attr::MOI.VariableName, x::VI)
    return MOI.get(model.source_model, attr, x)
end

function MOI.add_variable(model::Virtual.Model)
    return MOI.add_variable(model.source_model)
end

function MOI.add_constraint(
    model::Virtual.Model,
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
)
    return MOI.add_constraint(model.source_model, f, s)
end

function MOI.set(
    model::Virtual.Model,
    ::MOI.ObjectiveFunction{F},
    f::F,
) where {F<:MOI.AbstractFunction}
    MOI.set(model.source_model, MOI.ObjectiveFunction{F}(), f)

    return nothing
end

function MOI.get(model::Virtual.Model, ::MOI.ListOfVariableAttributesSet)
    list = MOI.AbstractVariableAttribute[
        a for a in MOI.get(model.source_model, MOI.ListOfVariableAttributesSet())
    ]

    if !isnothing(model.optimizer)
        for a in MOI.get(model.optimizer, MOI.ListOfVariableAttributesSet())
            a in list || push!(list, a)
        end
    end

    for (key, val) in model.variable_settings
        isempty(val) && continue

        attr = Attributes._attribute_from_key(Val(key))()::MOI.AbstractVariableAttribute
        attr in list || push!(list, attr)
    end

    return list
end

function MOI.get(
    model::Virtual.Model,
    attr::MOI.ListOfConstraintAttributesSet{F,S},
) where {F,S}
    list = MOI.AbstractConstraintAttribute[
        a for a in MOI.get(model.source_model, attr)
    ]

    for (key, val) in model.constraint_settings
        any(ci -> ci isa MOI.ConstraintIndex{F,S}, keys(val)) || continue

        con_attr = Attributes._attribute_from_key(Val(key))()::MOI.AbstractConstraintAttribute
        con_attr in list || push!(list, con_attr)
    end

    return list
end
