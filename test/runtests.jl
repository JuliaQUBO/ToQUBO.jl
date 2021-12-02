using Test

function tests()
    @testset "PosiformTest" begin
        include("../src/posiform.jl")

        ∅ = Vector{Int}()

        p = Posiform{Int, Float64}([1] => 0.3, [1,2] => -0.5, [2,3] => 1.2)
        q = Posiform{Int, Float64}([1] => -0.3, [1,2] => 2.5, [2,3] => 1.0, ∅ => 2.0)

        @test (p + q) == Posiform{Int, Float64}([1, 2] => 2.0, [2, 3] => 2.2, ∅ => 2.0)
    end
end

tests()