function test_indicator()
    test_indicator_linear()
    test_indicator_quadratic()
end

"""

"""
function test_indicator_linear()
    @testset "→ Indicator Constraint" begin
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, -2 ≤ x[1:2] ≤ 2)
        @variable(model, Y[1:2], Bin)

        @objective(model, Min, sum(x))

        @constraint(model, sum(Y) == 1)
        
        @constraint(model, sq1[i = 1:2], Y[1] => {-2 ≤ x[i] ≤ -1})
        @constraint(model, sq2[i = 1:2], Y[2] => {1 ≤ x[i] ≤ 2})

        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)
    end

    return nothing
end

"""
"""
function test_indicator_quadratic()
    @testset "→ Indicator Constraint" begin
        model = Model(() -> ToQUBO.Optimizer(RandomSampler.Optimizer))

        @variable(model, 0 <= x[1:2] <= 1)
        @variable(model, Y[1:2], Bin)

        @objective(model, Min, sum(x))

        @constraint(model, c1, Y[1] => {x[1]^2 + x[2]^2 ≤ 1})
        @constraint(model, c2, Y[2] => {(x[1] - 2)^2 + (x[2] - 2)^2 ≤ 1})

        @constraint(model, c3, Y[1] + Y[2] == 1)

        set_attribute.(x, ToQUBO.Attributes.VariableEncodingMethod(), ToQUBO.Encoding.Binary())
        set_attribute.(x, ToQUBO.Attributes.VariableEncodingBits(), 3)
        set_attribute(model, RandomSampler.NumberOfReads(), 2_000)

        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)
    end

    return nothing
end

