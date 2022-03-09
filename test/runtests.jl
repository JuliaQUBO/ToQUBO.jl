using Test
using LinearAlgebra

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex

# -*- Imports: ToQUBO -*-
using ToQUBO
using Anneal

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")

# -*- Tests: ToQUBO UI -*-
include("toqubo.jl")