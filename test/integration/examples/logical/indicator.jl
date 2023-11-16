function test_indicator()
    test_indicator_linear()
    test_indicator_quadratic()
end

"""
"""
function test_indicator_linear()
    @testset "→ Indicator Constraint" begin
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x[1:2] <= 2, Int)
        @variable(model, Y[1:2], Bin)

        @objective(model, Min, sum(x) - 2 * sum(Y))

        @constraint(model, ci[i = 1:2], Y[i] => {x[i] ≥ 1})

        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        @show n
        println()
        display(L)
        println()
        display(Q)
        println()
    end

    return nothing
end

"""
"""
function test_indicator_quadratic()
    @testset "→ Indicator Constraint" begin
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x[1:2] <= 5, Int)
        @variable(model, Y[1:2], Bin)

        @objective(model, Min, sum(x) - 2 * sum(Y))

        @constraint(model, c1, Y[1] => {x[1]^2 + x[2]^2 ≤ 1})
        @constraint(model, c2, Y[2] => {(x[1] - 2)^2 + (x[2] - 2)^2 ≤ 1})

        @constraint(model, c3, Y[1] + Y[2] == 1)

        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        @show n
        println()
        display(L)
        println()
        display(Q)
        println()

        @show result_count(model)
    end

    return nothing
end

