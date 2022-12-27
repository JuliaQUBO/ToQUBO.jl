include("logical_tsp.jl")
include("logical_sos.jl")

function test_logical()
    @testset "Logical Programs" verbose=true begin
        test_logical_sos1()
        test_logical_tsp()
    end
end