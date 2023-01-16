function is_qubo(model::MOI.ModelLike)
    return is_quadratic(model) &&
           is_unconstrained(model) &&
           is_binary(model) &&
           is_optimization(model)
end

function is_quadratic(model::MOI.ModelLike)
    return MOI.get(model, MOI.ObjectiveFunctionType()) <: Union{SQF,SAF,VI}
end

function is_unconstrained(model::MOI.ModelLike)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if !(F === VI && S === MOI.ZeroOne)
            return false
        end
    end

    return true
end

function is_binary(model::MOI.ModelLike)
    m = MOI.get(model, MOI.NumberOfConstraints{VI,MOI.ZeroOne}())
    n = MOI.get(model, MOI.NumberOfVariables())

    # There will be uncovered variables in this case:
    if m < n
        return false
    end

    𝔹 = sizehint!(Set{VI}(), n)

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.ZeroOne}())
        push!(𝔹, MOI.get(model, MOI.ConstraintFunction(), ci))
    end

    for vi in MOI.get(model, MOI.ListOfVariableIndices())
        if vi ∉ 𝔹 # Non-binary variable found
            return false
        end
    end

    return true
end

function is_optimization(model::MOI.ModelLike)
    S = MOI.get(model, MOI.ObjectiveSense())

    return (S === MOI.MAX_SENSE || S === MOI.MIN_SENSE)
end