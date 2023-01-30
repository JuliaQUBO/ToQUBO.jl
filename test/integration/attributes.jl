function test_attributes()
    @testset "Attributes" begin
        model = JuMP.Model(() -> ToQUBO.Optimizer(RandomSampler.Optimizer))

        # MOI Attributes
        @test MOI.get(model, MOI.NumberOfVariables()) == 0
        
        @test MOI.get(model, MOI.TimeLimitSec()) |> isnothing
        MOI.set(model, MOI.TimeLimitSec(), 1.0)
        @test MOI.get(model, MOI.TimeLimitSec()) == 1.0

        # ToQUBO Attributes
        @test MOI.get(model, ToQUBO.QUADRATIZE()) === false
        MOI.set(model, ToQUBO.QUADRATIZE(), true)
        @test MOI.get(model, ToQUBO.QUADRATIZE()) === true

        # Solver Attributes
        @test MOI.get(model, RandomSampler.RandomSeed()) |> isnothing
        MOI.set(model, RandomSampler.RandomSeed(), 13)
        @test MOI.get(model, RandomSampler.RandomSeed()) == 13

        @test MOI.get(model, RandomSampler.NumberOfReads()) == 1_000
        MOI.set(model, RandomSampler.NumberOfReads(), 13)
        @test MOI.get(model, RandomSampler.NumberOfReads()) == 13
    end
end