# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "Random Sampler"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return v"1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(sampler::Optimizer, ::MOI.RawSolver)
    return sampler
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
# function MOI.set(sampler::Optimizer, ::RandomBias, bias::Float64)
#     if !(0.0 <= bias <= 1.0)
#         error("Invalid bias i.e. not in [0, 1]")
#     end

#     sampler.settings.RandomBias = bias

#     nothing
# end

# function MOI.set(sampler::Optimizer, ::RandomSeed, seed::Int)
#     sampler.settings.RandomSeed = seed
#     sampler.settings.RandomGenerator = MersenneTwister(seed)

#     nothing
# end