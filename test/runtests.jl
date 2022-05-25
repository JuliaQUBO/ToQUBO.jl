using Test

# -*- MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex

# -*- Imports -*-
using JuMP
using ToQUBO
using Anneal
using LinearAlgebra
using TOML

const VM = ToQUBO.VirtualMapping

# -*- Tests: Version -*-
include("version.jl")

# -*- Tests: Library -*-
include("./lib/pbo.jl")
include("./lib/virtual.jl")

# -*- Tests: Interface -*-
# include("./lib/moi.jl")
# include("./lib/jump.jl")

# -*- Tests: Examples -*-
@testset "Quantum Bridge Analytics I" begin
    include("examples/qba2.jl")
    include("examples/qba3_1.jl")
    include("examples/qba3_2.jl")
end