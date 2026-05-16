function test_wrapper_optimizer()
    @testset "→ Optimizer Wrapper" begin
        @testset "Construction" begin
            let model = ToQUBO.Optimizer{Float64}(nothing)
                @test model isa ToQUBO.Optimizer{Float64}
                @test MOI.is_empty(model)
            end

            let model = ToQUBO.Optimizer()
                @test model isa ToQUBO.Optimizer{Float64}
            end
        end

        @testset "is_empty and empty!" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.is_empty(model)

                # Add a variable
                vi = MOI.add_variable(model)
                @test !MOI.is_empty(model)

                MOI.empty!(model)
                @test MOI.is_empty(model)
            end
        end

        @testset "MOI supports" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
                @test MOI.supports(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}())
                @test MOI.supports_constraint(model, VI, MOI.ZeroOne)
                @test MOI.supports_add_constrained_variable(model, MOI.ZeroOne)

                for S in (MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64})
                    @test MOI.supports_constraint(model, MOI.ScalarQuadraticFunction{Float64}, S)
                end

                @test MOI.supports_constraint(model, MOI.VectorOfVariables, MOI.SOS1{Float64})

                indicator_sets = (
                    MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.EqualTo{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.LessThan{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.GreaterThan{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.Interval{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.EqualTo{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.LessThan{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.GreaterThan{Float64}},
                    MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.Interval{Float64}},
                )

                for S in indicator_sets
                    @test MOI.supports_constraint(model, MOI.VectorAffineFunction{Float64}, S)
                    @test MOI.supports_constraint(model, MOI.VectorQuadraticFunction{Float64}, S)
                end
            end
        end

        @testset "show" begin
            let model = ToQUBO.Optimizer{Float64}()
                io = IOBuffer()
                Base.show(io, model)
                output = String(take!(io))
                @test contains(output, "Virtual QUBO Model")
            end
        end

        @testset "QUBOTools backend" begin
            let model = ToQUBO.Optimizer{Float64}()
                vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

                backend = QUBOTools.backend(model)
                @test backend isa QUBOTools.Model
            end
        end

        @testset "Solver Name and Version" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.get(model, MOI.SolverName()) == "Virtual QUBO Model"
                @test MOI.get(model, MOI.SolverVersion()) == "v$(ToQUBO.__version__())"
            end
        end
    end

    return nothing
end

function test_wrapper_attributes()
    @testset "→ Wrapper Attributes" begin
        @testset "RawStatusString" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, MOI.RawStatusString())
                @test MOI.get(model, MOI.RawStatusString()) == ""

                MOI.set(model, MOI.RawStatusString(), "Test status")
                @test MOI.get(model, MOI.RawStatusString()) == "Test status"
            end
        end

        @testset "TerminationStatus (without optimizer)" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, MOI.TerminationStatus())
                # Without optimization, should return OPTIMIZE_NOT_CALLED
                @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            end
        end

        @testset "PrimalStatus and DualStatus (without optimizer)" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, MOI.PrimalStatus())
                @test MOI.supports(model, MOI.DualStatus())
                @test MOI.get(model, MOI.PrimalStatus()) == MOI.NO_SOLUTION
                @test MOI.get(model, MOI.DualStatus()) == MOI.NO_SOLUTION
            end
        end

        @testset "ResultCount (without optimizer)" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.supports(model, MOI.ResultCount())
                @test MOI.get(model, MOI.ResultCount()) == 0
            end
        end

        @testset "ObjectiveValue (without optimizer)" begin
            let model = ToQUBO.Optimizer{Float64}()
                ov = MOI.ObjectiveValue()
                @test MOI.get(model, ov) == 0.0
            end
        end

        @testset "RawSolver (without optimizer)" begin
            let model = ToQUBO.Optimizer{Float64}()
                @test MOI.get(model, MOI.RawSolver()) === nothing
            end
        end
    end

    return nothing
end

function test_wrapper()
    @testset "□ Wrapper Module" verbose = true begin
        test_wrapper_optimizer()
        test_wrapper_attributes()
    end

    return nothing
end
