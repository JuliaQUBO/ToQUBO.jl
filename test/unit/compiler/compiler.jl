include("constraints.jl")
include("error.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_error()
    end

    return nothing
end
