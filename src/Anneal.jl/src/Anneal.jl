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

# -*- Includes: Anneal -*-
include("error.jl")
include("qubo.jl")
include("sampler.jl")
include("MOI_wrapper.jl")

# -*- Includes: Submodules -*-
# :: Samplers ::
include("samplers/random/random.jl")
export RandomSampler

include("samplers/exact/exact.jl")
export ExactSampler

include("samplers/identity/identity.jl")
export IdentitySampler

# :: Annealers ::
include("annealers/simulated/simulated.jl")
export SimulatedAnnealer

end # module
