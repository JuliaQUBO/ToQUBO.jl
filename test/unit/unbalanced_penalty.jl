function _issue_207_affine_constraint(set)
    model = ToQUBO.Virtual.Model{Float64}()
    arch = ToQUBO.Compiler.GenericArchitecture()
    x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 2))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.ScalarAffineFunction{Float64}(
        [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
        0.0,
    )
    ci = if MOI.supports_constraint(model.source_model, typeof(f), typeof(set))
        MOI.add_constraint(model.source_model, f, set)
    else
        MOI.ConstraintIndex{typeof(f),typeof(set)}(1)
    end

    return model, arch, x, f, ci
end

function _issue_207_value(g, x, values)
    assignment = Dict(xi => value for (xi, value) in zip(x, values))

    return convert(Float64, g(assignment))
end

function _issue_207_mixed_integer_model(method = nothing)
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)
    y = MOI.add_variable(model)

    MOI.add_constraint(model, x, MOI.ZeroOne())
    MOI.add_constraint(model, y, MOI.Integer())
    MOI.add_constraint(model, y, MOI.Interval{Float64}(0.0, 2.0))

    f = MOI.ScalarAffineFunction{Float64}(
        [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1.0, y)],
        0.0,
    )
    ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
    )

    if !isnothing(method)
        MOI.set(model, Attributes.ConstraintEncodingMethod(), ci, method)
        MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), ci, 2.0)
    end

    MOI.optimize!(model)

    return model, ci
end

