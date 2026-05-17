function test_compiler_constraints_quadratic()
    n = 3
    A = [
        -1.0  2.0  2.0
         2.0 -1.0  2.0
         2.0  2.0 -1.0
    ]
    b = 6.0

    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), n))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(A[i, j], x[i], x[j]) for i = 1:n for j = 1:n if i != j],
        [MOI.ScalarAffineTerm(A[i, i] / 2.0, x[i]) for i = 1:n],
        0.0,
    )
    s = MOI.EqualTo{Float64}(b)
    c = MOI.add_constraint(model.source_model, f, s)
    g = ToQUBO.Compiler.constraint(model, c, f, s, arch)

    h = ToQUBO.PBO.PBF{VI,Float64}()

    ToQUBO.Compiler.parse!(model, h, f, s, arch)

    @test h == PBO.PBF{VI,Float64}(
        -6.0,
        x[1] => -0.5,
        x[2] => -0.5,
        x[3] => -0.5,
        [x[1], x[2]] => 4.0,
        [x[1], x[3]] => 4.0,
        [x[2], x[3]] => 4.0,
    )

    @test g == PBO.PBF{VI,Float64}(
        144.0,
        x[1] => 25.0,
        x[2] => 25.0,
        x[3] => 25.0,
        [x[1], x[2]] => -158.0,
        [x[1], x[3]] => -158.0,
        [x[2], x[3]] => -158.0,
        [x[1], x[2], x[3]] => 336.0,
    )

    return nothing
end

function test_compiler_constraints_linear_penalty()
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(1.0, x[2]),
        ],
        0.0,
    )
    s = MOI.EqualTo{Float64}(1.0)
    c = MOI.add_constraint(model.source_model, f, s)

    g_quadratic = ToQUBO.Compiler.constraint(model, c, f, s, arch)

    @test g_quadratic == PBO.PBF{VI,Float64}(
        1.0,
        x[1] => -1.0,
        x[2] => -1.0,
        [x[1], x[2]] => 2.0,
    )

    MOI.set(
        model,
        Attributes.DefaultConstraintEncodingMethod(),
        Attributes.LinearPenalty(),
    )

    g_linear = ToQUBO.Compiler.constraint(model, c, f, s, arch)

    @test g_linear == PBO.PBF{VI,Float64}(
        -1.0,
        x[1] => 1.0,
        x[2] => 1.0,
    )
    @test MOI.get(model, Attributes.Quadratize()) === false

    MOI.set(
        model,
        Attributes.ConstraintEncodingMethod(),
        c,
        Attributes.QuadraticPenalty(),
    )

    g_override = ToQUBO.Compiler.constraint(model, c, f, s, arch)

    @test g_override == g_quadratic

    return nothing
end

function test_compiler_constraints_linear_penalty_requires_hint()
    model = ToQUBO.Optimizer{Float64}()
    x     = [MOI.add_variable(model) for _ = 1:2]

    for xi in x
        MOI.add_constraint(model, xi, MOI.ZeroOne())
    end

    f = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(1.0, x[2]),
        ],
        0.0,
    )
    c = MOI.add_constraint(model, f, MOI.EqualTo{Float64}(1.0))

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
    )
    MOI.set(
        model,
        Attributes.DefaultConstraintEncodingMethod(),
        Attributes.LinearPenalty(),
    )

    @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)
    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
    @test MOI.get(model, MOI.RawStatusString()) ==
          "Missing linear constraint penalty hint"

    MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, -2.0)
    MOI.optimize!(model)

    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == -2.0

    return nothing
end

