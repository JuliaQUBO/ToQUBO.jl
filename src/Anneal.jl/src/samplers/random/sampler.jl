# -*- :: Random sampler :: -*-
struct RandomBias <: MOI.AbstractOptimizerAttribute end
struct RandomSeed <: MOI.AbstractOptimizerAttribute end

Anneal.@anew_sampler begin
    num_reads::Int = 1_000
    random_bias::Float64 = 0.5
    random_seed::Int = trunc(Int, time())
    random_rng::Any = nothing
end

function Anneal.init!(sampler::Optimizer)
    sampler.settings.random_rng = MersenneTwister(sampler.settings.random_seed)
end

# -*- :: Biased Random State Generation :: -*-
function random_sample(sampler::Optimizer)
    s = Int.(rand(sampler.settings.random_rng, sampler.n) .< sampler.settings.random_bias)
    
    return (s, 1, Anneal.energy(sampler, s))
end

function Anneal.sample(sampler::Optimizer)
    t₀ = time()
    samples = [random_sample(sampler) for _ = 1:sampler.settings.num_reads]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end 