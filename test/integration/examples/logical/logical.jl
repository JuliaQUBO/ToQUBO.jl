include("logical_tsp.jl")
include("logical_sos.jl")
include("indicator.jl")

function test_logical()
    @testset "Logical Programs" verbose = true begin
        test_logical_sos1()
        test_logical_tsp()
        test_indicator()
    end

    return nothing
end