function test_compiler_constraints_sign_definite_penalty()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))

    ToQUBO.Compiler.variables!(model, arch)

    f_affine = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(1.0, x[2]),
        ],
        0.0,
    )
    s_affine = MOI.EqualTo{Float64}(0.0)
    c_affine = MOI.add_constraint(model.source_model, f_affine, s_affine)

    @test ToQUBO.Compiler.constraint(model, c_affine, f_affine, s_affine, arch) ==
          PBO.PBF{VI,Float64}(
              x[1] => 1.0,
              x[2] => 1.0,
          )

    s_affine_lt = MOI.LessThan{Float64}(0.0)
    c_affine_lt = MOI.add_constraint(model.source_model, f_affine, s_affine_lt)

    @test ToQUBO.Compiler.constraint(model, c_affine_lt, f_affine, s_affine_lt, arch) ==
          PBO.PBF{VI,Float64}(
              x[1] => 1.0,
              x[2] => 1.0,
          )

    f_negative = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(-1.0, x[1]),
            MOI.ScalarAffineTerm(-1.0, x[2]),
        ],
        0.0,
    )
    s_negative = MOI.GreaterThan{Float64}(0.0)
    c_negative = MOI.add_constraint(model.source_model, f_negative, s_negative)

    @test ToQUBO.Compiler.constraint(model, c_negative, f_negative, s_negative, arch) ==
          PBO.PBF{VI,Float64}(
              x[1] => 1.0,
              x[2] => 1.0,
          )

    f_quadratic = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(1.0, x[1], x[2])],
        [MOI.ScalarAffineTerm(1.0, x[3])],
        0.0,
    )
    s_quadratic = MOI.EqualTo{Float64}(0.0)
    c_quadratic = MOI.add_constraint(model.source_model, f_quadratic, s_quadratic)

    @test ToQUBO.Compiler.constraint(model, c_quadratic, f_quadratic, s_quadratic, arch) ==
          PBO.PBF{VI,Float64}(
              x[3] => 1.0,
              [x[1], x[2]] => 1.0,
          )
    @test MOI.get(model, Attributes.Quadratize()) === false

    s_quadratic_lt = MOI.LessThan{Float64}(0.0)
    c_quadratic_lt = MOI.add_constraint(model.source_model, f_quadratic, s_quadratic_lt)
    g_quadratic_lt = ToQUBO.Compiler.constraint(
        model,
        c_quadratic_lt,
        f_quadratic,
        s_quadratic_lt,
        arch,
    )

    @test g_quadratic_lt ==
          PBO.PBF{VI,Float64}(
              x[3] => 1.0,
              [x[1], x[2]] => 1.0,
          )

    return nothing
end

function test_compiler_constraints_quadratic_greater_than_always_feasible()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(1.0, x[1], x[2])],
        [MOI.ScalarAffineTerm(1.0, x[1])],
        1.0,
    )
    s = MOI.GreaterThan{Float64}(0.0)
    c = MOI.add_constraint(model.source_model, f, s)

    @test_logs (:warn, r"Always-feasible constraint detected") begin
        @test ToQUBO.Compiler.constraint(model, c, f, s, arch) === nothing
    end

    return nothing
end

function test_compiler_constraints_feasibility_actions()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)

    feasible_f = MOI.ScalarAffineFunction{Float64}(
        [MOI.ScalarAffineTerm(1.0, x[1])],
        0.0,
    )
    feasible_s = MOI.LessThan{Float64}(1.0)
    feasible_c = MOI.add_constraint(model.source_model, feasible_f, feasible_s)

    @test_logs (:warn, r"Always-feasible constraint detected") begin
        @test ToQUBO.Compiler.constraint(
            model,
            feasible_c,
            feasible_f,
            feasible_s,
            arch,
        ) === nothing
    end

    MOI.set(model, Attributes.IgnoreFeasibleConstraints(), false)

    feasible_penalty = nothing
    @test_logs (:warn, r"Always-feasible constraint detected") begin
        feasible_penalty = ToQUBO.Compiler.constraint(
            model,
            feasible_c,
            feasible_f,
            feasible_s,
            arch,
        )
    end
    @test feasible_penalty !== nothing
    @test haskey(model.slack, feasible_c)

    infeasible_f = MOI.ScalarAffineFunction{Float64}(
        [MOI.ScalarAffineTerm(1.0, x[2])],
        1.0,
    )
    infeasible_s = MOI.LessThan{Float64}(0.0)
    infeasible_c = MOI.add_constraint(model.source_model, infeasible_f, infeasible_s)

    infeasible_penalty = nothing
    @test_logs (:warn, r"Infeasible constraint detected") begin
        infeasible_penalty = ToQUBO.Compiler.constraint(
            model,
            infeasible_c,
            infeasible_f,
            infeasible_s,
            arch,
        )
    end
    @test infeasible_penalty == PBO.PBF{VI,Float64}(1.0, x[2] => 1.0)
    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OPTIMIZE_NOT_CALLED

    return nothing
end

function test_compiler_constraints_strict_infeasible_status()
    function infeasible_model(constructor = nothing)
        model = ToQUBO.Optimizer{Float64}(constructor)
        x     = MOI.add_variable(model)

        MOI.add_constraint(model, x, MOI.ZeroOne())

        f = MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, x)],
            1.0,
        )
        MOI.add_constraint(model, f, MOI.LessThan{Float64}(0.0))

        MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        MOI.set(
            model,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
            MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
        )
        MOI.set(model, Attributes.ErrorInfeasibleConstraints(), true)

        return model
    end

    for model in (
        infeasible_model(),
        infeasible_model(ExactSampler.Optimizer),
    )
        @test_logs (:warn, r"Infeasible constraint detected") begin
            @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)
        end
        @test MOI.get(model, Attributes.CompilationStatus()) == MOI.INFEASIBLE
        @test MOI.get(model, MOI.TerminationStatus()) == MOI.INFEASIBLE
        @test occursin("Infeasible constraint detected", MOI.get(model, MOI.RawStatusString()))
    end

    return nothing
