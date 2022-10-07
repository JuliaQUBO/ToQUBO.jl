include("qba/qba.jl")
include("linear/linear.jl")
include("quadratic/quadratic.jl")

function test_examples()
    @testset "Examples" verbose = true begin
        test_qba()
        test_linear()
        test_quadratic()
    end
end