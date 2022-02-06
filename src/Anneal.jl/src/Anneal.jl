module Anneal

using MathOptInterface
const MOI = MathOptInterface

const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAF{T} = MOI.ScalarAffineFunction{T}
const VI = MOI.VariableIndex

# -*- Exports -*-
export SimulatedAnnealer, QuantumAnnealer, DigitalAnnealer

include("error.jl")
include("qubo.jl")
include("sample.jl")
include("annealer.jl")
include("MOI_wrapper.jl")
include("view.jl")

end # module