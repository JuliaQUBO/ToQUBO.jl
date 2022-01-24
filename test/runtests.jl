using Test
using LinearAlgebra

import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex

# -*- Imports: ToQUBO -*-
using ToQUBO

function tests()
    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Pseudo-Boolean Optimization Module" begin
        include("./lib/pbo.jl")
    end

    # -*- Tests: Annealing -*-
    @testset "Annealing Module" begin
        include("./lib/anneal.jl")
    end

    # -*- Tests: Virtual Mapping -*-
    @testset "VirtualMapping Module" begin
        include("./lib/virtual.jl")
    end

    # -*- Tests: QUBO Model Assembly -*-
    @testset "Models" begin
        include("./models/models.jl")
    end
end

tests()