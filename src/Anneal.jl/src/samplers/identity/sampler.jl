# -*- :: Identity Sampler :: -*-
Anneal.@anew_sampler begin end;

function identity_sample(sampler::Optimizer{T}) where {T}
    s = Vector{Int}(undef, sampler.n)

    for (xᵢ, i) ∈ sampler.x
        if i === nothing
            continue
        end

        sᵢ = MOI.get(sampler, MOI.VariablePrimalStart(), xᵢ)

        s[i] = (sᵢ === nothing) ? 0 : convert(Int, sᵢ > zero(T))
    end

    return (s, 1, Anneal.energy(sampler, s))
end

# -*- :: Identity Sampler :: -*-
function Anneal.sample(sampler::Optimizer)
    t₀ = time()
    samples = [identity_sample(sampler)]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end 