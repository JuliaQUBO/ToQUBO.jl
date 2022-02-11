@testset "Digital Annealing" begin

    annealer = Digital.Optimizer{Float64}(
        num_reads=500
    )

    @test (MOI.get(annealer, Digital.NumberOfReads()) == 500)

    MOI.set(annealer, Anneal.NumberOfReads(), 1_000)

    @test (MOI.get(annealer, Digital.NumberOfReads()) == 1_000)

    @test (MOI.is_empty(annealer) == true)

    model = MOIU.Model{Float64}()

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    x₁ = MOI.add_variable(model)
    x₂ = MOI.add_variable(model)

    @test (Anneal.isqubo(model) == false)

    @test_throws Anneal.QUBOError MOI.copy_to(annealer, model)

    MOI.add_constraint(model, x₁, MOI.ZeroOne())
    MOI.add_constraint(model, x₂, MOI.ZeroOne())

    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
        MOI.ScalarQuadraticFunction{Float64}([
            MOI.ScalarQuadraticTerm{Float64}(1.0, x₁, x₂),
        ], [
            MOI.ScalarAffineTerm{Float64}(-1.0, x₁),
            MOI.ScalarAffineTerm{Float64}(-2.0, x₂)
        ], 3.0)
    )

    @test (Anneal.isqubo(model) == true)

    MOI.copy_to(annealer, model)

    @test (MOI.is_empty(annealer) == false)

    @test annealer.x == Dict{MOI.VariableIndex, Int}(x₁ => 1, x₂ => 2)
    @test annealer.Q == Dict{Tuple{Int, Int}, Float64}(
        (1, 1) => -1.0,
        (1, 2) => 1.0,
        (2, 2) => -2.0,
    )
    @test annealer.c == 3.0

    MOI.empty!(annealer)

    @test (MOI.is_empty(annealer) == true)
end