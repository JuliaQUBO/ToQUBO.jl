@testset "QUBO Model" begin

    model = MOIU.Model{Float64}()

    @test (Anneal.isqubo(model) === false)

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

    @test (Anneal.isqubo(model) === true)

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    @test (Anneal.isqubo(model) === true)

    x₁ = MOI.add_variable(model)

    @test (Anneal.isqubo(model) === false)

    MOI.add_constraint(model, x₁, MOI.ZeroOne())

    @test (Anneal.isqubo(model) === true)

    x₂ = MOI.add_variable(model)

    @test (Anneal.isqubo(model) === false)

    MOI.add_constraint(model, x₂, MOI.ZeroOne())

    @test (Anneal.isqubo(model) === true)


    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}([
            MOI.ScalarAffineTerm{Float64}(-1.0, x₁),
            MOI.ScalarAffineTerm{Float64}(-2.0, x₂)
        ], 3.0)
    )

    @test (Anneal.isqubo(model) === true)

    @test (Anneal.qubo_normal_form(model) == (
            Dict{MOI.VariableIndex, Int}(x₁ => 1, x₂ => 2),
            Dict{Tuple{Int, Int}, Float64}(
                (1, 1) => -1.0,
                (2, 2) => -2.0
            ),
            3.0,
        )
    )

    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
        MOI.ScalarQuadraticFunction{Float64}([
            MOI.ScalarQuadraticTerm{Float64}(1.0, x₁, x₂),
        ], [
            MOI.ScalarAffineTerm{Float64}(-1.0, x₁),
            MOI.ScalarAffineTerm{Float64}(-2.0, x₂)
        ], 3.0)
    )

    @test (Anneal.isqubo(model) === true)

    @test (Anneal.qubo_normal_form(model) == (
            Dict{MOI.VariableIndex, Int}(x₁ => 1, x₂ => 2),
            Dict{Tuple{Int, Int}, Float64}(
                (1, 1) => -1.0,
                (1, 2) => 1.0,
                (2, 2) => -2.0
            ),
            3.0,
        )
    )

end