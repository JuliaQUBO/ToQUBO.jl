using Test
using LinearAlgebra

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex

# -*- Imports: ToQUBO -*-
using ToQUBO

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")

# -*- Tests: QUBO Model Assembly -*-
# include("./models/models.jl")