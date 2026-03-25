include("constraints.jl")
include("error.jl")
include("analysis.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_error()
        test_compiler_analysis()
    end

    return nothing
end
