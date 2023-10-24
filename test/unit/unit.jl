include("compiler/compiler.jl")
include("encoding/encoding.jl")

function test_unit()
    @testset "⊚ ⊚ Unit Tests" verbose = true begin
        test_encoding_methods()
        test_compiler()
    end

    return nothing
end
