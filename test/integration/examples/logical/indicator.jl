using DisjunctiveProgramming

function test_indicator()
    test_indicator_linear()
    test_indicator_quadratic()
    test_indicator_disjunctive_programming()
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

function test_indicator_disjunctive_programming()
    @testset "→ DisjunctiveProgramming Indicator Reformulation" begin
        test_indicator_disjunctive_programming_linear()
        test_indicator_disjunctive_programming_quadratic()
        test_indicator_disjunctive_programming_manual_example()
    end

    return nothing
end

function test_indicator_disjunctive_programming_linear()
    @testset "Linear GDP disjunction" begin
        model = GDPModel(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x <= 3)
        @variable(model, Y[1:2], Logical)

        @constraint(model, x <= 0, Disjunct(Y[1]))
        @constraint(model, x >= 2, Disjunct(Y[2]))
        @disjunction(model, Y)
        @objective(model, Min, x)

        set_attribute(x, ToQUBO.Attributes.VariableEncodingMethod(), ToQUBO.Encoding.Unary())
        set_attribute(x, ToQUBO.Attributes.VariableEncodingBits(), 3)

        optimize!(model; gdp_method = Indicator())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        @test n > 0
        @test size(Q) == (n, n)
        @test length(L) == n
        @test termination_status(model) === MOI.LOCALLY_SOLVED
        @test get_attribute(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED

        x̂ = value(x)

        @test x̂ ≈ 0.0
        @test x̂ <= 0.0 || x̂ >= 2.0
    end

    return nothing
end

function test_indicator_disjunctive_programming_quadratic()
    @testset "Quadratic GDP disjunction" begin
        model = GDPModel(() -> ToQUBO.Optimizer())

        @variable(model, -1 <= x <= 2)
        @variable(model, Y[1:2], Logical)

        @constraint(model, (x + 1)^2 <= 0, Disjunct(Y[1]))
        @constraint(model, (x - 1)^2 <= 0, Disjunct(Y[2]))
        @disjunction(model, Y)
        @objective(model, Min, x)

        set_attribute(x, ToQUBO.Attributes.VariableEncodingMethod(), ToQUBO.Encoding.Unary())
        set_attribute(x, ToQUBO.Attributes.VariableEncodingBits(), 3)

        optimize!(model; gdp_method = Indicator())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        @test n > 0
        @test size(Q) == (n, n)
        @test length(L) == n
        @test termination_status(model) === MOI.LOCALLY_SOLVED
        @test get_attribute(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED
        @test primal_status(model) === MOI.NO_SOLUTION
    end

    return nothing
end

function test_indicator_disjunctive_programming_manual_example()
    @testset "Manual GDP example" begin
        model = GDPModel(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, -1 <= x[1:2] <= 1)
        @variable(model, Y[1:2], Logical)

        @constraint(model, [i = 1:2], x[i] == -1, Disjunct(Y[1]))
        @constraint(model, [i = 1:2], x[i] == 1, Disjunct(Y[2]))
        @disjunction(model, Y)

        @objective(model, Min, x[1] + x[2])

        set_attribute.(x, ToQUBO.Attributes.VariableEncodingMethod(), ToQUBO.Encoding.Unary())
        set_attribute.(x, ToQUBO.Attributes.VariableEncodingBits(), 1)

        optimize!(model; gdp_method = Indicator())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        @test n > 0
        @test n <= 8
        @test size(Q) == (n, n)
        @test length(L) == n
        @test result_count(model) > 0
        @test termination_status(model) === MOI.LOCALLY_SOLVED
        @test primal_status(model) === MOI.FEASIBLE_POINT
        @test get_attribute(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED
        @test value.(x) ≈ [-1.0, -1.0]
    end

    return nothing
end
