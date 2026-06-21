function _target_objective_pbf(model::ToQUBO.Optimizer{T}) where {T}
    obj = MOI.get(model.target_model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}}())
    f = PBO.PBF{VI,T}()

    for q in obj.quadratic_terms
        if q.variable_1 == q.variable_2
            f[q.variable_1] += q.coefficient / 2
        else
            f[VI[q.variable_1, q.variable_2]] += q.coefficient
        end
    end

    for a in obj.affine_terms
        f[a.variable] += a.coefficient
    end

    f[nothing] += obj.constant

    return f
end

function _compiled_uses_qubo_fast_path(model::ToQUBO.Optimizer)
    return get(model.compiler_settings, :qubo_fast_path, false) === true
end

function _set_objective!(model, sense, f)
    MOI.set(model, MOI.ObjectiveSense(), sense)
    MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)

    return nothing
end

function test_compiler_copy()
    @testset "→ Copy" begin
        @testset "already-QUBO quadratic objective uses direct copy" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                obj = MOI.ScalarQuadraticFunction{Float64}(
                    [
                        MOI.ScalarQuadraticTerm(6.0, x, x),
                        MOI.ScalarQuadraticTerm(3.0, x, y),
                        MOI.ScalarQuadraticTerm(5.0, y, x),
                    ],
                    [MOI.ScalarAffineTerm(2.0, y)],
                    7.0,
                )
                _set_objective!(model, MOI.MIN_SENSE, obj)

                MOI.optimize!(model)

                x_target = only(MOI.get(model, Attributes.VariableTargetVariables(), x))
                y_target = only(MOI.get(model, Attributes.VariableTargetVariables(), y))
                expected = PBO.PBF{VI,Float64}(
                    7.0,
                    x_target => 3.0,
                    y_target => 2.0,
                    VI[x_target, y_target] => 8.0,
                )

                @test _compiled_uses_qubo_fast_path(model)
                @test MOI.get(model.target_model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
                @test MOI.get(model.target_model, MOI.NumberOfVariables()) == 2
                @test MOI.get(model.target_model, MOI.NumberOfConstraints{VI,MOI.ZeroOne}()) == 2
                @test isempty(model.g)
                @test isempty(model.h)
                @test isempty(model.s)
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == expected
                @test MOI.get(model, Attributes.CompiledHamiltonian()) == expected
                @test _target_objective_pbf(model) == expected
            end
        end

        @testset "affine and variable objectives are copied directly" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                obj = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(2.0, x),
                        MOI.ScalarAffineTerm(-1.0, y),
                    ],
                    4.0,
                )
                _set_objective!(model, MOI.MAX_SENSE, obj)

                MOI.optimize!(model)

                x_target = only(MOI.get(model, Attributes.VariableTargetVariables(), x))
                y_target = only(MOI.get(model, Attributes.VariableTargetVariables(), y))
                expected = PBO.PBF{VI,Float64}(
                    4.0,
                    x_target => 2.0,
                    y_target => -1.0,
                )

                @test _compiled_uses_qubo_fast_path(model)
                @test MOI.get(model.target_model, MOI.ObjectiveSense()) == MOI.MAX_SENSE
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == expected
                @test _target_objective_pbf(model) == expected
            end

            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                MOI.set(model, MOI.ObjectiveFunction{VI}(), x)

                MOI.optimize!(model)

                x_target = only(MOI.get(model, Attributes.VariableTargetVariables(), x))
                y_target = only(MOI.get(model, Attributes.VariableTargetVariables(), y))
                expected = PBO.PBF{VI,Float64}(x_target => 1.0)

                @test _compiled_uses_qubo_fast_path(model)
                @test MOI.get(model, Attributes.CompiledObjectiveFunction()) == expected
                @test MOI.get(model, Attributes.VariableTargetVariables(), x) == VI[x_target]
                @test MOI.get(model, Attributes.VariableTargetVariables(), y) == VI[y_target]
            end
        end

        @testset "metadata and projection stay coherent for pass-through QUBO" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                obj = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, x)],
                    0.0,
                )
                _set_objective!(model, MOI.MIN_SENSE, obj)

                MOI.optimize!(model)

                backend = QUBOTools.backend(model)
                @test backend isa QUBOTools.Model
                @test !haskey(QUBOTools.metadata(backend), "toqubo")

                full_backend = QUBOTools.backend(model; full_metadata = true)
                metadata = ToQUBO.reformulation_metadata(full_backend)

                @test metadata["source"]["variable_order"] == [x.value, y.value]
                @test metadata["target"]["num_variables"] == 2
                @test isempty(metadata["auxiliary_variables"])
                @test all(entry["role"] == "source" for entry in metadata["target_variables"])
                @test ToQUBO.original_variables(full_backend) == [x.value, y.value]

                state = [1, 0]
                live_projection = ToQUBO.project_original_state(model, state)
                backend_projection = ToQUBO.project_original_state(full_backend, state)

                @test live_projection[x] == 1.0
                @test live_projection[y] == 0.0
                @test backend_projection[x.value] == 1.0
                @test backend_projection[y.value] == 0.0
            end
        end

        @testset "NPP-style quadratic fixture selects fast path" begin
            let model = ToQUBO.Optimizer{Float64}()
                n = 6
                weights = collect(1.0:n)
                total = sum(weights)
                x = VI[]

                for _ = 1:n
                    vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                    push!(x, vi)
                end

                quadratic_terms = MOI.ScalarQuadraticTerm{Float64}[]
                affine_terms = MOI.ScalarAffineTerm{Float64}[]

                for i = 1:n
                    push!(quadratic_terms, MOI.ScalarQuadraticTerm(8 * weights[i]^2, x[i], x[i]))
                    push!(affine_terms, MOI.ScalarAffineTerm(-4 * total * weights[i], x[i]))

                    for j = (i + 1):n
                        push!(
                            quadratic_terms,
                            MOI.ScalarQuadraticTerm(8 * weights[i] * weights[j], x[i], x[j]),
                        )
                    end
                end

                obj = MOI.ScalarQuadraticFunction{Float64}(
                    quadratic_terms,
                    affine_terms,
                    total^2,
                )
                _set_objective!(model, MOI.MIN_SENSE, obj)

                MOI.optimize!(model)

                @test _compiled_uses_qubo_fast_path(model)
                @test MOI.get(model.target_model, MOI.NumberOfVariables()) == n
                @test isempty(model.slack)
                @test isempty(ToQUBO.auxiliary_variables(model))
                @test QUBOTools.backend(model) isa QUBOTools.Model
            end
        end

        @testset "constrained models use normal reformulation path" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                constraint = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(1.0, x),
                        MOI.ScalarAffineTerm(1.0, y),
                    ],
                    0.0,
                )
                MOI.add_constraint(model, constraint, MOI.LessThan(1.0))
                _set_objective!(model, MOI.MIN_SENSE, constraint)

                MOI.optimize!(model)

                @test !ToQUBO.Compiler.is_qubo(model.source_model)
                @test !_compiled_uses_qubo_fast_path(model)
                @test !isempty(model.g)
            end
        end

        @testset "non-binary domain models use normal reformulation path" begin
            let model = ToQUBO.Optimizer{Float64}()
                x, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                y = MOI.add_variable(model)
                MOI.add_constraint(model, y, MOI.Integer())
                MOI.add_constraint(model, y, MOI.Interval(0.0, 3.0))

                obj = MOI.ScalarQuadraticFunction{Float64}(
                    [MOI.ScalarQuadraticTerm(2.0, x, y)],
                    [
                        MOI.ScalarAffineTerm(1.0, x),
                        MOI.ScalarAffineTerm(3.0, y),
                    ],
                    4.0,
                )
                _set_objective!(model, MOI.MIN_SENSE, obj)

                MOI.optimize!(model)

                x_target = only(MOI.get(model, Attributes.VariableTargetVariables(), x))
                y_targets = MOI.get(model, Attributes.VariableTargetVariables(), y)
                state = zeros(Int, MOI.get(model.target_model, MOI.NumberOfVariables()))
                state[x_target.value] = 1

                for yi in y_targets
                    state[yi.value] = 1
                end

                projected = ToQUBO.project_original_state(model, state)

                @test !ToQUBO.Compiler.is_qubo(model.source_model)
                @test !_compiled_uses_qubo_fast_path(model)
                @test MOI.get(model.target_model, MOI.NumberOfVariables()) == 3
                @test length(y_targets) == 2
                @test projected[x] == 1.0
                @test projected[y] == 3.0
                @test QUBOTools.backend(model) isa QUBOTools.Model
            end
        end
    end

    return nothing
end
