using Test
using Anneal

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# -*- QUBO Models -*-
include("qubo.jl")

# -*- Samplers -*-
include("samplers/exact.jl")
include("samplers/identity.jl")
include("samplers/random.jl")

# -*- Annealers -*-
include("annealers/simulated.jl")