function sense!(model::VirtualModel, ::AbstractArchitecture)
    if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    else
        # Feasibility is interpreted as minimization
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    end

    return nothing
end

function objective!(model::VirtualModel, arch::AbstractArchitecture)
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    parse!(model, model.f, f, arch)

    return nothing
end