function test_unbalanced_penalty()
    @testset "Unbalanced inequality penalty" begin
        @testset "method parameters" begin
            method = Attributes.UnbalancedPenalty()

            @test method.linear == 1.0
            @test method.quadratic == 0.5
            @test Attributes.UnbalancedPenalty(2, 3) == Attributes.UnbalancedPenalty(2, 3)
            @test_throws ArgumentError Attributes.UnbalancedPenalty(0.0, 0.5)
            @test_throws ArgumentError Attributes.UnbalancedPenalty(1.0, 0.0)
        end

        @testset "less-than penalty avoids slack variables" begin
            set = MOI.LessThan{Float64}(1.0)
            slack_model, slack_arch, _, slack_f, slack_ci =
                _issue_207_affine_constraint(set)
            slack_penalty =
                ToQUBO.Compiler.constraint(slack_model, slack_ci, slack_f, set, slack_arch)

            model, arch, x, f, ci = _issue_207_affine_constraint(set)
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(),
            )
            penalty = ToQUBO.Compiler.constraint(model, ci, f, set, arch)
            target = [_target_var(model, xi) for xi in x]

            @test haskey(slack_model.slack, slack_ci)
            @test length(PBO.variables(slack_penalty)) > length(x)
            @test !haskey(model.slack, ci)
            @test Set(PBO.variables(penalty)) == Set(target)
            @test _issue_207_value(penalty, target, (0, 0)) == -0.5
            @test _issue_207_value(penalty, target, (1, 0)) == 0.0
            @test _issue_207_value(penalty, target, (1, 1)) == 1.5
        end

        @testset "wider coefficient types convert to the model's" begin
            # A BigFloat-parameterized method on a Float64 model previously
            # built a malformed PBF; it now converts and matches the defaults.
            set = MOI.LessThan{Float64}(1.0)
            model, arch, x, f, ci = _issue_207_affine_constraint(set)
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(big"1.0", big"0.5"),
            )
            penalty = ToQUBO.Compiler.constraint(model, ci, f, set, arch)
            target = [_target_var(model, xi) for xi in x]

            @test _issue_207_value(penalty, target, (0, 0)) == -0.5
            @test _issue_207_value(penalty, target, (1, 0)) == 0.0
            @test _issue_207_value(penalty, target, (1, 1)) == 1.5
        end

        @testset "greater-than and interval orientation" begin
            set = MOI.GreaterThan{Float64}(1.0)
            model, arch, x, f, ci = _issue_207_affine_constraint(set)
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(),
            )
            penalty = ToQUBO.Compiler.constraint(model, ci, f, set, arch)
            target = [_target_var(model, xi) for xi in x]

            @test _issue_207_value(penalty, target, (0, 0)) == 1.5
            @test _issue_207_value(penalty, target, (1, 0)) == 0.0
            @test _issue_207_value(penalty, target, (1, 1)) == -0.5
            @test !haskey(model.slack, ci)

            interval = MOI.Interval{Float64}(1.0, 1.0)
            interval_model, interval_arch, interval_x, interval_f, interval_ci =
                _issue_207_affine_constraint(interval)
            MOI.set(
                interval_model,
                Attributes.ConstraintEncodingMethod(),
                interval_ci,
                Attributes.UnbalancedPenalty(),
            )
            interval_penalty = ToQUBO.Compiler.constraint(
                interval_model,
                interval_ci,
                interval_f,
                interval,
                interval_arch,
            )
            interval_target = [_target_var(interval_model, xi) for xi in interval_x]

            @test _issue_207_value(interval_penalty, interval_target, (0, 0)) == 1.0
            @test _issue_207_value(interval_penalty, interval_target, (1, 0)) == 0.0
            @test _issue_207_value(interval_penalty, interval_target, (1, 1)) == 1.0
            @test !haskey(interval_model.slack, interval_ci)
        end

        @testset "quadratic inequalities request quadratization" begin
            model = ToQUBO.Virtual.Model{Float64}()
            arch = ToQUBO.Compiler.GenericArchitecture()
            x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))

            ToQUBO.Compiler.variables!(model, arch)

            f = MOI.ScalarQuadraticFunction{Float64}(
                [MOI.ScalarQuadraticTerm(1.0, x[1], x[2])],
                [MOI.ScalarAffineTerm(1.0, x[3])],
                0.0,
            )
            set = MOI.LessThan{Float64}(1.0)
            ci = MOI.add_constraint(model.source_model, f, set)
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(2.0, 1.0),
            )
            penalty = ToQUBO.Compiler.constraint(model, ci, f, set, arch)

            @test !haskey(model.slack, ci)
            @test MOI.get(model, Attributes.Quadratize()) === true
            @test any(length(term) > 2 for (term, _) in penalty)
        end

        @testset "explicit coefficient is required" begin
            model = ToQUBO.Optimizer{Float64}()
            x = [MOI.add_variable(model) for _ = 1:2]

            for xi in x
                MOI.add_constraint(model, xi, MOI.ZeroOne())
            end

            f = MOI.ScalarAffineFunction{Float64}(
                [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
                0.0,
            )
            ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

            MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
            MOI.set(
                model,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
            )
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(),
            )

            @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)
            @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
            @test MOI.get(model, MOI.RawStatusString()) ==
                  "Missing unbalanced constraint penalty hint"

            MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), ci, 2.0)
            MOI.optimize!(model)

            @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED
            @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), ci) == 2.0
        end

        @testset "mixed-integer target variable count" begin
            slack_model, slack_ci = _issue_207_mixed_integer_model()
            unbalanced_model, unbalanced_ci =
                _issue_207_mixed_integer_model(Attributes.UnbalancedPenalty())
            slack_count =
                length(MOI.get(slack_model.target_model, MOI.ListOfVariableIndices()))
            unbalanced_count =
                length(MOI.get(unbalanced_model.target_model, MOI.ListOfVariableIndices()))

            @test haskey(slack_model.slack, slack_ci)
            @test !haskey(unbalanced_model.slack, unbalanced_ci)
            @test unbalanced_count < slack_count
        end

        @testset "equality constraints reject the method" begin
            set = MOI.EqualTo{Float64}(1.0)
            model, arch, _, f, ci = _issue_207_affine_constraint(set)
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.UnbalancedPenalty(),
            )

            @test_throws ToQUBO.Compiler.CompilationError ToQUBO.Compiler.constraint(
                model,
                ci,
                f,
                set,
                arch,
            )
        end

        @testset "documentation explains the tradeoff" begin
            root = normpath(joinpath(@__DIR__, "..", ".."))
            settings = replace(
                read(joinpath(root, "docs", "src", "manual", "4-settings.md"), String),
                "\r\n" => "\n",
            )
            booklet = replace(
                read(joinpath(root, "docs", "src", "booklet", "4-encoding.md"), String),
                "\r\n" => "\n",
            )

            @test occursin("Attributes.UnbalancedPenalty()", settings)
            @test occursin("exact zero penalty", settings)
            @test occursin("target-variable budget", settings)
            @test occursin("10.1088/2058-9565/ad35e4", settings)
            @test occursin("K`` auxiliary binary", settings)
            @test occursin("slack-free", booklet)
        end
    end

    return nothing
end
