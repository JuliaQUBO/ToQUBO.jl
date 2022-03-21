# -*- :: Exact Sampler :: -*-
Anneal.@anew begin end

function Anneal.sample(sampler::Optimizer)
    m = 2 ^ sampler.n

    samples = Anneal.SamplerResults(undef, m)

    t₀ = time()
    for k = 1:m
        s = digits(k - 1; base=2, pad=sampler.n)
        samples[k] = (s, 1, Anneal.energy(sampler, s))
    end
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end