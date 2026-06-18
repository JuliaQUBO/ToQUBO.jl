function _measure_constraint(model, ci, values)
    f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
    s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)

    return ToQUBO._constraint_violation(model.source_model, ci, f, s, values)
end

function _measure_function(model, f, s, values)
    ci = MOI.ConstraintIndex{typeof(f),typeof(s)}(0)

    return ToQUBO._constraint_violation(model.source_model, ci, f, s, values)
end

function test_feasibility_scalar_measurements()
    model = ToQUBO.Optimizer{Float64}()
    x_zero_one = MOI.add_variable(model)
    x_integer = MOI.add_variable(model)
    x_interval = MOI.add_variable(model)
    x_upper = MOI.add_variable(model)
    z_lower = MOI.add_variable(model)
    x = MOI.add_variable(model)
    y = MOI.add_variable(model)
    z = MOI.add_variable(model)

    values = Dict{VI,Any}(
        x_zero_one => 1.25,
        x_integer => 1.25,
        x_interval => 1.25,
        x_upper => 1.25,
        z_lower => 0.0,
        x => 1.25,
        y => 1.0,
        z => 0.0,
    )

    c_zero_one = MOI.add_constraint(model, x_zero_one, MOI.ZeroOne())
    c_integer = MOI.add_constraint(model, x_integer, MOI.Integer())
    c_interval_variable =
        MOI.add_constraint(model, x_interval, MOI.Interval{Float64}(0.0, 1.0))
    c_upper_variable = MOI.add_constraint(model, x_upper, MOI.LessThan{Float64}(1.0))
    c_lower_variable = MOI.add_constraint(model, z_lower, MOI.GreaterThan{Float64}(1.0))

    f_affine = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(1.0, x),
            MOI.ScalarAffineTerm(1.0, y),
        ],
        0.0,
    )
    c_affine_eq = MOI.add_constraint(model, f_affine, MOI.EqualTo{Float64}(3.0))
    c_affine_lt = MOI.add_constraint(model, f_affine, MOI.LessThan{Float64}(2.0))
    c_affine_gt = MOI.add_constraint(model, f_affine, MOI.GreaterThan{Float64}(3.0))
    affine_interval_set = MOI.Interval{Float64}(0.0, 2.0)

    f_quadratic = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(1.0, x, y)],
        [MOI.ScalarAffineTerm(1.0, z)],
        0.0,
    )
    c_quadratic_eq = MOI.add_constraint(model, f_quadratic, MOI.EqualTo{Float64}(1.0))
    c_quadratic_lt = MOI.add_constraint(model, f_quadratic, MOI.LessThan{Float64}(1.0))
    c_quadratic_gt = MOI.add_constraint(model, f_quadratic, MOI.GreaterThan{Float64}(2.0))
    quadratic_interval_set = MOI.Interval{Float64}(2.0, 3.0)

    @test _measure_constraint(model, c_zero_one, values).violation ≈ 0.25
    @test _measure_constraint(model, c_integer, values).violation ≈ 0.25
    @test _measure_constraint(model, c_interval_variable, values).violation ≈ 0.25
    @test _measure_constraint(model, c_upper_variable, values).raw_residual ≈ 0.25
    @test _measure_constraint(model, c_lower_variable, values).violation ≈ 1.0

    affine_eq = _measure_constraint(model, c_affine_eq, values)
    @test affine_eq.value ≈ 2.25
    @test affine_eq.raw_residual ≈ -0.75
    @test affine_eq.violation ≈ 0.75

    @test _measure_constraint(model, c_affine_lt, values).violation ≈ 0.25
    @test _measure_constraint(model, c_affine_gt, values).violation ≈ 0.75
    @test _measure_function(model, f_affine, affine_interval_set, values).violation ≈ 0.25

    @test _measure_constraint(model, c_quadratic_eq, values).violation ≈ 0.25
    @test _measure_constraint(model, c_quadratic_lt, values).violation ≈ 0.25
    @test _measure_constraint(model, c_quadratic_gt, values).violation ≈ 0.75
    @test _measure_function(model, f_quadratic, quadratic_interval_set, values).violation ≈ 0.75

    return nothing
end

function test_feasibility_vector_measurements()
    model = ToQUBO.Optimizer{Float64}()
    a = MOI.add_variable(model)
    x = MOI.add_variable(model)
    y = MOI.add_variable(model)

    values = Dict{VI,Any}(a => 1.0, x => 1.0, y => 1.0)
    inactive_values = Dict{VI,Any}(a => 0.0, x => 1.0, y => 1.0)

    c_sos = MOI.add_constraint(
        model,
        MOI.VectorOfVariables([x, y]),
        MOI.SOS1{Float64}([1.0, 2.0]),
    )

    f_indicator = MOI.VectorAffineFunction{Float64}(
        [
            MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, a)),
            MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x)),
            MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, y)),
        ],
        [0.0, 0.0],
    )
    c_indicator_eq = MOI.add_constraint(
        model,
        f_indicator,
        MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.EqualTo{Float64}(1.0)),
    )
    c_indicator_lt = MOI.add_constraint(
        model,
        f_indicator,
        MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.LessThan{Float64}(1.0)),
    )
    c_indicator_gt = MOI.add_constraint(
        model,
        f_indicator,
        MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.GreaterThan{Float64}(3.0)),
    )
    c_indicator_interval = MOI.add_constraint(
        model,
        f_indicator,
        MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.Interval{Float64}(3.0, 4.0)),
    )

    f_quadratic_indicator = MOI.VectorQuadraticFunction{Float64}(
        [MOI.VectorQuadraticTerm(2, MOI.ScalarQuadraticTerm(1.0, x, y))],
        [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, a))],
        [0.0, 0.0],
    )
    c_quadratic_indicator = MOI.add_constraint(
        model,
        f_quadratic_indicator,
        MOI.Indicator{MOI.ACTIVATE_ON_ZERO}(MOI.LessThan{Float64}(0.0)),
    )

    sos = _measure_constraint(model, c_sos, values)
    @test sos.value ≈ [1.0, 1.0]
    @test sos.violation ≈ 1.0

    @test _measure_constraint(model, c_indicator_eq, values).violation ≈ 1.0
    @test _measure_constraint(model, c_indicator_lt, values).violation ≈ 1.0
    @test _measure_constraint(model, c_indicator_gt, values).violation ≈ 1.0
    @test _measure_constraint(model, c_indicator_interval, values).violation ≈ 1.0
    @test _measure_constraint(model, c_indicator_lt, inactive_values).violation ≈ 0.0
    @test _measure_constraint(model, c_quadratic_indicator, inactive_values).violation ≈ 1.0

    return nothing
end

function test_feasibility_public_api()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)

    optimize!(model)

    result_violations = ToQUBO.violations(model; result = 1)

    @test !isempty(result_violations)
    @test !ToQUBO.is_feasible(model; result = 1)
    @test any(v -> v.violation ≈ 1.0, result_violations)

    report = ToQUBO.feasibility_report(model; result = 1:min(result_count(model), 4))

    @test report.result_count == min(result_count(model), 4)
    @test report.feasible_count < report.result_count
    @test report.max_violation >= 1.0
    @test !isempty(first(report.results).by_constraint_type)

    return nothing
end

function test_feasibility()
    @testset "→ Feasibility Analysis" verbose = true begin
        test_feasibility_scalar_measurements()
        test_feasibility_vector_measurements()
        test_feasibility_public_api()
    end

    return nothing
end
