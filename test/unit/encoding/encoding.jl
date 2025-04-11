include("variables.jl")
include("constraints.jl")

function test_encoding_methods()
    @testset "□ Encoding" verbose = true begin
        test_variable_encoding_methods()
        test_constraint_encoding_methods()
    end

    return nothing
end
