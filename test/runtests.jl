using Test

# -*- MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- Imports -*-
# using JuMP
using ToQUBO: ToQUBO, PBO, VirtualMapping
# using Anneal
using LinearAlgebra
using TOML

# -*- Tests: Version -*-
include("version.jl")

# -*- Tests: Library -*-
include(joinpath("lib", "pbo.jl"))
include(joinpath("lib", "virtual.jl"))

# -*- Tests: Interface -*-
# include(joinpath("interface", "moi.jl"))
# include(joinpath("interface", "jump.jl"))

# -*- Tests: Examples -*-
# @testset "Quantum Bridge Analytics I" begin
#     include(joinpath("examples", "qba2.jl"))
#     include(joinpath("examples", "qba3_1.jl"))
#     include(joinpath("examples", "qba3_2.jl"))
# end