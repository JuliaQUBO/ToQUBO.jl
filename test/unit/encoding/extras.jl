function test_encoding_extras()
    @testset "→ Extras" begin
        @testset "integer_interval" begin
            # Normal interval (a < b)
            @test ToQUBO.Encoding.integer_interval((-2.5, 2.5)) == (-2.0, 2.0)
            @test ToQUBO.Encoding.integer_interval((0.1, 3.9)) == (1.0, 3.0)
            @test ToQUBO.Encoding.integer_interval((-1.0, 1.0)) == (-1.0, 1.0)
            @test ToQUBO.Encoding.integer_interval((0.0, 5.0)) == (0.0, 5.0)

            # Reversed interval (a > b)
            @test ToQUBO.Encoding.integer_interval((2.5, -2.5)) == (-2.0, 2.0)
            @test ToQUBO.Encoding.integer_interval((3.9, 0.1)) == (1.0, 3.0)
        end
    end

    return nothing
end
