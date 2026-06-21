include("constraints.jl")
include("copy.jl")
include("error.jl")
include("analysis.jl")
include("variables.jl")
include("penalties.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_copy()
        test_compiler_error()
        test_compiler_analysis()
        test_compiler_variables()
        test_compiler_penalties()
    end

    return nothing
end