end

function test_compiler_constraints_equality_feasibility_classification()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 1))

    ToQUBO.Compiler.variables!(model, arch)

    zero_f = MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0)
    zero_s = MOI.EqualTo{Float64}(0.0)
    zero_c = MOI.add_constraint(model.source_model, zero_f, zero_s)

    @test_logs (:warn, r"Always-feasible constraint detected") begin
        @test ToQUBO.Compiler.constraint(model, zero_c, zero_f, zero_s, arch) === nothing
    end

    infeasible_f = MOI.ScalarAffineFunction{Float64}(
        [MOI.ScalarAffineTerm(1.0, x[1])],
        0.0,
    )
    infeasible_s = MOI.EqualTo{Float64}(2.0)
    infeasible_c = MOI.add_constraint(model.source_model, infeasible_f, infeasible_s)

    infeasible_penalty = nothing
    @test_logs (:warn, r"Infeasible constraint detected") begin
        infeasible_penalty = ToQUBO.Compiler.constraint(
            model,
            infeasible_c,
            infeasible_f,
            infeasible_s,
            arch,
        )
    end
    @test infeasible_penalty !== nothing

    return nothing
end

function test_compiler_constraints_indicator_inner_infeasible_is_gated()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)
    MOI.set(model, Attributes.ErrorInfeasibleConstraints(), true)

    f = MOI.VectorAffineFunction{Float64}(
        [
            MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1])),
            MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[2])),
        ],
        [0.0, 1.0],
    )
    s = MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.LessThan{Float64}(0.0))
    c = MOI.add_constraint(model.source_model, f, s)

    penalty = nothing
    @test_logs (:warn, r"Infeasible constraint detected") begin
        penalty = ToQUBO.Compiler.constraint(model, c, f, s, arch)
    end

    @test penalty == PBO.PBF{VI,Float64}(
        x[1] => 1.0,
        [x[1], x[2]] => 1.0,
    )
    @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OPTIMIZE_NOT_CALLED

    return nothing
end

function test_compiler_constraints_sos1_domain_wall()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
    s     = MOI.SOS1{Float64}([1.0, 2.0, 3.0])
    c     = MOI.add_constraint(model.source_model, MOI.VectorOfVariables(x), s)

    ToQUBO.Compiler.variables!(model, arch)

    v = model.slack[c]
    y = ToQUBO.Virtual.target(v)

    @test ToQUBO.Virtual.encoding(v) isa Encoding.DomainWall
    @test length(y) == 3
    @test MOI.get(model.target_model, MOI.ListOfVariableIndices()) == y
    @test ToQUBO.Virtual.expansion(model.source[x[1]]) ==
          PBO.PBF{VI,Float64}([y[1] => 1.0, y[2] => -1.0])
    @test ToQUBO.Virtual.expansion(model.source[x[2]]) ==
          PBO.PBF{VI,Float64}([y[2] => 1.0, y[3] => -1.0])
    @test ToQUBO.Virtual.expansion(model.source[x[3]]) == PBO.PBF{VI,Float64}(y[3] => 1.0)

    f = MOI.ScalarAffineFunction{Float64}(
        [
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(2.0, x[2]),
            MOI.ScalarAffineTerm(3.0, x[3]),
        ],
        0.0,
    )
    h = PBO.PBF{VI,Float64}()

    ToQUBO.Compiler.parse!(model, h, f, arch)

    @test h == PBO.PBF{VI,Float64}(y[1] => 1.0, y[2] => 1.0, y[3] => 1.0)
    @test ToQUBO.Compiler.constraint(model, c, MOI.VectorOfVariables(x), s, arch) ==
          PBO.PBF{VI,Float64}(
              y[2] => 2.0,
              y[3] => 2.0,
              [y[1], y[2]] => -2.0,
              [y[2], y[3]] => -2.0,
          )

    return nothing
end

