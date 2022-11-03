include("integer_primes.jl")

function test_integer()
    @testset "Integer Programs" verbose = true begin
        test_integer_primes()
    end
end