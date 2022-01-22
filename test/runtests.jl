using Test

# -*- Imports: ToQUBO -*-
using ToQUBO

# -*- Import : MOI -*-
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex

function tests()
    @testset "GitHub CI Workflow" begin
        @test true
    end

    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Pseudo-Boolean Optimization Module" begin
        include("./lib/pbo.jl")
    end

    # -*- Tests: Annealing -*-
    @testset "Annealing Module" begin
        include("./lib/anneal.jl")
    end

    # -*- Tests: Varmap
    @testset "VarMap" begin
        include("./lib/varmap.jl")
    end

    # -*- Tests: QUBO Model Assembly -*-
    @testset "Models" begin
        include("./models/models.jl")
    end
end

tests()