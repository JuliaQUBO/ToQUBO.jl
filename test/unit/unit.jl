include("lib/lib.jl")
include("compiler/compiler.jl")

function test_unit()
    @testset "Unit Tests" verbose = true begin
        test_lib()
        test_compiler()
    end

    return nothing
end
