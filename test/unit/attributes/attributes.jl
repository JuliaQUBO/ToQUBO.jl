function test_compiler_attributes()
    @testset "→ Compiler Attributes" begin
        @testset "SourceModel and TargetModel" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.get(model, Attributes.SourceModel()) isa ToQUBO.PreQUBOModel{Float64}
                @test MOI.get(model, Attributes.TargetModel()) isa ToQUBO.QUBOModel{Float64}
            end
        end

        @testset "Formulation introspection" begin
            let model = ToQUBO.Optimizer{Float64}()
                x = MOI.add_variable(model)
                MOI.add_constraint(model, x, MOI.ZeroOne())

                y = MOI.add_variable(model)
                MOI.add_constraint(model, y, MOI.Integer())
                MOI.add_constraint(model, y, MOI.Interval{Float64}(0.0, 3.0))

                obj = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(2.0, x), MOI.ScalarAffineTerm(1.0, y)],
                    0.0,
                )
                con = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1.0, y)],
                    0.0,
                )
                ci = MOI.add_constraint(model, con, MOI.LessThan{Float64}(2.0))

                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{typeof(obj)}(), obj)

                @test MOI.supports(model, Attributes.CompiledObjectiveFunction())
                @test MOI.supports(model, Attributes.CompiledHamiltonian())
                @test MOI.supports(model, Attributes.VariableTargetVariables(), VI)
                @test MOI.supports(model, Attributes.VariableEncodingFunction(), VI)
                @test MOI.supports(model, Attributes.VariableEncodingPenaltyFunction(), VI)
                @test MOI.supports(
                    model,
                    Attributes.ConstraintEncodingFunction(),
                    typeof(ci),
                )
                @test MOI.supports(
                    model,
                    Attributes.SlackVariableTargetVariables(),
                    typeof(ci),
                )
                @test MOI.supports(
                    model,
                    Attributes.SlackVariableEncodingFunction(),
                    typeof(ci),
                )
                @test MOI.supports(
                    model,
                    Attributes.SlackVariableEncodingPenaltyFunction(),
                    typeof(ci),
                )

                @test MOI.get(model, Attributes.VariableTargetVariables(), x) === nothing
                @test MOI.get(model, Attributes.VariableEncodingFunction(), x) === nothing
                @test MOI.get(model, Attributes.ConstraintEncodingFunction(), ci) === nothing
                @test MOI.get(model, Attributes.SlackVariableTargetVariables(), ci) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingFunction(), ci) === nothing

                MOI.optimize!(model)

                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == model.f
                @test Attributes.compiled_objective_function(model) == model.f
                @test MOI.get(model, Attributes.CompiledHamiltonian()) == model.H
                @test Attributes.compiled_hamiltonian(model) == model.H

                objective = MOI.get(model, Attributes.CompiledObjectiveFunction())
                objective[nothing] += 1.0
                @test objective != model.f
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == model.f

                targets = MOI.get(model, Attributes.VariableTargetVariables(), x)
                @test targets == ToQUBO.Virtual.target(model.source[x])
                @test targets !== ToQUBO.Virtual.target(model.source[x])
                push!(targets, VI(9999))
                @test targets != ToQUBO.Virtual.target(model.source[x])
                @test Attributes.variable_target_variables(model, x) ==
                      ToQUBO.Virtual.target(model.source[x])

                @test MOI.get(model, Attributes.VariableEncodingFunction(), x) ==
                      ToQUBO.Virtual.expansion(model.source[x])
                @test Attributes.variable_encoding_function(model, y) ==
                      ToQUBO.Virtual.expansion(model.source[y])
                @test MOI.get(
                    model,
                    Attributes.VariableEncodingPenaltyFunction(),
                    x,
                ) === nothing

                constraint = MOI.get(model, Attributes.ConstraintEncodingFunction(), ci)
                @test constraint == model.g[ci]
                @test Attributes.constraint_encoding_function(model, ci) == model.g[ci]
                constraint[nothing] += 1.0
                @test constraint != model.g[ci]

                @test MOI.get(model, Attributes.SlackVariableTargetVariables(), ci) ==
                      ToQUBO.Virtual.target(model.slack[ci])
                @test Attributes.slack_variable_target_variables(model, ci) ==
                      ToQUBO.Virtual.target(model.slack[ci])
                @test MOI.get(model, Attributes.SlackVariableEncodingFunction(), ci) ==
                      ToQUBO.Virtual.expansion(model.slack[ci])
                @test Attributes.slack_variable_encoding_function(model, ci) ==
                      ToQUBO.Virtual.expansion(model.slack[ci])
                @test MOI.get(
                    model,
                    Attributes.SlackVariableEncodingPenaltyFunction(),
                    ci,
                ) === nothing
            end
        end

        @testset "Formulation introspection for already-QUBO models" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                obj = MOI.ScalarQuadraticFunction{Float64}(
                    [MOI.ScalarQuadraticTerm(3.0, x, y)],
                    [MOI.ScalarAffineTerm(2.0, x)],
                    1.0,
                )
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{typeof(obj)}(), obj)

                MOI.optimize!(model)

                x_target = only(MOI.get(model, Attributes.VariableTargetVariables(), x))
                y_target = only(MOI.get(model, Attributes.VariableTargetVariables(), y))
                expected = PBO.PBF{VI,Float64}(
                    1.0,
                    x_target => 2.0,
                    [x_target, y_target] => 3.0,
                )

                @test ToQUBO.Compiler.is_qubo(model.source_model)
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == expected
                @test MOI.get(model, Attributes.CompiledHamiltonian()) == expected
            end
        end

        @testset "Reset clears formulation introspection" begin
            let model = ToQUBO.Optimizer{Float64}()
                x = MOI.add_variable(model)
                MOI.add_constraint(model, x, MOI.ZeroOne())

                y = MOI.add_variable(model)
                MOI.add_constraint(model, y, MOI.Integer())
                MOI.add_constraint(model, y, MOI.Interval{Float64}(0.0, 3.0))

                obj = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, x)],
                    0.0,
                )
                con = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1.0, y)],
                    0.0,
                )
                ci = MOI.add_constraint(model, con, MOI.LessThan{Float64}(2.0))
                MOI.set(model, Attributes.SlackVariableEncodingMethod(), ci, Encoding.OneHot())

                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{typeof(obj)}(), obj)

                MOI.optimize!(model)

                @test !isempty(MOI.get(model, Attributes.CompiledHamiltonian()))
                @test MOI.get(model, Attributes.ConstraintEncodingFunction(), ci) !== nothing
                @test MOI.get(model, Attributes.SlackVariableTargetVariables(), ci) !== nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingFunction(), ci) !== nothing
                @test MOI.get(
                    model,
                    Attributes.SlackVariableEncodingPenaltyFunction(),
                    ci,
                ) !== nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), ci) !== nothing
                @test MOI.get(model, Attributes.CompilationStatus()) ==
                      MOI.LOCALLY_SOLVED
                @test MOI.get(model, Attributes.CompilationTime()) !== nothing
                @test MOI.get(model, MOI.RawStatusString()) ==
                      "Compilation complete without an internal solver"

                MOI.empty!(model)

                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) ==
                      PBO.PBF{VI,Float64}()
                @test MOI.get(model, Attributes.CompiledHamiltonian()) ==
                      PBO.PBF{VI,Float64}()
                @test MOI.get(model, Attributes.VariableTargetVariables(), x) === nothing
                @test MOI.get(model, Attributes.VariableEncodingFunction(), x) === nothing
                @test MOI.get(model, Attributes.ConstraintEncodingFunction(), ci) === nothing
                @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), ci) === nothing
                @test MOI.get(model, Attributes.SlackVariableTargetVariables(), ci) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingFunction(), ci) === nothing
                @test MOI.get(
                    model,
                    Attributes.SlackVariableEncodingPenaltyFunction(),
                    ci,
                ) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), ci) === nothing
                @test MOI.get(model, Attributes.CompilationStatus()) ==
                      MOI.OPTIMIZE_NOT_CALLED
                @test MOI.get(model, Attributes.CompilationTime()) === nothing
                @test MOI.get(model, MOI.RawStatusString()) == ""
            end
        end

        @testset "CompilationTime" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.CompilationTime())
                @test MOI.get(model, Attributes.CompilationTime()) === nothing

                MOI.set(model, Attributes.CompilationTime(), 1.5)
                @test MOI.get(model, Attributes.CompilationTime()) == 1.5
                @test Attributes.compilation_time(model) == 1.5

                MOI.set(model, Attributes.CompilationTime(), nothing)
                @test MOI.get(model, Attributes.CompilationTime()) === nothing
            end
        end

        @testset "CompilationStatus" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.CompilationStatus())
                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OPTIMIZE_NOT_CALLED
                @test Attributes.compilation_status(model) == MOI.OPTIMIZE_NOT_CALLED

                MOI.set(model, Attributes.CompilationStatus(), MOI.LOCALLY_SOLVED)
                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED

                MOI.set(model, Attributes.CompilationStatus(), nothing)
                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            end
        end

        @testset "Warnings" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.Warnings())
                @test MOI.get(model, Attributes.Warnings()) === true
                @test Attributes.warnings(model) === true

                MOI.set(model, Attributes.Warnings(), false)
                @test MOI.get(model, Attributes.Warnings()) === false

                MOI.set(model, Attributes.Warnings(), nothing)
                @test MOI.get(model, Attributes.Warnings()) === true
            end
        end

        @testset "PrimalFeasibilityCheck" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.PrimalFeasibilityCheck())
                @test MOI.get(model, Attributes.PrimalFeasibilityCheck()) === true
                @test Attributes.primal_feasibility_check(model) === true

                MOI.set(model, Attributes.PrimalFeasibilityCheck(), false)
                @test MOI.get(model, Attributes.PrimalFeasibilityCheck()) === false

                # User settings survive a compiler reset.
                ToQUBO.Compiler.reset!(model)
                @test MOI.get(model, Attributes.PrimalFeasibilityCheck()) === false

                MOI.set(model, Attributes.PrimalFeasibilityCheck(), nothing)
                @test MOI.get(model, Attributes.PrimalFeasibilityCheck()) === true
            end
        end

        @testset "AutoFeasibilityReport" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.AutoFeasibilityReport())
                @test MOI.get(model, Attributes.AutoFeasibilityReport()) === false
                @test Attributes.auto_feasibility_report(model) === false

                MOI.set(model, Attributes.AutoFeasibilityReport(), true)
                @test MOI.get(model, Attributes.AutoFeasibilityReport()) === true

                ToQUBO.Compiler.reset!(model)
                @test MOI.get(model, Attributes.AutoFeasibilityReport()) === true

                MOI.set(model, Attributes.AutoFeasibilityReport(), nothing)
                @test MOI.get(model, Attributes.AutoFeasibilityReport()) === false
            end
        end

        @testset "SourceObjectiveValue" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.SourceObjectiveValue())
                @test Attributes.SourceObjectiveValue().result_index == 1
                @test Attributes.SourceObjectiveValue(3).result_index == 3
                @test MOI.is_set_by_optimize(Attributes.SourceObjectiveValue())
            end
        end

        @testset "PenaltyPolicy" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.PenaltyPolicy())
                @test MOI.supports(model, Attributes.PenaltyPolicyMetadata())
                @test MOI.get(model, Attributes.PenaltyPolicy()) isa
                      Attributes.ObjectiveRangePenalty
                @test Attributes.penalty_policy(model) isa Attributes.ObjectiveRangePenalty
                @test MOI.get(model, Attributes.PenaltyPolicyMetadata()) === nothing
                @test Attributes.penalty_policy_metadata(model) === nothing

                MOI.set(model, Attributes.PenaltyPolicy(), Attributes.LegacyPenalty())
                @test MOI.get(model, Attributes.PenaltyPolicy()) isa Attributes.LegacyPenalty

                MOI.set(model, Attributes.PenaltyPolicy(), Attributes.ObjectiveRangePenalty())
                @test MOI.get(model, Attributes.PenaltyPolicy()) isa
                      Attributes.ObjectiveRangePenalty

                MOI.set(model, Attributes.PenaltyPolicy(), nothing)
                @test MOI.get(model, Attributes.PenaltyPolicy()) isa
                      Attributes.ObjectiveRangePenalty
            end
        end

        @testset "IgnoreFeasibleConstraints" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.IgnoreFeasibleConstraints())
                @test MOI.get(model, Attributes.IgnoreFeasibleConstraints()) === true
                @test Attributes.ignore_feasible_constraints(model) === true

                MOI.set(model, Attributes.IgnoreFeasibleConstraints(), false)
                @test MOI.get(model, Attributes.IgnoreFeasibleConstraints()) === false

                MOI.set(model, Attributes.IgnoreFeasibleConstraints(), nothing)
                @test MOI.get(model, Attributes.IgnoreFeasibleConstraints()) === true
            end
        end

        @testset "ErrorInfeasibleConstraints" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.ErrorInfeasibleConstraints())
                @test MOI.get(model, Attributes.ErrorInfeasibleConstraints()) === false
                @test Attributes.error_infeasible_constraints(model) === false

                MOI.set(model, Attributes.ErrorInfeasibleConstraints(), true)
                @test MOI.get(model, Attributes.ErrorInfeasibleConstraints()) === true

                MOI.set(model, Attributes.ErrorInfeasibleConstraints(), nothing)
                @test MOI.get(model, Attributes.ErrorInfeasibleConstraints()) === false
            end
        end

        @testset "Optimization" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.Optimization())
                @test MOI.get(model, Attributes.Optimization()) === 0
                @test Attributes.optimization(model) === 0

                MOI.set(model, Attributes.Optimization(), 3)
                @test MOI.get(model, Attributes.Optimization()) === 3

                MOI.set(model, Attributes.Optimization(), nothing)
                @test MOI.get(model, Attributes.Optimization()) === 0
            end
        end

        @testset "Architecture" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.Architecture())
                @test MOI.get(model, Attributes.Architecture()) isa QUBOTools.GenericArchitecture
                @test Attributes.architecture(model) isa QUBOTools.GenericArchitecture

                MOI.set(model, Attributes.Architecture(), QUBOTools.GenericArchitecture())
                @test MOI.get(model, Attributes.Architecture()) isa QUBOTools.GenericArchitecture

                MOI.set(model, Attributes.Architecture(), nothing)
                @test MOI.get(model, Attributes.Architecture()) isa QUBOTools.GenericArchitecture
            end
        end

        @testset "Discretize" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.Discretize())
                @test MOI.get(model, Attributes.Discretize()) === true
                @test Attributes.discretize(model) === true

                MOI.set(model, Attributes.Discretize(), false)
                @test MOI.get(model, Attributes.Discretize()) === false

                MOI.set(model, Attributes.Discretize(), nothing)
                @test MOI.get(model, Attributes.Discretize()) === true
            end
        end

        @testset "DefaultConstraintEncodingMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.DefaultConstraintEncodingMethod())
                @test MOI.get(
                    model,
                    Attributes.DefaultConstraintEncodingMethod(),
                ) isa Attributes.QuadraticPenalty
                @test Attributes.default_constraint_encoding_method(model) isa Attributes.QuadraticPenalty

                MOI.set(
                    model,
                    Attributes.DefaultConstraintEncodingMethod(),
                    Attributes.LinearPenalty(),
                )
                @test MOI.get(
                    model,
                    Attributes.DefaultConstraintEncodingMethod(),
                ) isa Attributes.LinearPenalty

                MOI.set(model, Attributes.DefaultConstraintEncodingMethod(), nothing)
                @test MOI.get(
                    model,
                    Attributes.DefaultConstraintEncodingMethod(),
                ) isa Attributes.QuadraticPenalty
            end
        end

        @testset "Quadratize" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.Quadratize())
                @test MOI.get(model, Attributes.Quadratize()) === false
                @test Attributes.quadratize(model) === false

                MOI.set(model, Attributes.Quadratize(), true)
                @test MOI.get(model, Attributes.Quadratize()) === true
            end
        end

        @testset "QuadratizationMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.QuadratizationMethod())
                @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.DEFAULT
                @test Attributes.quadratization_method(model) isa PBO.DEFAULT

                MOI.set(model, Attributes.QuadratizationMethod(), PBO.PTR_BG())
                @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.PTR_BG

                MOI.set(model, Attributes.QuadratizationMethod(), nothing)
                @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.DEFAULT
            end
        end

        @testset "StableQuadratization" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.StableQuadratization())
                @test MOI.get(model, Attributes.StableQuadratization()) === false

                MOI.set(model, Attributes.StableQuadratization(), true)
                @test MOI.get(model, Attributes.StableQuadratization()) === true

                MOI.set(model, Attributes.StableQuadratization(), nothing)
                @test MOI.get(model, Attributes.StableQuadratization()) === false
            end
        end

        @testset "StableCompilation" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.StableCompilation())
                @test MOI.get(model, Attributes.StableCompilation()) === false
                @test Attributes.stable_compilation(model) === false

                MOI.set(model, Attributes.StableCompilation(), true)
                @test MOI.get(model, Attributes.StableCompilation()) === true

                MOI.set(model, Attributes.StableCompilation(), nothing)
                @test MOI.get(model, Attributes.StableCompilation()) === false
            end
        end
    end

    return nothing
