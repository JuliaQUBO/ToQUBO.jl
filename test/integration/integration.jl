include("interface.jl")
include("examples/examples.jl")

function test_integration()
    @testset "Integration" verbose = true begin
        test_interface()
        test_examples()
    end

    return nothing
end
