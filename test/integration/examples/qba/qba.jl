include("qba2.jl")
include("qba3_1.jl")
include("qba3_2.jl")

function test_qba()
    @testset "Quantum Bridge Analytics I" verbose = true begin
        test_qba2()
        test_qba3_1()
        test_qba3_2()
    end
end
