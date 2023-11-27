include("constraints.jl")
include("error.jl")
include("setup.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_error()
        test_compiler_setup_callback()
    end

    return nothing
end
