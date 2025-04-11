include("continuous_1.jl")
include("continuous_2.jl")

function test_continuous()
    @testset "Continuous Variables" verbose = true begin
        test_continuous_1()
        test_continuous_2()
    end
end
