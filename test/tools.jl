function _variable_indices(model)
    return MOI.get(model, MOI.ListOfVariableIndices())
end

function _constraint_indices(model)
    c = []

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        append!(c, MOI.get(model, MOI.ListOfConstraintIndices{F,S}()))
    end

    return c
end