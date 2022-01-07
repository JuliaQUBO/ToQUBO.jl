using Test

# -*- Imports: Pseudo-Boolean Optimization -*-
include("../src/lib/pbo.jl")

function tests()
    @testset "GitHub CI Workflow" begin
        @test true
    end

    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Pseudo-Boolean Optimization Module" begin
        include("./lib/pbo.jl")
    end

    # -*- Tests: QUBO Model Assembly -*-
    @testset "Models" begin
        @test true
    end
end

tests()