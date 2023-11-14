include("quadratic_1.jl")
include("primes.jl")

function test_quadratic()
    @testset "Quadratic Programs" verbose = true begin
        test_quadratic_1()
        test_primes()
    end
end
