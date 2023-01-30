function toqubo_penalties!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    # -*- :: Invert Sign ::  -*- #
    s = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
    δ = PBO.gap(model.f)

    for (ci, g) in model.g
        ϵ = PBO.sharpness(g)

        model.ρ[ci] = s * (δ / ϵ + β)
    end

    for (vi, h) in model.h
        ϵ = PBO.sharpness(h)

        model.θ[vi] = s * (δ / ϵ + β)
    end

    return nothing
end