function _uses_linear_equality_penalty(model::Virtual.Model, ci::CI)::Bool
    return MOI.get(model, MOI.ConstraintSet(), ci) isa MOI.EqualTo &&
           Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty
end

function _inferred_penalty_factor(sign, δ, ϵ, scale, offset)
    return scale * sign * (δ / ϵ + offset)
end

function penalties!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Adjust Sign
    σ = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    δ = PBO.maxgap(model.f)

    for (ci, g) in model.g
        ρ = Attributes.constraint_encoding_penalty_hint(model, ci)

        if isnothing(ρ)
            if _uses_linear_equality_penalty(model, ci)
                compilation_error!(
                    model,
                    "LinearPenalty requires an explicit ConstraintEncodingPenaltyHint";
                    status = "Missing linear constraint penalty hint",
                )
            end

            ϵ = PBO.mingap(g)
            ρ = _inferred_penalty_factor(
                σ,
                δ,
                ϵ,
                Attributes.constraint_penalty_scale(model, ci),
                Attributes.constraint_penalty_offset(model, ci),
            )
        end

        MOI.set(model, Attributes.ConstraintEncodingPenalty(), ci, ρ)
    end

    for (vi, h) in model.h
        θ = Attributes.variable_encoding_penalty_hint(model, vi)

        if isnothing(θ)
            ϵ = PBO.mingap(h)
            θ = _inferred_penalty_factor(
                σ,
                δ,
                ϵ,
                Attributes.penalty_scale(model),
                Attributes.penalty_offset(model),
            )
        end

        MOI.set(model, Attributes.VariableEncodingPenalty(), vi, θ)
    end

    for (ci, s) in model.s
        η = Attributes.slack_variable_encoding_penalty_hint(model, ci)

        if isnothing(η)
            ϵ = PBO.mingap(s)
            η = _inferred_penalty_factor(
                σ,
                δ,
                ϵ,
                Attributes.constraint_penalty_scale(model, ci),
                Attributes.constraint_penalty_offset(model, ci),
            )
        end

        MOI.set(model, Attributes.SlackVariableEncodingPenalty(), ci, η)
    end

    return nothing
end
