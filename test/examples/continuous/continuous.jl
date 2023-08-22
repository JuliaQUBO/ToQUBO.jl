include("continuous_1.jl")

function test_continuous()
    @testset "Continuous Variables" verbose = true begin
        test_continuous_1() 
    end
end