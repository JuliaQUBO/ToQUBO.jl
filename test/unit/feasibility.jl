module FeasibilityBackendProbe

struct Model end

function unsafe_backend(::Model)
    error("backend failed")
end

end

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

# Under-penalized knapsack-style model: with the deliberately weak penalty
# hint, the best-energy sample (result 1) sets both variables and violates
# the capacity constraint.
function _under_penalized_model()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)

    return model, x
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
    all_report = ToQUBO.feasibility_report(model)

    @test report.result_count == min(result_count(model), 4)
    @test report.feasible_count < report.result_count
    @test report.max_violation >= 1.0
    @test !isempty(first(report.results).by_constraint_type)
    @test all_report.result_count == result_count(model)
    @test all_report.feasible_count <= all_report.result_count
    @test first(values(first(report.results).by_constraint_type)) isa ToQUBO.ConstraintTypeSummary

    return nothing
end

function test_feasibility_error_paths()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x, Bin)
    @objective(model, Min, x)

    @test_throws ErrorException ToQUBO.feasibility_report(model)

    optimize!(model)

    @test_throws ErrorException ToQUBO.violations(model; result = 0)
    @test_throws ErrorException ToQUBO.violations(model; result = result_count(model) + 1)
    @test_throws ErrorException ToQUBO.violations(nothing)

    try
        ToQUBO.violations(FeasibilityBackendProbe.Model())
        @test false
    catch err
        @test occursin("backend failed", sprint(showerror, err))
    end

    return nothing
end

function test_feasibility_primal_status()
    model, _ = _under_penalized_model()

    optimize!(model)

    # Result 1 violates the capacity constraint, so the default feasibility
    # check downgrades the sampler's FEASIBLE_POINT.
    @test !ToQUBO.is_feasible(model; result = 1)
    @test primal_status(model) === MOI.INFEASIBLE_POINT

    n = result_count(model)
    feasible_index = findfirst(i -> ToQUBO.is_feasible(model; result = i), 1:n)

    @test feasible_index !== nothing
    @test primal_status(model; result = feasible_index) === MOI.FEASIBLE_POINT

    # Dual status is untouched by the feasibility check.
    @test dual_status(model) === MOI.NO_SOLUTION

    # Disabling the check restores the sampler's raw status. Setting a JuMP
    # model attribute marks the model dirty, so re-optimize before querying;
    # ExactSampler keeps the results deterministic.
    set_attribute(model, Attributes.PrimalFeasibilityCheck(), false)
    optimize!(model)
    @test primal_status(model) === MOI.FEASIBLE_POINT

    set_attribute(model, Attributes.PrimalFeasibilityCheck(), true)
    optimize!(model)
    @test primal_status(model) === MOI.INFEASIBLE_POINT

    return nothing
end

function test_feasibility_source_objective_value()
    model, x = _under_penalized_model()

    optimize!(model)

    n = result_count(model)

    for i in (1, n)
        expected = 3 * value(x[1]; result = i) + 3 * value(x[2]; result = i)

        @test ToQUBO.source_objective_value(model; result = i) ≈ expected
    end

    @test ToQUBO.source_objective_value(model) ≈
          ToQUBO.source_objective_value(model; result = 1)

    # Result 1 is infeasible, so the target energy carries an active penalty
    # term and differs from the penalty-free source objective value.
    @test ToQUBO.source_objective_value(model) ≈ 6.0
    @test !isapprox(objective_value(model), ToQUBO.source_objective_value(model))

    @test_throws MOI.ResultIndexBoundsError ToQUBO.source_objective_value(model; result = 0)
    @test_throws MOI.ResultIndexBoundsError ToQUBO.source_objective_value(
        model;
        result = n + 1,
    )

    return nothing
end

