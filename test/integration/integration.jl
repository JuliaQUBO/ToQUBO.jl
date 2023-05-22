include("interface.jl")

function test_integration()
    @testset "Integration" verbose = true begin
        test_interface()
    end
end
