# -*- :: Random sampler :: -*-
Anneal.@anew begin
    NumberOfReads::Int   = 1_000
    RandomBias::Float64  = 0.5
    RandomSeed::Int      = 0
    RandomGenerator::Any = MersenneTwister(0)
end

# -*- :: Biased Random State Generation :: -*-
function random_sample(sampler::Optimizer)
    s = Int.(rand(sampler.settings.RandomGenerator, sampler.n) .< sampler.settings.RandomBias)
    
    return (s, 1, Anneal.energy(sampler, s))
end

function Anneal.sample(sampler::Optimizer)
    t₀ = time()
    samples = [random_sample(sampler) for _ = 1:sampler.settings.NumberOfReads]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end 