end

function test_encoding_attributes()
    @testset "→ Encoding Attributes" begin
        @testset "DefaultVariableEncodingMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.DefaultVariableEncodingMethod())
                @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Binary

                MOI.set(model, Attributes.DefaultVariableEncodingMethod(), Encoding.Unary())
                @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Unary

                MOI.set(model, Attributes.DefaultVariableEncodingMethod(), nothing)
                @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Binary
            end
        end

        @testset "DefaultVariableEncodingATol" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.DefaultVariableEncodingATol())
                @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 0.25

                MOI.set(model, Attributes.DefaultVariableEncodingATol(), 0.1)
                @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 0.1

                MOI.set(model, Attributes.DefaultVariableEncodingATol(), nothing)
                @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 0.25
            end
        end

        @testset "DefaultVariableEncodingBits" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, Attributes.DefaultVariableEncodingBits())
                @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) === nothing

                MOI.set(model, Attributes.DefaultVariableEncodingBits(), 5)
                @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) == 5

                MOI.set(model, Attributes.DefaultVariableEncodingBits(), nothing)
                @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) === nothing
            end
        end

        @testset "VariableEncodingMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)

                @test MOI.supports(model, Attributes.VariableEncodingMethod(), VI)
                @test MOI.get(model, Attributes.VariableEncodingMethod(), vi) === nothing
                @test Attributes.variable_encoding_method(model, vi) isa Encoding.Binary  # Falls back to default

                MOI.set(model, Attributes.VariableEncodingMethod(), vi, Encoding.OneHot())
                @test MOI.get(model, Attributes.VariableEncodingMethod(), vi) isa Encoding.OneHot
                @test Attributes.variable_encoding_method(model, vi) isa Encoding.OneHot

                MOI.set(model, Attributes.VariableEncodingMethod(), vi, nothing)
                @test MOI.get(model, Attributes.VariableEncodingMethod(), vi) === nothing
            end
        end

        @testset "VariableEncodingATol" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)

                @test MOI.supports(model, Attributes.VariableEncodingATol(), VI)
                @test MOI.get(model, Attributes.VariableEncodingATol(), vi) === nothing
                @test Attributes.variable_encoding_atol(model, vi) ≈ 0.25  # Falls back to default

                MOI.set(model, Attributes.VariableEncodingATol(), vi, 0.5)
                @test MOI.get(model, Attributes.VariableEncodingATol(), vi) ≈ 0.5
                @test Attributes.variable_encoding_atol(model, vi) ≈ 0.5

                MOI.set(model, Attributes.VariableEncodingATol(), vi, nothing)
                @test MOI.get(model, Attributes.VariableEncodingATol(), vi) === nothing
            end
        end

        @testset "VariableEncodingBits" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)

                @test MOI.supports(model, Attributes.VariableEncodingBits(), VI)
                @test Attributes.variable_encoding_bits(model, vi) === nothing  # Falls back to default

                MOI.set(model, Attributes.VariableEncodingBits(), vi, 10)
                @test MOI.get(model, Attributes.VariableEncodingBits(), vi) == 10
                @test Attributes.variable_encoding_bits(model, vi) == 10

                MOI.set(model, Attributes.VariableEncodingBits(), vi, nothing)
            end
        end

        @testset "VariableEncodingPenaltyHint" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)

                @test MOI.supports(model, Attributes.VariableEncodingPenaltyHint(), VI)
                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), vi) === nothing
                @test Attributes.variable_encoding_penalty_hint(model, vi) === nothing

                MOI.set(model, Attributes.VariableEncodingPenaltyHint(), vi, -1.0)
                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), vi) == -1.0

                MOI.set(model, Attributes.VariableEncodingPenaltyHint(), vi, nothing)
                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), vi) === nothing
            end
        end
    end

    return nothing
