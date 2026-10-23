function test_compiler_objective()
    @testset "→ Objective & Vector Objectives" begin
        @testset "Two-objective mixed-sense compilation and sample reporting (JuMP)" begin
            for model_sense in (MOI.MIN_SENSE, MOI.MAX_SENSE)
                model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(model, x[1:2], Bin)

                f1 = 2.0 * x[1] - 3.0 * x[2] + 1.0
                f2 = x[1] * x[2] + 4.0 * x[2] - 2.0
                if model_sense === MOI.MIN_SENSE
                    @objective(model, Min, [f1, f2])
                else
                    @objective(model, Max, [f1, f2])
                end

                set_attribute(model, Attributes.ObjectiveWeights(), [1.5, 2.5])
                set_attribute(
                    model,
                    Attributes.ObjectiveSenses(),
                    [MOI.MIN_SENSE, MOI.MAX_SENSE],
                )

                optimize!(model)

                backend = JuMP.unsafe_backend(model)
                comp_pbfs = get_attribute(model, Attributes.CompiledObjectiveFunctions())
                @test comp_pbfs == MOI.get(model, Attributes.CompiledObjectiveFunctions())
                @test comp_pbfs == MOI.get(backend, Attributes.CompiledObjectiveFunctions())
                @test length(comp_pbfs) == 2

                rel_1 = model_sense === MOI.MIN_SENSE ? 1.0 : -1.0
                rel_2 = model_sense === MOI.MAX_SENSE ? 1.0 : -1.0
                expected_scalarized = 1.5 * rel_1 * comp_pbfs[1] + 2.5 * rel_2 * comp_pbfs[2]
                @test MOI.get(backend, Attributes.CompiledObjectiveFunction()) ==
                      expected_scalarized
                @test MOI.get(backend, Attributes.CompiledHamiltonian()) ==
                      expected_scalarized

                meta = ToQUBO.reformulation_metadata(backend)
                @test length(meta["objectives"]) == 2
                @test meta["objectives"][1]["index"] == 1
                @test meta["objectives"][1]["weight"] == 1.5
                @test meta["objectives"][1]["sense"] == "min"
                @test meta["objectives"][1]["relative_sign"] == Int(rel_1)
                @test meta["objectives"][2]["index"] == 2
                @test meta["objectives"][2]["weight"] == 2.5
                @test meta["objectives"][2]["sense"] == "max"
                @test meta["objectives"][2]["relative_sign"] == Int(rel_2)

                n_res = result_count(model)
                @test n_res == 4

                for r = 1:n_res
                    x1 = value(x[1]; result = r)
                    x2 = value(x[2]; result = r)
                    expected_f1 = 2.0 * x1 - 3.0 * x2 + 1.0
                    expected_f2 = x1 * x2 + 4.0 * x2 - 2.0
                    expected_total = 1.5 * rel_1 * expected_f1 + 2.5 * rel_2 * expected_f2

                    vals = ToQUBO.source_objective_values(model; result = r)
                    @test vals ≈ [expected_f1, expected_f2]
                    @test MOI.get(model, Attributes.ObjectiveFunctionValues(r)) ≈
                          [expected_f1, expected_f2]
                    @test MOI.get(model, Attributes.SourceObjectiveValues(r)) ≈
                          [expected_f1, expected_f2]
                    @test ToQUBO.source_objective_value(model, 1; result = r) ≈ expected_f1
                    @test ToQUBO.source_objective_value(model, 2; result = r) ≈ expected_f2
                    @test MOI.get(model, Attributes.ObjectiveFunctionValue(1, r)) ≈
                          expected_f1
                    @test MOI.get(model, Attributes.ObjectiveFunctionValue(2, r)) ≈
                          expected_f2
                    @test ToQUBO.source_objective_value(model; result = r) ≈ expected_total
                    @test objective_value(model; result = r) ≈ expected_total
                end

                # Default result = 1
                @test ToQUBO.source_objective_values(model) ==
                      ToQUBO.source_objective_values(model; result = 1)
                @test ToQUBO.source_objective_value(model, 1) ==
                      ToQUBO.source_objective_value(model, 1; result = 1)
                @test Attributes.objective_function_values(backend) ==
                      MOI.get(backend, Attributes.ObjectiveFunctionValues(1))
                @test Attributes.objective_function_value(backend, 2) ==
                      MOI.get(backend, Attributes.ObjectiveFunctionValue(2, 1))

                @test_throws MOI.ResultIndexBoundsError MOI.get(
                    model,
                    Attributes.ObjectiveFunctionValues(0),
                )
                @test_throws MOI.ResultIndexBoundsError MOI.get(
                    model,
                    Attributes.ObjectiveFunctionValues(n_res + 1),
                )
                @test_throws MOI.ResultIndexBoundsError MOI.get(
                    model,
                    Attributes.ObjectiveFunctionValue(1, n_res + 1),
                )
                @test_throws BoundsError MOI.get(
                    model,
                    Attributes.ObjectiveFunctionValue(3, 1),
                )
                @test_throws BoundsError ToQUBO.source_objective_value(model, 3; result = 1)
            end
        end

        @testset "VectorOfVariables and VectorAffineFunction objectives with per-index overrides" begin
            # VectorOfVariables
            let model = ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer)
                x = [MOI.add_variable(model) for _ = 1:3]
                for xi in x
                    MOI.add_constraint(model, xi, MOI.ZeroOne())
                end

                f_vov = MOI.VectorOfVariables(x)
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{MOI.VectorOfVariables}(), f_vov)
                MOI.set(model, Attributes.ObjectiveWeight(1), 2.0)
                MOI.set(model, Attributes.ObjectiveWeight(3), -4.0)
                MOI.set(model, Attributes.ObjectiveSense(2), :max)

                MOI.optimize!(model)

                for r = 1:MOI.get(model, MOI.ResultCount())
                    xv = [MOI.get(model, MOI.VariablePrimal(r), xi) for xi in x]
                    @test MOI.get(model, Attributes.ObjectiveFunctionValues(r)) ≈ xv
                    # Component 1: +2*x1, Component 2 (max in min model): -1*x2, Component 3: -4*x3
                    expected = 2.0 * xv[1] - 1.0 * xv[2] - 4.0 * xv[3]
                    @test MOI.get(model, Attributes.SourceObjectiveValue(r)) ≈ expected
                    @test MOI.get(model, MOI.ObjectiveValue(r)) ≈ expected
                end
            end

            # VectorAffineFunction with integer variable and constraint + PenaltyIncumbent
            let model = ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer)
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                z = MOI.add_variable(model)
                MOI.add_constraint(model, z, MOI.Integer())
                MOI.add_constraint(model, z, MOI.Interval(0.0, 2.0))

                c = MOI.add_constraint(
                    model,
                    MOI.ScalarAffineFunction(
                        [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1.0, z)],
                        0.0,
                    ),
                    MOI.EqualTo(2.0),
                )

                f_vaf = MOI.VectorAffineFunction(
                    [
                        MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(3.0, x)),
                        MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, z)),
                        MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(2.0, z)),
                    ],
                    [1.0, -1.0],
                )
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{typeof(f_vaf)}(), f_vaf)
                MOI.set(model, Attributes.ObjectiveWeights(), (2.0, 0.5))
                MOI.set(model, Attributes.ObjectiveSenses(), (QUBOTools.Min, QUBOTools.Max))
                MOI.set(model, Attributes.PenaltyIncumbent(), Dict(x => 0.0, z => 2.0))

                MOI.optimize!(model)

                meta = MOI.get(model, Attributes.PenaltyPolicyMetadata())
                @test meta["incumbent"]["used"] === true
                @test meta["sufficient_bound"]["certified"] === true

                # Best feasible result should satisfy x + z == 2
                @test ToQUBO.is_feasible(model; result = 1)
                xv = MOI.get(model, MOI.VariablePrimal(1), x)
                zv = MOI.get(model, MOI.VariablePrimal(1), z)
                @test xv + zv ≈ 2.0
                f1_val = 3.0 * xv + zv + 1.0
                f2_val = 2.0 * zv - 1.0
                @test ToQUBO.source_objective_values(model; result = 1) ≈ [f1_val, f2_val]
                @test ToQUBO.source_objective_value(model; result = 1) ≈
                      2.0 * f1_val - 0.5 * f2_val
                @test MOI.get(model, MOI.ObjectiveValue(1)) ≈
                      ToQUBO.source_objective_value(model; result = 1)
            end
        end

        @testset "Scalar objective regression and custom scalarization bypasses QUBO fast path" begin
            let model = ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer)
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                f = MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(2.0, x), MOI.ScalarAffineTerm(-1.0, y)],
                    3.0,
                )
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)

                MOI.optimize!(model)
                @test get(model.compiler_settings, :qubo_fast_path, false) === true
                @test length(MOI.get(model, Attributes.CompiledObjectiveFunctions())) == 1
                @test only(MOI.get(model, Attributes.CompiledObjectiveFunctions())) ==
                      MOI.get(model, Attributes.CompiledObjectiveFunction())

                for r = 1:MOI.get(model, MOI.ResultCount())
                    val = ToQUBO.source_objective_value(model; result = r)
                    @test ToQUBO.source_objective_values(model; result = r) ≈ [val]
                    @test ToQUBO.source_objective_value(model, 1; result = r) ≈ val
                end

                # Now configure a weight and flipped sense on the scalar objective
                MOI.set(model, Attributes.ObjectiveWeights(), [2.5])
                MOI.set(model, Attributes.ObjectiveSenses(), [:max])
                MOI.optimize!(model)

                @test get(model.compiler_settings, :qubo_fast_path, false) === false
                raw_comp = only(MOI.get(model, Attributes.CompiledObjectiveFunctions()))
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) ==
                      -2.5 * raw_comp

                for r = 1:MOI.get(model, MOI.ResultCount())
                    xv = MOI.get(model, MOI.VariablePrimal(r), x)
                    yv = MOI.get(model, MOI.VariablePrimal(r), y)
                    raw_val = 2.0 * xv - yv + 3.0
                    @test ToQUBO.source_objective_values(model; result = r) ≈ [raw_val]
                    @test ToQUBO.source_objective_value(model; result = r) ≈ -2.5 * raw_val
                    @test MOI.get(model, MOI.ObjectiveValue(r)) ≈ -2.5 * raw_val
                end
            end
        end

        @testset "Validation and CompilationError on mismatched weights/senses" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                f = MOI.VectorOfVariables([x, x])
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{MOI.VectorOfVariables}(), f)

                MOI.set(model, Attributes.ObjectiveWeights(), [1.0, 2.0, 3.0])
                @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)
                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR

                MOI.set(model, Attributes.ObjectiveWeights(), nothing)
                MOI.set(model, Attributes.ObjectiveWeight(3), 1.0)
                @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)

                MOI.set(model, Attributes.ObjectiveWeight(3), nothing)
                MOI.set(model, Attributes.ObjectiveSenses(), [:min])
                @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)

                MOI.set(model, Attributes.ObjectiveSenses(), nothing)
                MOI.set(model, Attributes.ObjectiveSense(4), :max)
                @test_throws ToQUBO.Compiler.CompilationError MOI.optimize!(model)

                MOI.set(model, Attributes.ObjectiveSense(4), nothing)
                MOI.optimize!(model)
                @test MOI.get(model, Attributes.CompilationStatus()) == MOI.LOCALLY_SOLVED
            end

            # JuMP CompiledObjectiveFunctions with encoded integer variable and BigFloat cached weights
            let jm = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
                @variable(jm, 0 <= z <= 2, Int)
                @objective(jm, Min, [z, z^2])
                optimize!(jm)

                raw = MOI.get(JuMP.unsafe_backend(jm), Attributes.CompiledObjectiveFunctions())
                @test get_attribute(jm, Attributes.CompiledObjectiveFunctions()) == raw
                @test MOI.get(jm, Attributes.CompiledObjectiveFunctions()) == raw
                @test length(raw) == 2
            end

            let jm = GenericModel{BigFloat}(() -> ToQUBO.Optimizer{BigFloat}())
                @variable(jm, z, Bin)
                @objective(jm, Min, z)
                set_attribute(jm, Attributes.ObjectiveWeights(), [big"1e400"])
                optimize!(jm)
                @test MOI.get(JuMP.unsafe_backend(jm), Attributes.CompilationStatus()) ==
                      MOI.LOCALLY_SOLVED
                @test Attributes.objective_weight(JuMP.unsafe_backend(jm), 1) == big"1e400"
            end
        end
    end

    return nothing
end
