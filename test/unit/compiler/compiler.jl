include("constraints.jl")
include("discretization.jl")
include("copy.jl")
include("quadratization.jl")
include("error.jl")
include("analysis.jl")
include("variables.jl")
include("objective.jl")
include("penalties.jl")
include("nonlinear.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
        test_compiler_integer_discretization()
        test_compiler_copy()
        test_compiler_quadratization()
        test_compiler_error()
        test_compiler_analysis()
        test_compiler_variables()
        test_compiler_objective()
        test_compiler_penalties()
        test_compiler_nonlinear()
    end

    return nothing
end
