using Test
using Pkg
Pkg.develop(path=joinpath(@__DIR__, "..", "src", "Anneal.jl"))

# -*- MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex

# -*- Imports -*-
using ToQUBO
using Anneal
using LinearAlgebra

const VM = ToQUBO.VirtualMapping

function Base.show(io::IO, v::VI)
    print(io, "v[$(v.value)]")
end

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")

# -*- Tests: ToQUBO UI -*-
include("toqubo.jl")