function test_feasibility_auto_report()
    model, _ = _under_penalized_model()

    @test get_attribute(model, Attributes.AutoFeasibilityReport()) === false

    # Disabled by default: the solve must not warn, and must not auto-compute
    # or cache a report.
    @test_logs min_level = Logging.Warn optimize!(model)

    @test !haskey(JuMP.unsafe_backend(model).moi_settings, :feasibility_report)

    # Default report requests are cached per solve (lazily, on first call).
    report = ToQUBO.feasibility_report(model)

    @test ToQUBO.feasibility_report(model) === report
    @test ToQUBO.feasibility_report(model; atol = 1e-3) !== report

    set_attribute(model, Attributes.AutoFeasibilityReport(), true)

    @test_logs (:warn, r"violate source constraints") match_mode = :any optimize!(model)

    # The auto-run report is cached, and re-optimizing invalidates it.
    auto_report = ToQUBO.feasibility_report(model)

    @test auto_report.feasible_count < auto_report.result_count

    optimize!(model)

    @test ToQUBO.feasibility_report(model) !== auto_report

    # Warnings() silences the infeasibility warning without disabling the report.
    set_attribute(model, Attributes.Warnings(), false)

    @test_logs min_level = Logging.Warn optimize!(model)
    @test ToQUBO.feasibility_report(model).feasible_count <
          ToQUBO.feasibility_report(model).result_count

    return nothing
end

