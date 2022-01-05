using Test

# -*- Imports: Pseudo-Boolean Optimization -*-
include("../src/lib/pbo.jl")

function tests()
    @testset "GitHub CI Workflow" begin
        @test true
    end

    # -*- Tests: Pseudo-Boolean Optimization -*-
    @testset "Pseudo-Boolean Optimization Module" begin
        # -*- Definitions -*-
        ℱ = PBO.PBF{Symbol, Float64}
        ∅ = Vector{Symbol}()

        p = ℱ(∅ => 0.5, [:x] => 1.0, [:x, :y] => -2.0)
        q = ℱ(∅ => 0.5, [:y] => 1.0, [:x, :z] => -2.0)
        r = ℱ(∅ => 0.5, [:z] => 1.0, [:y, :z] => -2.0)
        s = ℱ(∅ => 1.0, [:x, :y, :z] => -1.0)

        # -*- Arithmetic: (+) -*-
        @test (p + q) == (q + p) == ℱ(
            ∅ => 1.0,
            [:x] => 1.0,
            [:y] => 1.0,
            [:x, :y] => -2.0,
            [:x, :z] => -2.0
        )

        @test (p + r) == (r + p) == ℱ(
            ∅ => 1.0,
            [:x] => 1.0,
            [:z] => 1.0,
            [:x, :y] => -2.0,
            [:y, :z] => -2.0
        )

        @test (p + s) == (s + p) == ℱ(
            ∅ => 1.5,
            [:x] => 1.0,
            [:x, :y] => -2.0,
            [:x, :y, :z] => -1.0
        )

        @test (q + r) == (r + q) == ℱ(
            ∅ => 1.0,
            [:y] => 1.0,
            [:z] => 1.0,
            [:x, :z] => -2.0,
            [:y, :z] => -2.0
        )

        @test (q + s) == (s + q) == ℱ(
            ∅ => 1.5,
            [:y] => 1.0,
            [:x, :z] => -2.0,
            [:x, :y, :z] => -1.0
        )

        @test (r + s) == (s + r) == ℱ(
            ∅ => 1.5,
            [:z] => 1.0,
            [:y, :z] => -2.0,
            [:x, :y, :z] => -1.0
        )

        # -*- Arithmetic: (-) -*-
        @test (p - q) == ℱ(
            [:x] => 1.0,
            [:y] => -1.0,
            [:x, :y] => -2.0,
            [:x, :z] => 2.0
        )

        @test (p - r) == ℱ(
            [:x] => 1.0,
            [:z] => -1.0,
            [:x, :y] => -2.0,
            [:y, :z] => 2.0
        )

        @test (p - s) == ℱ(
            ∅ => -0.5,
            [:x] => 1.0,
            [:x, :y] => -2.0,
            [:x, :y, :z] => 1.0
        )

        @test (q - r) == ℱ(
            [:y] => 1.0,
            [:z] => -1.0,
            [:x, :z] => -2.0,
            [:y, :z] => 2.0
        )

        @test (q - s) == ℱ(
            ∅ => -0.5,
            [:y] => 1.0,
            [:x, :z] => -2.0,
            [:x, :y, :z] => 1.0
        )

        @test (r - s) == ℱ(
            ∅ => -0.5,
            [:z] => 1.0,
            [:y, :z] => -2.0,
            [:x, :y, :z] => 1.0
        )

        # -*- Arithmetic: (*) -*-

        # -*- Arithmetic: (^) -*-
    end
end

tests()