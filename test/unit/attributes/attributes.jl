function test_compiler_attributes()
    @testset "→ Compiler Attributes" begin
        @testset "SourceModel and TargetModel" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.get(model, Attributes.SourceModel()) isa ToQUBO.PreQUBOModel{Float64}
                @test MOI.get(model, Attributes.TargetModel()) isa ToQUBO.QUBOModel{Float64}
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
