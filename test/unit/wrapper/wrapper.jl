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
                @test MOI.supports_constraint(model, VI, MOI.ZeroOne)
                @test MOI.supports_add_constrained_variable(model, MOI.ZeroOne)
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
                # SolverVersion returns the module version as a Ref 
                # We just verify it doesn't throw an error
                @test_nowarn MOI.get(model, MOI.SolverVersion())
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
