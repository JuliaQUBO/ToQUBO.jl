using Test
using LinearAlgebra

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex

# -*- Imports: ToQUBO -*-
using ToQUBO

# -*- Imports: Anneal -*-
using Pkg; Pkg.develop(path=joinpath("..", "src", "Anneal.jl"))
using Anneal

const VM = ToQUBO.VirtualMapping

function Base.show(io::IO, v::VI)
    print(io, "v[$(v.value)]")
end

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")

# -*- Tests: ToQUBO UI -*-
include("toqubo.jl")