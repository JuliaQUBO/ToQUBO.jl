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

include("samplers/exact/exact.jl")

include("samplers/identity/identity.jl")

# :: Annealers ::
include("annealers/simulated/simulated.jl")

end # module
