include("corner_1.jl")

function test_corner()
    @testset "Corner Cases" begin
        test_corner_1()
    end

    return nothing
end
