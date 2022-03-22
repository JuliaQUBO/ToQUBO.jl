module Anneal

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}
const SAF{T} = MOI.ScalarAffineFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- Exports: Submodules -*-
export ExactSampler, RandomSampler, IdentitySampler
export SimulatedAnnealer

# -*- Includes: Anneal -*-
include("error.jl")
include("qubo.jl")
include("sampler.jl")
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