module RandomSampler

using Anneal
using MathOptInterface
const MOI = MathOptInterface
using Random

export RandomBias, RandomSeed

include("sampler.jl")
include("MOI_wrapper.jl")

end # module