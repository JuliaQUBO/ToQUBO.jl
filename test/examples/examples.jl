include("qba/qba.jl")
include("linear/linear.jl")

function test_examples()
    @testset "Examples" verbose = true begin
        test_qba()
        test_linear()
    end
end