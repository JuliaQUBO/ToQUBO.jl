include("attributes.jl")

function test_integration()
    @testset "Integration" verbose = true begin
        test_attributes()
    end
end