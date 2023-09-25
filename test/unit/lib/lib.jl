include("virtual.jl")

function test_lib()
    @testset "Library" verbose = true begin
        test_virtual()
    end

    return nothing
end
