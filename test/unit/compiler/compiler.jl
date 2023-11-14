include("constraints.jl")

function test_compiler()
    @testset "□ Compiler" verbose = true begin
        test_compiler_constraints()
    end

    return nothing
end
