module SimulatedAnnealer

using Anneal
using MathOptInterface
const MOI = MathOptInterface

export NumberOfSweeps

include("annealer.jl")
include("MOI_wrapper.jl")

end # module