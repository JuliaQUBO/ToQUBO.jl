# Objective Support
function supported_objective(model::MOIU.Model{T}) where T
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    if !__supported_objective(F)
        error("Objective functions of type ", F, " are not implemented")
    end
    return
end

__supported_objective(::Type) = false
__supported_objective(::VI) = true
__supported_objective(::SAF) = true

# Constraint Support
function supported_constraints(model::MOIU.Model{T}) where T
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if !__supported_constraint(F, S)
            error(
                "Constraints of function ",
                F,
                " in the Set ",
                S,
                " are not implemented",
            )
        end
    end
    return
end

__supported_constraint(::Type, ::Type) = false