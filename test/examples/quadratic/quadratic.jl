include("quadratic_1.jl")

function test_quadratic()
    @testset "Quadratic Programs" verbose = true begin
        test_quadratic_1() 
    end
end