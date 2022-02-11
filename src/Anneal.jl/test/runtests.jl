using Test
using Anneal

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# -*- QUBO Models -*-
include("qubo.jl")

# -*- Simulated Annealing -*-
include("annealers/simulated.jl")

# -*- Simulated Annealing -*-
include("annealers/quantum.jl")

# -*- Simulated Annealing -*-
include("annealers/digital.jl")