using Test
using Anneal

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# -*- QUBO Models -*-
include("qubo.jl")

# -*- Simulated Annealing -*-
include("simulated.jl")

# -*- Simulated Annealing -*-
include("quantum.jl")

# -*- Simulated Annealing -*-
include("digital.jl")