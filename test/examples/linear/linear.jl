include("linear1.jl")

function test_linear()
    @testset "Linear Binary Program" verbose = true begin
        test_linear1()
    end
end