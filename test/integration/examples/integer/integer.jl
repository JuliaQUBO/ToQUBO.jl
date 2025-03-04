include("integer_1.jl")

function test_integer()
    @testset "Integer Variables" verbose = true begin
        test_integer_1()
    end

    return nothing
end
