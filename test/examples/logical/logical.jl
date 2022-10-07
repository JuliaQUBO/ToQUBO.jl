include("logical_sos.jl")

function test_logical()
    @testset "Logical Programs" verbose=true begin
        test_logical_sos1()
    end
end