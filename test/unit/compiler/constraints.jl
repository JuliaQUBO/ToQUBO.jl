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

function test_compiler_constraints()
    @testset "→ Constraints" verbose = true begin
        test_compiler_constraints_quadratic()
        test_compiler_constraints_linear_penalty()
        test_compiler_constraints_linear_penalty_requires_hint()
        test_compiler_constraints_sos1_domain_wall()
    end

    return nothing
end
