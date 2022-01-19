using Test

# -*- Imports: ToQUBO -*-
using ToQUBO

# -*- Import : MOI -*-
import MathOptInterface
const MOI = MathOptInterface

function tests()
    @testset "GitHub CI Workflow" begin
        @test true
    end

    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Pseudo-Boolean Optimization Module" begin
        include("./lib/pbo.jl")
    end

    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Annealing Module" begin
        include("./lib/anneal.jl")
    end

    # -*- Tests: QUBO Model Assembly -*-
    @testset "Models" begin
        @test true
    end
end

tests()