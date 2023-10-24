function test_virtual()
    @testset "VirtualMapping" verbose = true begin
        @testset "Virtual Model" begin
            model = ToQUBO.Virtual.Model()

            @test MOI.is_empty(model)
        end
    end

    return nothing
end
