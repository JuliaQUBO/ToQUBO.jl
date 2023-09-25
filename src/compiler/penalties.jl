function penalties!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    # Adjust Sign
    s = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
    δ = PBO.maxgap(model.f)

    for (ci, g) in model.g
        ρ = MOI.get(model, Attributes.ConstraintEncodingPenalty(), ci)

        if ρ === nothing
            ϵ = PBO.mingap(g)
            ρ = s * (δ / ϵ + β)
        end

        model.ρ[ci] = ρ
    end

    for (vi, h) in model.h
        ρ = MOI.get(model, Attributes.VariableEncodingPenalty(), vi)

        if ρ === nothing
            ϵ = PBO.mingap(h)
            ρ = s * (δ / ϵ + β)
        end

        model.θ[vi] = ρ
    end

    return nothing
end
