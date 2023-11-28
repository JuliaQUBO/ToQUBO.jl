include("qba/qba.jl")
include("linear/linear.jl")
include("quadratic/quadratic.jl")
include("logical/logical.jl")
include("continuous/continuous.jl")
include("corner/corner.jl")

function test_examples()
    @testset "□ Examples" verbose = true begin
        # test_qba()
        # test_linear()
        # test_quadratic()
        # test_logical()
        # test_continuous()
        test_corner()
    end

    return nothing
end
