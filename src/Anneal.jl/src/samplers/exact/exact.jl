module ExactSampler

using Anneal
using MathOptInterface
const MOI = MathOptInterface

include("sampler.jl")
include("MOI_wrapper.jl")

end # module