end

function test_constraint_attributes()
    @testset "→ Constraint Attributes" begin
        @testset "ConstraintEncodingPenaltyHint" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.ConstraintEncodingPenaltyHint(), typeof(ci))
                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), ci) === nothing
                @test Attributes.constraint_encoding_penalty_hint(model, ci) === nothing

                MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), ci, -5.0)
                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), ci) == -5.0

                MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), ci, nothing)
                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), ci) === nothing
            end
        end

        @testset "ConstraintEncodingMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.ConstraintEncodingMethod(), typeof(ci))
                @test MOI.get(model, Attributes.ConstraintEncodingMethod(), ci) === nothing
                @test Attributes.constraint_encoding_method(model, ci) isa Attributes.QuadraticPenalty

                MOI.set(
                    model,
                    Attributes.DefaultConstraintEncodingMethod(),
                    Attributes.LinearPenalty(),
                )
                @test Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty

                MOI.set(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci,
                    Attributes.QuadraticPenalty(),
                )
                @test MOI.get(
                    model,
                    Attributes.ConstraintEncodingMethod(),
                    ci,
                ) isa Attributes.QuadraticPenalty
                @test Attributes.constraint_encoding_method(model, ci) isa Attributes.QuadraticPenalty

                MOI.set(model, Attributes.ConstraintEncodingMethod(), ci, nothing)
                @test MOI.get(model, Attributes.ConstraintEncodingMethod(), ci) === nothing
                @test Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty
            end
        end

        @testset "SlackVariableEncodingMethod" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.SlackVariableEncodingMethod(), typeof(ci))
                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), ci) === nothing
                @test Attributes.slack_variable_encoding_method(model, ci) isa Encoding.Binary  # Falls back to default

                MOI.set(model, Attributes.SlackVariableEncodingMethod(), ci, Encoding.DomainWall())
                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), ci) isa Encoding.DomainWall

                MOI.set(model, Attributes.SlackVariableEncodingMethod(), ci, nothing)
                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), ci) === nothing
            end
        end

        @testset "SlackVariableEncodingATol" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.SlackVariableEncodingATol(), typeof(ci))
                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), ci) === nothing
                @test Attributes.slack_variable_encoding_atol(model, ci) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingATol(), ci, 0.1)
                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), ci) ≈ 0.1

                MOI.set(model, Attributes.SlackVariableEncodingATol(), ci, nothing)
                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), ci) === nothing
            end
        end

        @testset "SlackVariableEncodingBits" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.SlackVariableEncodingBits(), typeof(ci))
                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), ci) === nothing
                @test Attributes.slack_variable_encoding_bits(model, ci) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingBits(), ci, 8)
                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), ci) == 8

                MOI.set(model, Attributes.SlackVariableEncodingBits(), ci, nothing)
                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), ci) === nothing
            end
        end

        @testset "SlackVariableEncodingPenaltyHint" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi = MOI.add_variable(model)
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                ci = MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test MOI.supports(model, Attributes.SlackVariableEncodingPenaltyHint(), typeof(ci))
                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), ci) === nothing
                @test Attributes.slack_variable_encoding_penalty_hint(model, ci) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingPenaltyHint(), ci, -10.0)
                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), ci) == -10.0

                MOI.set(model, Attributes.SlackVariableEncodingPenaltyHint(), ci, nothing)
                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), ci) === nothing
            end
        end
    end

    return nothing
end

function test_attributes()
    @testset "□ Attributes Module" verbose = true begin
        test_compiler_attributes()
        test_encoding_attributes()
        test_constraint_attributes()
    end

    return nothing
end
