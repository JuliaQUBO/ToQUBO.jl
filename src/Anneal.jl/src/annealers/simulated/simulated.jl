module SimulatedAnnealer

using PythonCall

using Anneal
using MathOptInterface
const MOI = MathOptInterface
const VI = MOI.VariableIndex

include("annealer.jl")
include("MOI_wrapper.jl")

end # module