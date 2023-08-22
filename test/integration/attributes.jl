function test_attributes()
    @testset "Attributes" begin
        model = JuMP.Model(() -> ToQUBO.Optimizer(RandomSampler.Optimizer))

        # MOI Attributes
        @test MOI.get(model, MOI.NumberOfVariables()) == 0
        
        @test MOI.get(model, MOI.TimeLimitSec()) |> isnothing
        MOI.set(model, MOI.TimeLimitSec(), 1.0)
        @test MOI.get(model, MOI.TimeLimitSec()) == 1.0

        # ToQUBO Attributes
        @test MOI.get(model, TQA.Quadratize()) === false
        MOI.set(model, TQA.Quadratize(), true)
        @test MOI.get(model, TQA.Quadratize()) === true

        # Solver Attributes
        @test MOI.get(model, RandomSampler.RandomSeed()) |> isnothing
        MOI.set(model, RandomSampler.RandomSeed(), 13)
        @test MOI.get(model, RandomSampler.RandomSeed()) == 13

        @test MOI.get(model, RandomSampler.NumberOfReads()) == 1_000
        MOI.set(model, RandomSampler.NumberOfReads(), 13)
        @test MOI.get(model, RandomSampler.NumberOfReads()) == 13

        # Raw Attributes
        @test MOI.get(model, MOI.RawOptimizerAttribute("seed")) == 13
        MOI.set(model, MOI.RawOptimizerAttribute("seed"), 1_001)
        @test MOI.get(model, MOI.RawOptimizerAttribute("seed")) == 1_001

        @test MOI.get(model, MOI.RawOptimizerAttribute("num_reads")) == 13
        MOI.set(model, MOI.RawOptimizerAttribute("num_reads"), 1_001)
        @test MOI.get(model, MOI.RawOptimizerAttribute("num_reads")) == 1_001
    end

    return nothing
end