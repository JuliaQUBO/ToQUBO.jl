include("compiler/compiler.jl")
include("docs.jl")
include("encoding/encoding.jl")
include("virtual/virtual.jl")
include("model/model.jl")
include("wrapper/wrapper.jl")
include("attributes/attributes.jl")

function test_unit()
    @testset "⊚ Unit Tests" verbose = true begin
        test_encoding_methods()
        test_compiler()
        test_docs()
        test_virtual()
        test_model()
        test_wrapper()
        test_attributes()
    end

    return nothing
end
