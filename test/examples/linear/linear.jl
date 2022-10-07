include("linear1.jl")
include("linear2.jl")

function test_linear()
    @testset "Linear Programs" verbose = true begin
        test_linear1()
        test_linear2()
    end
end