function test_compiler_constraints_sos1_domain_wall_indicator_activation()
    function indicator_function(::Val{:affine}, x)
        return MOI.VectorAffineFunction{Float64}(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1])),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[2])),
            ],
            [0.0, 0.0],
        )
    end

    function indicator_function(::Val{:quadratic}, x)
        return MOI.VectorQuadraticFunction{Float64}(
            [MOI.VectorQuadraticTerm(2, MOI.ScalarQuadraticTerm(1.0, x[2], x[2]))],
            [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1]))],
            [0.0, 0.0],
        )
    end

    for (label, function_type) in ("affine" => Val(:affine), "quadratic" => Val(:quadratic))
        for activation in (MOI.ACTIVATE_ON_ONE, MOI.ACTIVATE_ON_ZERO)
            @testset "$(label) $(activation)" begin
                model = ToQUBO.Optimizer{Float64}()
                x, _  = MOI.add_constrained_variables(model, fill(MOI.ZeroOne(), 2))

                c = MOI.add_constraint(
                    model,
                    MOI.VectorOfVariables(x),
                    MOI.SOS1{Float64}([1.0, 2.0]),
                )

                MOI.add_constraint(
                    model,
                    indicator_function(function_type, x),
                    MOI.Indicator{activation}(MOI.LessThan{Float64}(0.0)),
                )
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(
                    model,
                    MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                    MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
                )

                MOI.optimize!(model)

                y = ToQUBO.Virtual.target(model.slack[c])

                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED
                @test ToQUBO.Virtual.encoding(model.source[x[1]]) isa Encoding.DomainWall
                @test ToQUBO.Compiler._indicator_activation(model, x[1]) ==
                      PBO.PBF{VI,Float64}(y[1]) * (1.0 - PBO.PBF{VI,Float64}(y[2]))
                @test ToQUBO.Compiler._indicator_activation(model, x[2]) ==
                      PBO.PBF{VI,Float64}(y[2])
            end
        end
    end

    return nothing
end

function test_compiler_constraints_quadratic_indicator_keeps_inner_terms()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.VectorQuadraticFunction{Float64}(
        [MOI.VectorQuadraticTerm(2, MOI.ScalarQuadraticTerm(1.0, x[2], x[3]))],
        [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1]))],
        [0.0, 0.0],
    )
    s = MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.LessThan{Float64}(0.0))
    c = MOI.add_constraint(model.source_model, f, s)

    @test ToQUBO.Compiler.constraint(model, c, f, s, arch) ==
          PBO.PBF{VI,Float64}([x[1], x[2], x[3]] => 1.0)

    return nothing
end

function test_compiler_constraints_indicator_interval_sets()
    for activation in (MOI.ACTIVATE_ON_ONE, MOI.ACTIVATE_ON_ZERO)
        model = ToQUBO.Virtual.Model{Float64}()
        arch  = ToQUBO.Compiler.GenericArchitecture()
        x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))

        ToQUBO.Compiler.variables!(model, arch)

        s = MOI.Indicator{activation}(MOI.Interval{Float64}(-1.0, 0.0))
        y = PBO.PBF{VI,Float64}(x[1] => 1.0)
        a = activation === MOI.ACTIVATE_ON_ONE ? y : 1.0 - y

        f_affine = MOI.VectorAffineFunction{Float64}(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1])),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[2])),
            ],
            [0.0, 0.0],
        )
        c_affine = MOI.add_constraint(model.source_model, f_affine, s)

        @test ToQUBO.Compiler.constraint(model, c_affine, f_affine, s, arch) ==
              a * PBO.PBF{VI,Float64}(x[2] => 1.0)

        f_quadratic = MOI.VectorQuadraticFunction{Float64}(
            [MOI.VectorQuadraticTerm(2, MOI.ScalarQuadraticTerm(1.0, x[2], x[3]))],
            [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1]))],
            [0.0, 0.0],
        )
        c_quadratic = MOI.add_constraint(model.source_model, f_quadratic, s)

        @test ToQUBO.Compiler.constraint(model, c_quadratic, f_quadratic, s, arch) ==
              a * PBO.PBF{VI,Float64}([x[2], x[3]] => 1.0)
    end

    return nothing
end

function test_compiler_constraints_trivial_indicator_inner_does_not_quadratize()
    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.VectorAffineFunction{Float64}(
        [
            MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x[1])),
            MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[2])),
        ],
        [0.0, 0.0],
    )
    s = MOI.Indicator{MOI.ACTIVATE_ON_ONE}(MOI.GreaterThan{Float64}(-1.0))
    c = MOI.add_constraint(model.source_model, f, s)

    @test ToQUBO.Compiler.constraint(model, c, f, s, arch) === nothing
    @test MOI.get(model, Attributes.Quadratize()) === false

    return nothing
end

function test_compiler_constraints()
    @testset "→ Constraints" verbose = true begin
        test_compiler_constraints_quadratic()
        test_compiler_constraints_linear_penalty()
        test_compiler_constraints_linear_penalty_requires_hint()
        test_compiler_constraints_sign_definite_penalty()
        test_compiler_constraints_quadratic_greater_than_always_feasible()
        test_compiler_constraints_feasibility_actions()
        test_compiler_constraints_strict_infeasible_status()
        test_compiler_constraints_equality_feasibility_classification()
        test_compiler_constraints_indicator_inner_infeasible_is_gated()
        test_compiler_constraints_sos1_domain_wall()
        test_compiler_constraints_sos1_domain_wall_indicator_activation()
        test_compiler_constraints_quadratic_indicator_keeps_inner_terms()
        test_compiler_constraints_indicator_interval_sets()
        test_compiler_constraints_trivial_indicator_inner_does_not_quadratize()
    end

    return nothing
end
