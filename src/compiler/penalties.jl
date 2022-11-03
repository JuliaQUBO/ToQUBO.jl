function toqubo_penalties!(model::VirtualQUBOModel{T}, ::AbstractArchitecture) where {T}
    # -*- :: Invert Sign ::  -*- #
    s = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    β = one(T) # TODO: This should be made a parameter too? Yes!
    δ = PBO.gap(model.f)

    for (vi, g) in model.g
        ϵ = PBO.sharpness(g)

        model.ρ[vi] = s * (δ / ϵ + β)
    end

    for (ci, h) in model.h
        ϵ = PBO.sharpness(h)

        model.ρ[ci] = s * (δ / ϵ + β)
    end

    return nothing
end