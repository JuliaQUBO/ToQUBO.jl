include("qba/qba.jl")
include("linear/linear.jl")
include("quadratic/quadratic.jl")
include("logical/logical.jl")
include("integer/integer.jl")

function test_examples()
    @testset "Examples" verbose = true begin
        test_qba()
        test_linear()
        test_quadratic()
        test_logical()
        test_integer()
    end
end