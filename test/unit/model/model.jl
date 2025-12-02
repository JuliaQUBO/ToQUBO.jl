function test_qubo_model()
    @testset "→ QUBOModel" begin
        @testset "Construction" begin
            let model = ToQUBO.QUBOModel{Float64}()
                @test MOI.is_empty(model)
                @test MOI.get(model, MOI.NumberOfVariables()) == 0
                @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
            end
        end

        @testset "Variable addition" begin
            let model = ToQUBO.QUBOModel{Float64}()
                # Add variable with constraint
                vi, ci = MOI.add_constrained_variable(model, MOI.ZeroOne())
                
                @test vi == VI(1)
                @test ci == MOI.ConstraintIndex{VI, MOI.ZeroOne}(1)
                @test MOI.get(model, MOI.NumberOfVariables()) == 1
                @test !MOI.is_empty(model)

                # Add another variable
                vi2 = MOI.add_variable(model)
                @test vi2 == VI(2)
                @test MOI.get(model, MOI.NumberOfVariables()) == 2
            end
        end

        @testset "Objective function" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi1, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                vi2, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                # Set scalar affine objective
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(2.0, vi1), MOI.ScalarAffineTerm(3.0, vi2)],
                    1.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)

                f_out = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}())
                @test f_out.constant == 1.0
                @test length(f_out.affine_terms) == 2

                # Set scalar quadratic objective
                q = MOI.ScalarQuadraticFunction{Float64}(
                    [MOI.ScalarQuadraticTerm(4.0, vi1, vi2)],
                    [MOI.ScalarAffineTerm(2.0, vi1)],
                    5.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(q)}(), q)

                q_out = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}())
                @test q_out.constant == 5.0
                @test length(q_out.quadratic_terms) == 1
            end
        end

        @testset "Objective sense" begin
            let model = ToQUBO.QUBOModel{Float64}()
                @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
                
                MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
                @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MAX_SENSE
            end
        end

        @testset "Variable constraints" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                
                ci = MOI.add_constraint(model, vi, MOI.ZeroOne())
                @test ci == MOI.ConstraintIndex{VI, MOI.ZeroOne}(1)

                @test MOI.get(model, MOI.ConstraintFunction(), ci) == vi
                @test MOI.get(model, MOI.ConstraintSet(), ci) == MOI.ZeroOne()
            end
        end

        @testset "List operations" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi1, ci1 = MOI.add_constrained_variable(model, MOI.ZeroOne())
                vi2, ci2 = MOI.add_constrained_variable(model, MOI.ZeroOne())

                # List of variable indices
                vis = MOI.get(model, MOI.ListOfVariableIndices())
                @test length(vis) == 2
                @test vi1 ∈ vis
                @test vi2 ∈ vis

                # List of constraint types
                ctp = MOI.get(model, MOI.ListOfConstraintTypesPresent())
                @test ctp == [(VI, MOI.ZeroOne)]

                # List of constraint indices
                cis = MOI.get(model, MOI.ListOfConstraintIndices{VI, MOI.ZeroOne}())
                @test length(cis) == 2
            end
        end

        @testset "Variable names" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                
                name = MOI.get(model, MOI.VariableName(), vi)
                @test name == "x[1]"
            end
        end

        @testset "Empty operations" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
                @test !MOI.is_empty(model)

                MOI.empty!(model)
                @test MOI.is_empty(model)
                @test MOI.get(model, MOI.NumberOfVariables()) == 0
            end
        end

        @testset "Support queries" begin
            let model = ToQUBO.QUBOModel{Float64}()
                @test MOI.supports(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}())
                @test MOI.supports_constraint(model, VI, MOI.ZeroOne)
                @test MOI.supports_add_constrained_variable(model, MOI.ZeroOne)
            end
        end

        @testset "Attribute lists" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                @test MOI.supports(model, MOI.ListOfVariableAttributesSet())
                var_attrs = MOI.get(model, MOI.ListOfVariableAttributesSet())
                @test var_attrs == MOI.AbstractVariableAttribute[]

                @test MOI.supports(model, MOI.ListOfModelAttributesSet())
                model_attrs = MOI.get(model, MOI.ListOfModelAttributesSet())
                @test length(model_attrs) == 2

                @test MOI.supports(model, MOI.ListOfConstraintAttributesSet{VI, MOI.ZeroOne}())
                constraint_attrs = MOI.get(model, MOI.ListOfConstraintAttributesSet{VI, MOI.ZeroOne}())
                @test constraint_attrs == MOI.AbstractConstraintAttribute[]
            end
        end

        @testset "VariablePrimalStart" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                @test MOI.get(model, MOI.VariablePrimalStart(), vi) === nothing
            end
        end

        @testset "ObjectiveFunctionType" begin
            let model = ToQUBO.QUBOModel{Float64}()
                @test MOI.get(model, MOI.ObjectiveFunctionType()) == MOI.ScalarQuadraticFunction{Float64}
            end
        end

        @testset "Single variable objective" begin
            let model = ToQUBO.QUBOModel{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                MOI.set(model, MOI.ObjectiveFunction{VI}(), vi)
                
                f = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}())
                @test f.constant == 0.0
                @test length(f.affine_terms) == 1
                @test f.affine_terms[1].coefficient == 1.0
                @test f.affine_terms[1].variable == vi
            end
        end
    end

    return nothing
end

function test_prequbo_model()
    @testset "→ PreQUBOModel" begin
        @testset "Construction" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                @test MOI.is_empty(model)
            end
        end

        @testset "Variable addition" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi = MOI.add_variable(model)
                @test vi == VI(1)
                @test MOI.get(model, MOI.NumberOfVariables()) == 1
            end
        end

        @testset "Constraint addition" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi, ci = MOI.add_constrained_variable(model, MOI.ZeroOne())
                @test vi == VI(1)
                @test MOI.get(model, MOI.NumberOfVariables()) == 1

                # Add scalar affine constraint
                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vi)],
                    0.0
                )
                s = MOI.LessThan{Float64}(1.0)
                ci2 = MOI.add_constraint(model, f, s)
                @test ci2 isa MOI.ConstraintIndex
            end
        end

        @testset "Objective function" begin
            let model = ToQUBO.PreQUBOModel{Float64}()
                vi = MOI.add_variable(model)

                f = MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(2.0, vi)],
                    1.0
                )
                MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
                MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

                @test MOI.get(model, MOI.ObjectiveSense()) == MOI.MIN_SENSE
            end
        end
    end

    return nothing
end

function test_model()
    @testset "□ Model Module" verbose = true begin
        test_qubo_model()
        test_prequbo_model()
    end

    return nothing
end
