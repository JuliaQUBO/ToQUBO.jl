module Anneal

using MathOptInterface
const MOI = MathOptInterface

const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAF{T} = MOI.ScalarAffineFunction{T}
const VI = MOI.VariableIndex

# -*- Exports: Submodules -*-
export Simulated
export Quantum
export Digital

# -*- Exports: Attributes -*-
export NumberOfReads

# -*- Includes: Anneal -*-
include("error.jl")
include("qubo.jl")
include("sample.jl")
include("annealer.jl")
include("MOI_wrapper.jl")
include("view.jl")

# -*- Includes: Submodules -*-
include("digital/digital.jl")
include("quantum/quantum.jl")
include("simulated/simulated.jl")

end # module