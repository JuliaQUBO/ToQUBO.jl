include("quadratic1.jl")

function test_quadratic()
    @testset "Quadratic Programs" verbose = true begin
        test_quadratic1() 
    end
end