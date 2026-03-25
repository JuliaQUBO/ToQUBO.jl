function test_compiler_analysis()
    @testset "→ Analysis" begin
        @testset "is_qubo" begin
            # Create a valid QUBO model using PreQUBOModel with binary vars
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi1, ci1 = MOI.add_constrained_variable(model, MOI.ZeroOne())
                vi2, ci2 = MOI.add_constrained_variable(model, MOI.ZeroOne())

                f = MOI.ScalarQuadraticFunction{Float64}(
                    [MOI.ScalarQuadraticTerm(2.0, vi1, vi2)],
                    [MOI.ScalarAffineTerm(1.0, vi1)],
                    0.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

                @test ToQUBO.Compiler.is_qubo(model)
            end
        end

        @testset "is_quadratic" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi1, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                # Quadratic objective
                f = MOI.ScalarQuadraticFunction{Float64}(
                    [MOI.ScalarQuadraticTerm(2.0, vi1, vi2)],
                    [],
                    0.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)

                @test ToQUBO.Compiler.is_quadratic(model)
            end

            let model = ToQUBO.PreQUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                # Affine objective
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)

                @test ToQUBO.Compiler.is_quadratic(model)
            end
        end

        @testset "is_unconstrained" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                # Only binary constraints - is "unconstrained" for QUBO purposes
                @test ToQUBO.Compiler.is_unconstrained(model)
            end

            let model = ToQUBO.PreQUBOModel{Float64}()
                vi = MOI.add_variable(model)
                MOI.add_constraint(model, vi, MOI.ZeroOne())

                # Add a linear constraint - not unconstrained
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                MOI.add_constraint(model, f, MOI.LessThan{Float64}(1.0))

                @test !ToQUBO.Compiler.is_unconstrained(model)
            end
        end

        @testset "is_binary" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi1, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                @test ToQUBO.Compiler.is_binary(model)
            end

            let model = ToQUBO.PreQUBOModel{Float64}()
                vi1 = MOI.add_variable(model)
                vi2, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                f = MOI.ScalarAffineFunction{Float64}(
                    [
                        MOI.ScalarAffineTerm(1.0, vi1),
                        MOI.ScalarAffineTerm(1.0, vi2),
                    ],
                    0.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

                @test !ToQUBO.Compiler.is_binary(model)
                @test !ToQUBO.Compiler.is_qubo(model)
            end
        end

        @testset "is_optimization" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
                @test ToQUBO.Compiler.is_optimization(model)

                MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
                @test ToQUBO.Compiler.is_optimization(model)
            end

            let model = ToQUBO.PreQUBOModel{Float64}()
                MOI.set(model, MOI.ObjectiveSense(), MOI.FEASIBILITY_SENSE)
                @test !ToQUBO.Compiler.is_optimization(model)
            end
        end
    end

    return nothing
end
