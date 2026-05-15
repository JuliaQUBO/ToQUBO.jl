include("constraints.jl")
include("error.jl")
include("analysis.jl")
include("variables.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_error()
        test_compiler_analysis()
        test_compiler_variables()
    end

    return nothing
end
