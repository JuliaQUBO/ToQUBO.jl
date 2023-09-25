function penalties!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    # Adjust Sign
    s = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
    δ = PBO.maxgap(model.f)

    for (ci, g) in model.g
        ρ = Attributes.constraint_encoding_penalty(model, ci)

        if isnothing(ρ)
            ϵ = PBO.mingap(g)
            ρ = s * (δ / ϵ + β)
        end

        model.ρ[ci] = ρ
    end

    for (vi, h) in model.h
        θ = Attributes.variable_encoding_penalty(model, vi)

        if isnothing(θ)
            ϵ = PBO.mingap(h)
            θ = s * (δ / ϵ + β)
        end

        model.θ[vi] = θ
    end

    return nothing
end
