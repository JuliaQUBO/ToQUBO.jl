# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "Random Sampler"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return "v1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::Optimizer, ::MOI.RawSolver)
    return "Random Sampler"
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
function MOI.get(sampler::Optimizer, ::RandomBias)
    return sampler.settings.random_bias
end

function MOI.set(sampler::Optimizer, ::RandomBias, random_bias::Float64)
    if !(0.0 <= random_bias <= 1.0)
        error("Invalid bias i.e. not in [0, 1]")
    end

    sampler.settings.random_bias = random_bias

    nothing
end

function MOI.get(sampler::Optimizer, ::RandomSeed)
    return sampler.settings.random_seed
end

function MOI.set(sampler::Optimizer, ::RandomSeed, random_seed::Int)
    sampler.settings.random_seed = random_seed
    sampler.settings.random_rng = MersenneTwister(sampler.settings.random_seed)

    nothing
end