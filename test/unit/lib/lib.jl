include("version.jl")
include("pbo.jl")
include("virtual.jl")

function test_lib()
    @testset "Library" verbose = true begin
        test_version()
        test_pbo()
        test_virtual()
    end
end