function test_feasibility_soft_constraints()
    # Hard + soft constraint model: hard constraint x[1] + x[2] <= 1 is enforced
    # by default exact penalty; soft preference x[1] + x[2] >= 2 is given a weak
    # penalty hint so result 1 satisfies the hard constraint (x[1] + x[2] == 1)
    # while violating the soft preference by 1.0.
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 2x[2])
    c_hard = @constraint(model, x[1] + x[2] <= 1)
    c_soft = @constraint(model, x[1] + x[2] >= 2)

    @test get_attribute(c_hard, Attributes.SoftConstraint()) === false
    @test get_attribute(c_soft, Attributes.SoftConstraint()) === false

    set_attribute(c_soft, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    set_attribute(c_soft, Attributes.SoftConstraint(), true)
    set_attribute(model, Attributes.AutoFeasibilityReport(), true)

    @test get_attribute(c_soft, Attributes.SoftConstraint()) === true

    # Because only the soft constraint is violated in the hard-feasible results,
    # result 1 is feasible and primal_status is FEASIBLE_POINT.
    optimize!(model)

    @test ToQUBO.is_feasible(model; result = 1)
    @test primal_status(model; result = 1) === MOI.FEASIBLE_POINT

    all_violated = ToQUBO.violations(model; result = 1)
    hard_violated = ToQUBO.violations(model; result = 1, include_soft = false)

    @test isempty(hard_violated)
    @test length(all_violated) == 1
    soft_v = only(all_violated)
    @test soft_v.soft === true
    @test soft_v.raw_residual ≈ 1.0
    @test soft_v.violation ≈ 1.0
    @test soft_v.value ≈ 1.0

    report = ToQUBO.feasibility_report(model)
    r1 = first(report.results)

    @test r1.feasible === true
    @test r1.violation_count == 0
    @test r1.max_violation == 0.0
    @test r1.total_violation == 0.0
    @test r1.soft_violation_count == 1
    @test r1.soft_max_violation ≈ 1.0
    @test r1.soft_total_violation ≈ 1.0
    @test haskey(r1.by_constraint_type, "$(MOI.ScalarAffineFunction{Float64}) in $(MOI.LessThan{Float64})")
    @test haskey(r1.soft_by_constraint_type, "$(MOI.ScalarAffineFunction{Float64}) in $(MOI.GreaterThan{Float64})")
    @test r1.soft_by_constraint_type["$(MOI.ScalarAffineFunction{Float64}) in $(MOI.GreaterThan{Float64})"].violation_count == 1

    @test report.soft_violation_count >= 1
    @test report.soft_max_violation >= 1.0
    @test report.soft_total_violation >= 1.0

    # When every constraint in an under-penalized model is marked soft, no hard
    # constraint is violated anywhere, so AutoFeasibilityReport emits no warning
    # and every result is hard-feasible.
    soft_only_model, _ = _under_penalized_model()
    for (F, S) in list_of_constraint_types(soft_only_model)
        F == VariableRef && continue
        for cref in all_constraints(soft_only_model, F, S)
            set_attribute(cref, Attributes.SoftConstraint(), true)
        end
    end
    set_attribute(soft_only_model, Attributes.AutoFeasibilityReport(), true)

    @test_logs min_level = Logging.Warn optimize!(soft_only_model)

    soft_only_report = ToQUBO.feasibility_report(soft_only_model)
    @test soft_only_report.feasible_count == soft_only_report.result_count
    @test soft_only_report.max_violation == 0.0
    @test soft_only_report.total_violation == 0.0
    @test soft_only_report.soft_violation_count == 2
    @test soft_only_report.soft_max_violation ≈ 1.0
    @test soft_only_report.soft_total_violation ≈ 2.0
    @test ToQUBO.is_feasible(soft_only_model; result = 1)
    @test primal_status(soft_only_model; result = 1) === MOI.FEASIBLE_POINT

    # Bridged interval constraint marked soft propagates to both split bounds.
    bridged_model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
    @variable(bridged_model, y[1:2], Bin)
    @objective(bridged_model, Max, 5y[1] + 5y[2])
    c_interval = @constraint(bridged_model, 0.0 <= y[1] + y[2] <= 1.0)
    set_attribute(c_interval, Attributes.SoftConstraint(), true)
    @test get_attribute(c_interval, Attributes.SoftConstraint()) === true
    set_attribute(bridged_model, Attributes.PenaltyScale(), 0.01)

    optimize!(bridged_model)
    @test get_attribute(c_interval, Attributes.SoftConstraint()) === true
    @test ToQUBO.is_feasible(bridged_model; result = 1)
    @test isempty(ToQUBO.violations(bridged_model; result = 1, include_soft = false))
    @test !isempty(ToQUBO.violations(bridged_model; result = 1, include_soft = true))
    @test all(v -> v.soft, ToQUBO.violations(bridged_model; result = 1))

    # Emptying a JuMP model and rebuilding with a hard constraint at the same
    # constraint index must not leak the previous soft flag into the backend.
    reuse_model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
    @variable(reuse_model, u[1:2], Bin)
    @objective(reuse_model, Max, 3u[1] + 3u[2])
    c_reuse_soft = @constraint(reuse_model, u[1] + u[2] <= 1)
    set_attribute(c_reuse_soft, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    set_attribute(c_reuse_soft, Attributes.SoftConstraint(), true)
    optimize!(reuse_model)
    @test ToQUBO.is_feasible(reuse_model; result = 1)
    @test primal_status(reuse_model; result = 1) === MOI.FEASIBLE_POINT

    empty!(reuse_model)
    @variable(reuse_model, v[1:2], Bin)
    @objective(reuse_model, Max, 3v[1] + 3v[2])
    c_reuse_hard = @constraint(reuse_model, v[1] + v[2] <= 1)
    set_attribute(c_reuse_hard, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    @test get_attribute(c_reuse_hard, Attributes.SoftConstraint()) === false
    optimize!(reuse_model)
    @test get_attribute(c_reuse_hard, Attributes.SoftConstraint()) === false
    @test !ToQUBO.is_feasible(reuse_model; result = 1)
    @test primal_status(reuse_model; result = 1) === MOI.INFEASIBLE_POINT
    @test only(ToQUBO.violations(reuse_model; result = 1)).soft === false

    return nothing
end

function test_feasibility()
    @testset "→ Feasibility Analysis" verbose = true begin
        test_feasibility_scalar_measurements()
        test_feasibility_vector_measurements()
        test_feasibility_public_api()
        test_feasibility_error_paths()
        test_feasibility_primal_status()
        test_feasibility_source_objective_value()
        test_feasibility_auto_report()
        test_feasibility_soft_constraints()
    end

    return nothing
end
