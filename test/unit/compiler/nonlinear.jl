function test_compiler_nonlinear()
    @testset "→ ScalarNonlinearFunction Polynomials (Issue #224)" verbose = true begin
        @testset "Cubic and quartic JuMP polynomial objectives" begin
            # 1. Cubic minimization: min 4*x1*x2*x3 - x1 - x2 - x3
            # Minimum is -2.0 achieved when any two of (x1, x2, x3) are 1 and the third is 0.
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:3], Bin)
                @objective(model, Min, 4 * x[1] * x[2] * x[3] - x[1] - x[2] - x[3])
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test termination_status(model) == _exact_sampler_termination_status()
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.f) == 3
                @test PBO.degree(backend.H) <= 2
                @test length(ToQUBO.auxiliary_variables(backend)) >= 1

                sol = [round(Int, value(x[i])) for i = 1:3]
                @test sum(sol) == 2
                @test prod(sol) == 0
                @test ToQUBO.source_objective_value(model) ≈ -2.0
                @test objective_value(model) ≈ -2.0
            end

            # 2. Quartic maximization: max -5*x1*x2*x3*x4 + x1 + x2 + x3 + x4 + 1.5
            # Maximum is 4.5 achieved when any three of (x1, x2, x3, x4) are 1 and one is 0.
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:4], Bin)
                @objective(
                    model,
                    Max,
                    -5 * x[1] * x[2] * x[3] * x[4] + x[1] + x[2] + x[3] + x[4] + 1.5,
                )
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test termination_status(model) == _exact_sampler_termination_status()
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.f) == 4
                @test PBO.degree(backend.H) <= 2

                sol = [round(Int, value(x[i])) for i = 1:4]
                @test sum(sol) == 3
                @test prod(sol) == 0
                @test ToQUBO.source_objective_value(model) ≈ 4.5
                @test objective_value(model) ≈ 4.5
            end

            # 3. Higher-degree polynomial over encoded integer variable: min (z - 2)^2 + (z - 2)^4
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, 0 <= z <= 7, Int)
                @objective(model, Min, (z - 2)^2 + (z - 2)^4)
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.f) == 3
                @test PBO.degree(backend.H) <= 2
                @test round(Int, value(z)) == 2
                @test ToQUBO.source_objective_value(model) ≈ 0.0
                @test objective_value(model) ≈ 0.0
            end

            # 4. Degree-2 ScalarNonlinearFunction does not auto-enable Quadratize and supports exact certification
            let model = ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer)
                x = [MOI.add_variable(model) for _ = 1:2]
                for xi in x
                    MOI.add_constraint(model, xi, MOI.ZeroOne())
                end

                # f(x) = (2*x1 - x2)^2 / 2 + 1 = 2*x1 - 2*x1*x2 + 0.5*x2 + 1
                diff = MOI.ScalarNonlinearFunction(
                    :-,
                    Any[MOI.ScalarNonlinearFunction(:*, Any[2.0, x[1]]), x[2]],
                )
                sq = MOI.ScalarNonlinearFunction(:^, Any[diff, 2])
                f_snf = MOI.ScalarNonlinearFunction(
                    :+,
                    Any[MOI.ScalarNonlinearFunction(:/, Any[sq, 2.0]), 1.0],
                )
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}(), f_snf)

                c_snf = MOI.add_constraint(
                    model,
                    MOI.ScalarNonlinearFunction(:+, Any[x[1], x[2]]),
                    MOI.EqualTo(1.0),
                )
                MOI.set(model, Attributes.PenaltyIncumbent(), Dict(x[1] => 0.0, x[2] => 1.0))

                MOI.optimize!(model)

                @test MOI.get(model, Attributes.Quadratize()) === false
                @test PBO.degree(model.f) <= 2
                @test PBO.degree(model.H) <= 2
                meta = MOI.get(model, Attributes.PenaltyPolicyMetadata())
                @test meta["incumbent"]["used"] === true
                @test meta["sufficient_bound"]["certified"] === true

                @test round(Int, MOI.get(model, MOI.VariablePrimal(1), x[1])) == 0
                @test round(Int, MOI.get(model, MOI.VariablePrimal(1), x[2])) == 1
                @test ToQUBO.source_objective_value(model) ≈ 1.5
            end

            # 5. Direct QUBODrivers.ScalarPolynomialFunction parsing
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()
                x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
                ToQUBO.Compiler.variables!(model, arch)
                y = [only(ToQUBO.Virtual.target(model.source[xi])) for xi in x]

                snf = MOI.ScalarNonlinearFunction(
                    :+,
                    Any[MOI.ScalarNonlinearFunction(:*, Any[3.0, x[1], x[2], x[3]]), -2.0],
                )
                spf = QUBODrivers.polynomial_function(snf, Float64)

                g = PBO.PBF{VI,Float64}()
                ToQUBO.Compiler.parse!(model, g, spf, arch)
                @test g == PBO.PBF{VI,Float64}(-2.0, [y[1], y[2], y[3]] => 3.0)

                ToQUBO.Compiler.parse!(model, g, spf, MOI.EqualTo(1.0), arch)
                @test g == PBO.PBF{VI,Float64}(-3.0, [y[1], y[2], y[3]] => 3.0)

                ToQUBO.Compiler.parse!(model, g, spf, MOI.LessThan(2.0), arch)
                @test g == PBO.PBF{VI,Float64}(-4.0, [y[1], y[2], y[3]] => 3.0)

                ToQUBO.Compiler.parse!(model, g, spf, MOI.GreaterThan(-1.0), arch)
                @test g == PBO.PBF{VI,Float64}(-1.0, [y[1], y[2], y[3]] => 3.0)

                fs = PBO.PBF{VI,Float64}[]
                ToQUBO.Compiler.parse!(model, fs, spf, arch)
                @test length(fs) == 1
                @test fs[1] == PBO.PBF{VI,Float64}(-2.0, [y[1], y[2], y[3]] => 3.0)
            end

            # 6. Mixed affine/quadratic leaf equivalence (including diagonal MOI quadratic convention)
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()
                x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
                ToQUBO.Compiler.variables!(model, arch)
                y = [only(ToQUBO.Virtual.target(model.source[xi])) for xi in x]

                # saf = 2*x3 - x1 + 0.5
                saf = MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(2.0, x[3]), MOI.ScalarAffineTerm(-1.0, x[1])],
                    0.5,
                )
                # sqf = 1.5*x2^2 (MOI coeff 3.0) - 2.0*x2*x3 + x1 - 0.25
                sqf = MOI.ScalarQuadraticFunction(
                    [
                        MOI.ScalarQuadraticTerm(3.0, x[2], x[2]),
                        MOI.ScalarQuadraticTerm(-2.0, x[2], x[3]),
                    ],
                    [MOI.ScalarAffineTerm(1.0, x[1])],
                    -0.25,
                )
                snf = MOI.ScalarNonlinearFunction(
                    :-,
                    Any[
                        MOI.ScalarNonlinearFunction(:*, Any[saf, sqf]),
                        MOI.ScalarNonlinearFunction(:^, Any[saf, 2]),
                    ],
                )

                g = PBO.PBF{VI,Float64}()
                ToQUBO.Compiler.parse!(model, g, snf, arch)
                g_q = ToQUBO.Compiler._parse_function_exact_rational(model, snf)
                @test !isnothing(g_q)

                for b1 in (0, 1), b2 in (0, 1), b3 in (0, 1)
                    saf_val = 2.0 * b3 - 1.0 * b1 + 0.5
                    sqf_val = 1.5 * b2^2 - 2.0 * b2 * b3 + 1.0 * b1 - 0.25
                    expected = saf_val * sqf_val - saf_val^2

                    y_assign = Dict(y[1] => b1, y[2] => b2, y[3] => b3)
                    g_val = sum(
                        c * prod(y_assign[v] for v in ω; init = 1) for (ω, c) in g;
                        init = 0.0,
                    )
                    g_q_val = sum(
                        c * prod(y_assign[v] for v in ω; init = 1) for (ω, c) in g_q;
                        init = zero(Rational{BigInt}),
                    )
                    @test g_val ≈ expected
                    @test Float64(g_q_val) ≈ expected

                    x_rat = Dict(
                        x[1] => Rational{BigInt}(b1),
                        x[2] => Rational{BigInt}(b2),
                        x[3] => Rational{BigInt}(b3),
                    )
                    eval_q = ToQUBO.Compiler._eval_source_function_rational(snf, x_rat)
                    @test !isnothing(eval_q)
                    @test Float64(eval_q) ≈ expected
                end
            end
        end

        @testset "Degree-3+ polynomial equality, inequality, and interval constraints" begin
            # 1. Cubic equality constraint: x1*x2*x3 == 1
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:3], Bin)
                @objective(model, Min, x[1] + 2 * x[2] + 3 * x[3])
                @constraint(model, x[1] * x[2] * x[3] == 1)
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.H) <= 2
                @test [round(Int, value(x[i])) for i = 1:3] == [1, 1, 1]
                @test ToQUBO.is_feasible(model)
                @test isempty(ToQUBO.violations(model))
                @test ToQUBO.feasibility_report(model).feasible_count >= 1
                @test ToQUBO.source_objective_value(model) ≈ 6.0
            end

            # 2. Cubic LessThan constraint: x1*x2*x3 + x1 <= 1
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:3], Bin)
                @objective(model, Max, x[1] + x[2] + x[3])
                @constraint(model, x[1] * x[2] * x[3] + x[1] <= 1)
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.H) <= 2
                sol = [round(Int, value(x[i])) for i = 1:3]
                @test sol[1] * sol[2] * sol[3] + sol[1] <= 1
                @test sum(sol) == 2
                @test ToQUBO.is_feasible(model)
                @test isempty(ToQUBO.violations(model))
                @test ToQUBO.source_objective_value(model) ≈ 2.0
            end

            # 3. Cubic GreaterThan constraint: x1*x2*x3 + x4 >= 2
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:4], Bin)
                @objective(model, Min, x[1] + x[2] + x[3] + 2 * x[4])
                @constraint(model, x[1] * x[2] * x[3] + x[4] >= 2)
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.H) <= 2
                @test [round(Int, value(x[i])) for i = 1:4] == [1, 1, 1, 1]
                @test ToQUBO.is_feasible(model)
                @test isempty(ToQUBO.violations(model))
                @test ToQUBO.source_objective_value(model) ≈ 5.0
            end

            # 4. Cubic Interval constraint via JuMP and direct MOI.Interval compiler path
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:3], Bin)
                @objective(model, Max, 3 * x[1] + 2 * x[2] + x[3])
                @constraint(model, 1 <= x[1] * x[2] * x[3] + x[1] + x[2] <= 2)
                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                @test MOI.get(backend, Attributes.Quadratize()) === true
                @test PBO.degree(backend.H) <= 2
                sol = [round(Int, value(x[i])) for i = 1:3]
                val = sol[1] * sol[2] * sol[3] + sol[1] + sol[2]
                @test 1 <= val <= 2
                # Max is achieved at [1, 1, 0] (val = 2, obj = 5) or [1, 0, 1] (val = 1, obj = 4)
                @test sol == [1, 1, 0]
                @test ToQUBO.is_feasible(model)
                @test ToQUBO.source_objective_value(model) ≈ 5.0
            end

            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()
                x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
                ToQUBO.Compiler.variables!(model, arch)
                f = MOI.ScalarNonlinearFunction(
                    :+,
                    Any[MOI.ScalarNonlinearFunction(:*, Any[x[1], x[2], x[3]]), x[1]],
                )
                s = MOI.Interval{Float64}(1.0, 1.0)
                ci = MOI.ConstraintIndex{MOI.ScalarNonlinearFunction,MOI.Interval{Float64}}(1)
                p = ToQUBO.Compiler.constraint(model, ci, f, s, arch)
                @test !isnothing(p)
                @test MOI.get(model, Attributes.Quadratize()) === true
            end

            # 5. Sign-definite cubic residual, LinearPenalty, UnbalancedPenalty, and AugmentedLagrangianPenalty
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()
                x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
                ToQUBO.Compiler.variables!(model, arch)
                y = [only(ToQUBO.Virtual.target(model.source[xi])) for xi in x]

                f_pos = MOI.ScalarNonlinearFunction(:*, Any[1.0, x[1], x[2], x[3]])
                ci_eq = MOI.add_constraint(model.source_model, f_pos, MOI.EqualTo(0.0))
                p_eq = ToQUBO.Compiler.constraint(model, ci_eq, f_pos, MOI.EqualTo(0.0), arch)
                @test p_eq == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 1.0)
                @test MOI.get(model, Attributes.Quadratize()) === true

                MOI.set(model, Attributes.Quadratize(), false)
                ci_lt = MOI.add_constraint(model.source_model, f_pos, MOI.LessThan(0.0))
                p_lt = ToQUBO.Compiler.constraint(model, ci_lt, f_pos, MOI.LessThan(0.0), arch)
                @test p_lt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 1.0)
                @test MOI.get(model, Attributes.Quadratize()) === true

                MOI.set(model, Attributes.Quadratize(), false)
                f_neg = MOI.ScalarNonlinearFunction(:-, Any[f_pos])
                ci_gt = MOI.add_constraint(model.source_model, f_neg, MOI.GreaterThan(0.0))
                p_gt = ToQUBO.Compiler.constraint(model, ci_gt, f_neg, MOI.GreaterThan(0.0), arch)
                @test p_gt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 1.0)
                @test MOI.get(model, Attributes.Quadratize()) === true

                # UnbalancedPenalty on LT and GT
                MOI.set(model, Attributes.Quadratize(), false)
                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci_lt,
                    Attributes.UnbalancedPenalty(1.0, 2.0),
                )
                p_unb_lt = ToQUBO.Compiler.constraint(model, ci_lt, f_pos, MOI.LessThan(0.0), arch)
                @test p_unb_lt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 3.0)
                @test MOI.get(model, Attributes.Quadratize()) === true

                MOI.set(model, Attributes.Quadratize(), false)
                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci_gt,
                    Attributes.UnbalancedPenalty(1.0, 2.0),
                )
                p_unb_gt = ToQUBO.Compiler.constraint(model, ci_gt, f_neg, MOI.GreaterThan(0.0), arch)
                @test p_unb_gt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 3.0)
                @test MOI.get(model, Attributes.Quadratize()) === true

                # AugmentedLagrangianPenalty on EQ, LT, and GT
                MOI.set(model, Attributes.Quadratize(), false)
                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci_eq,
                    Attributes.AugmentedLagrangianPenalty(0.5, 2.0),
                )
                p_alm_eq = ToQUBO.Compiler.constraint(model, ci_eq, f_pos, MOI.EqualTo(0.0), arch)
                @test p_alm_eq == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 2.5)
                @test MOI.get(model, Attributes.Quadratize()) === true

                MOI.set(model, Attributes.Quadratize(), false)
                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci_lt,
                    Attributes.AugmentedLagrangianPenalty(0.5, 2.0),
                )
                p_alm_lt = ToQUBO.Compiler.constraint(model, ci_lt, f_pos, MOI.LessThan(0.0), arch)
                @test p_alm_lt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 2.5)
                @test MOI.get(model, Attributes.Quadratize()) === true

                MOI.set(model, Attributes.Quadratize(), false)
                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci_gt,
                    Attributes.AugmentedLagrangianPenalty(0.5, 2.0),
                )
                p_alm_gt = ToQUBO.Compiler.constraint(model, ci_gt, f_neg, MOI.GreaterThan(0.0), arch)
                @test p_alm_gt == PBO.PBF{VI,Float64}([y[1], y[2], y[3]] => 2.5)
                @test MOI.get(model, Attributes.Quadratize()) === true
            end

            # 6. Boolean logic gadget via ScalarNonlinearFunction (XOR and AND)
            let model = ToQUBO.Virtual.Model{Float64}()
                arch = ToQUBO.Compiler.GenericArchitecture()
                x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
                ToQUBO.Compiler.variables!(model, arch)
                y = [only(ToQUBO.Virtual.target(model.source[xi])) for xi in x]

                # AND: x3 - x1*x2 == 0
                f_and = MOI.ScalarNonlinearFunction(
                    :-,
                    Any[x[3], MOI.ScalarNonlinearFunction(:*, Any[x[1], x[2]])],
                )
                ci_and = MOI.add_constraint(model.source_model, f_and, MOI.EqualTo(0.0))
                g_and = ToQUBO.Compiler.constraint(model, ci_and, f_and, MOI.EqualTo(0.0), arch)
                @test g_and == PBO.PBF{VI,Float64}(
                    y[3] => 3.0,
                    [y[1], y[2]] => 1.0,
                    [y[1], y[3]] => -2.0,
                    [y[2], y[3]] => -2.0,
                )
                @test MOI.get(model, Attributes.Quadratize()) === false
            end

            # 7. Violated soft SNF constraint populates ConstraintViolation.variable_values
            let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:3], Bin)
                @objective(model, Min, x[1] + x[2] + x[3])
                c = @constraint(model, x[1] * x[2] * x[3] == 1)
                MOI.set(model, Attributes.SoftConstraint(), c, true)
                MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, 0.1)
                optimize!(model)

                v = only(ToQUBO.violations(model; result = 1, include_soft = true))
                @test v.soft === true
                @test v.function_type == MOI.ScalarNonlinearFunction
                @test v.set_type == MOI.EqualTo{Float64}
                @test length(v.variable_values) == 3
                @test all(val -> val ≈ 0.0, values(v.variable_values))
            end
        end

        @testset "Descriptive rejection of non-polynomial ScalarNonlinearFunction expressions" begin
            # 1. Non-polynomial unary operators in objective and constraints
            for op in (:sin, :cos, :exp, :log, :sqrt)
                let model = ToQUBO.Optimizer{Float64}()
                    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    f = MOI.ScalarNonlinearFunction(op, Any[x])
                    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}(), f)

                    err = try
                        MOI.optimize!(model)
                        nothing
                    catch e
                        e
                    end
                    @test err isa ToQUBO.Compiler.CompilationError
                    @test occursin(string(op), err.msg)
                    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
                    @test MOI.get(model, MOI.RawStatusString()) ==
                          "Unsupported nonlinear expression"
                end

                let model = ToQUBO.Optimizer{Float64}()
                    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    f = MOI.ScalarNonlinearFunction(op, Any[x])
                    MOI.add_constraint(model, f, MOI.EqualTo(0.0))

                    err = try
                        MOI.optimize!(model)
                        nothing
                    catch e
                        e
                    end
                    @test err isa ToQUBO.Compiler.CompilationError
                    @test occursin(string(op), err.msg)
                    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
                end
            end

            # 2. Non-constant division and division by zero
            for denom in (:variable, :zero)
                let model = ToQUBO.Optimizer{Float64}()
                    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    f = MOI.ScalarNonlinearFunction(
                        :/,
                        Any[x, denom === :variable ? y : 0.0],
                    )
                    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}(), f)

                    err = try
                        MOI.optimize!(model)
                        nothing
                    catch e
                        e
                    end
                    @test err isa ToQUBO.Compiler.CompilationError
                    @test occursin("/", err.msg)
                    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
                end
            end

            # 3. Invalid exponents in `^`: negative, fractional, and non-constant
            for bad_exp in (-1, 1.5, :variable)
                let model = ToQUBO.Optimizer{Float64}()
                    x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    f = MOI.ScalarNonlinearFunction(
                        :^,
                        Any[x, bad_exp === :variable ? y : bad_exp],
                    )
                    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}(), f)

                    err = try
                        MOI.optimize!(model)
                        nothing
                    catch e
                        e
                    end
                    @test err isa ToQUBO.Compiler.CompilationError
                    @test occursin("^", err.msg)
                    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
                end
            end
        end
    end

    return nothing
end

