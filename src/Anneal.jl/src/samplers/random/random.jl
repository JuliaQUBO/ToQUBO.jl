module RandomSampler

using Anneal
using Random
using MathOptInterface
const MOI = MathOptInterface
const VI = MOI.VariableIndex

include("sampler.jl")
include("MOI_wrapper.jl")

end # module