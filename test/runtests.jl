using Test

# -*- MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex

# -*- Imports -*-
using ToQUBO
include("../src/Anneal.jl/src/Anneal.jl")
using .Anneal
using LinearAlgebra
using TOML

const VM = ToQUBO.VirtualMapping

function Base.show(io::IO, v::VI)
    print(io, "v[$(v.value)]")
end

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")


# -*- Tests: Version -*-
include("version.jl")

# -*- Tests: ToQUBO -*-
include("toqubo.jl")