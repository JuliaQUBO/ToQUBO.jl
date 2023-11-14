include("variables.jl")

function test_encoding_methods()
    @testset "□ Encoding" verbose = true begin
        test_variable_encoding_methods()
    end

    return nothing
end
