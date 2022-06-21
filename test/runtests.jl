using Test

# -*- MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- Imports -*-
using JuMP
using ToQUBO: ToQUBO, PBO, VM
using Anneal
using LinearAlgebra
using TOML


@testset "ToQUBO.jl" verbose = true begin
# -*- Tests: Version -*-
include("version.jl")

# -*- Tests: Library -*-
include(joinpath("lib", "pbo.jl"))
include(joinpath("lib", "virtual.jl"))

# -*- Tests: Interface -*-
include(joinpath("interface", "moi.jl"))
include(joinpath("interface", "jump.jl"))

# -*- Tests: Examples -*-
# include(joinpath("examples", "qba.jl"))
end