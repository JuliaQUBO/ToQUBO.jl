function sense!(model::Virtual.Model, ::AbstractArchitecture)
    if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    else
        # Feasibility is interpreted as minimization
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    end

    return nothing
end

function _validate_objective_scalarization!(
    model::Virtual.Model,
    num_objectives::Int,
)
    weights = get(model.compiler_settings, :objective_weights, nothing)
    if !isnothing(weights) && length(weights) != num_objectives
        compilation_error!(
            model,
            "ObjectiveWeights length ($(length(weights))) does not match number of objective components ($num_objectives)";
            status = "Invalid objective weights",
        )
    end

    weight_overrides = get(model.compiler_settings, :objective_weight, nothing)
    if !isnothing(weight_overrides)
        for idx in sort!(collect(keys(weight_overrides)))
            if !(1 <= idx <= num_objectives)
                compilation_error!(
                    model,
                    "ObjectiveWeight index ($idx) is out of bounds for $num_objectives objective component(s)";
                    status = "Invalid objective weight index",
                )
            end
        end
    end

    senses = get(model.compiler_settings, :objective_senses, nothing)
    if !isnothing(senses) && length(senses) != num_objectives
        compilation_error!(
            model,
            "ObjectiveSenses length ($(length(senses))) does not match number of objective components ($num_objectives)";
            status = "Invalid objective senses",
        )
    end

    sense_overrides = get(model.compiler_settings, :objective_sense, nothing)
    if !isnothing(sense_overrides)
        for idx in sort!(collect(keys(sense_overrides)))
            if !(1 <= idx <= num_objectives)
                compilation_error!(
                    model,
                    "ObjectiveSense index ($idx) is out of bounds for $num_objectives objective component(s)";
                    status = "Invalid objective sense index",
                )
            end
        end
    end

    return nothing
end

function objective!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    parse!(model, model.f_components, f, arch)

    k = length(model.f_components)
    _validate_objective_scalarization!(model, k)

    Base.empty!(model.f)

    if k == 1 && !Attributes._has_custom_objective_scalarization(model)
        for (ω, c) in model.f_components[1]
            model.f[ω] = c
        end
    else
        target_sense = MOI.get(model.target_model, MOI.ObjectiveSense())

        for i = 1:k
            w_i = Attributes.objective_weight(model, i)
            s_i = Attributes.objective_sense(model, i)
            rel_sign = s_i === target_sense ? one(T) : -one(T)
            scale = rel_sign * w_i

            iszero(scale) && continue

            for (ω, c) in model.f_components[i]
                model.f[ω] += scale * c

                if !isfinite(model.f[ω])
                    compilation_error!(
                        model,
                        "Objective scalarization produced a non-finite coefficient";
                        status = "Non-finite scalarized objective coefficient",
                    )
                end
            end
        end
    end

    if PBO.degree(model.f) > 2
        MOI.set(model, Attributes.Quadratize(), true)
    end

    return nothing
end
