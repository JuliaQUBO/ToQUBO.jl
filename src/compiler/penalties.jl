function _uses_linear_equality_penalty(model::Virtual.Model, ci::CI)::Bool
    return MOI.get(model, MOI.ConstraintSet(), ci) isa MOI.EqualTo &&
           Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty
end

function penalties!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Adjust Sign
    σ = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
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
            ρ = σ * (δ / ϵ + β)
        end

        MOI.set(model, Attributes.ConstraintEncodingPenalty(), ci, ρ)
    end

    for (vi, h) in model.h
        θ = Attributes.variable_encoding_penalty_hint(model, vi)

        if isnothing(θ)
            ϵ = PBO.mingap(h)
            θ = σ * (δ / ϵ + β)
        end

        MOI.set(model, Attributes.VariableEncodingPenalty(), vi, θ)
    end

    for (ci, s) in model.s
        η = Attributes.slack_variable_encoding_penalty_hint(model, ci)

        if isnothing(η)
            ϵ = PBO.mingap(s)
            η = σ * (δ / ϵ + β)
        end

        MOI.set(model, Attributes.SlackVariableEncodingPenalty(), ci, η)
    end

    return nothing
end
