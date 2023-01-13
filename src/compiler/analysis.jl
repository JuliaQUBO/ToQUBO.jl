function is_qubo(model::MOI.ModelLike)
    return is_optimization(model) && is_quadratic(model) && is_unconstrained(model)
end

function is_quadratic(model::MOI.ModelLike)
    return MOI.get(model, MOI.ObjectiveFunctionType()) <: Union{SQF,SAF,VI}
end

function is_unconstrained(model::MOI.ModelLike)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if !(F === VI && (S === MOI.ZeroOne || S === Spin))
            return false
        end
    end

    return true
end

function is_optimization(model::MOI.ModelLike)
    S = MOI.get(model, MOI.ObjectiveSense())

    return (S === MOI.MAX_SENSE || S === MOI.MIN_SENSE)
end