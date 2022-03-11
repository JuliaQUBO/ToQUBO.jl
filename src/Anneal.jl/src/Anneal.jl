module Anneal

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAF{T} = MOI.ScalarAffineFunction{T}
const VI = MOI.VariableIndex

# -*- Exports: Python -*-
export python_import, PyNULL

# -*- Exports: Submodules -*-
export ExactSampler, RandomSampler, IdentitySampler
export SimulatedAnnealer

# -*- Exports: Attributes -*-
export NumberOfReads, NumberOfSweeps, RandomBias, RandomSeed

# -*- Includes: Anneal -*-
include("error.jl")
include("qubo.jl")
include("sampler.jl")
include("annealer.jl")
include("pyimport.jl")
include("MOI_wrapper.jl")

# -*- Includes: Submodules -*-
# :: Samplers ::
include("samplers/random/random.jl")
using .RandomSampler

include("samplers/exact/exact.jl")
using .ExactSampler

include("samplers/identity/identity.jl")
using .IdentitySampler

# :: Annealers ::
include("annealers/simulated/simulated.jl")
using .SimulatedAnnealer

end # module