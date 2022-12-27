include("moi.jl")
include("jump.jl")

function test_interface()
    @testset "Interface" verbose = true begin
        test_moi()
        test_jump()
    end
end