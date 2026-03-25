include("variables.jl")
include("constraints.jl")
include("extras.jl")

function test_encoding_methods()
    @testset "□ Encoding" verbose = true begin
        test_variable_encoding_methods()
        test_constraint_encoding_methods()
        test_encoding_extras()
    end

    return nothing
end
