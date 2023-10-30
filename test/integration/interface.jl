# Assets
struct SuperArchitecture <: QUBOTools.AbstractArchitecture
    super::Bool

    function SuperArchitecture(super::Bool = false)
        return new(super)
    end
end

function test_interface()
    @testset "□ Interface" verbose = true begin
        test_interface_moi()
        # test_interface_jump()
    end

    return nothing
end

function test_interface_moi()
    @testset "MathOptInterface" begin
        @testset "Instantiate" begin
            @testset "Compiler mode" begin
                let
                    model = MOI.instantiate(
                        () -> ToQUBO.Optimizer{Float64}(nothing),
                        with_bridge_type = Float64,
                    )

                    @test MOI.is_empty(model)
                end
            end

            @testset "Optimizer mode" begin
                let
                    model = MOI.instantiate(
                        () ->
                            ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer{Float64}),
                        with_bridge_type = Float64,
                    )
                    @test MOI.is_empty(model)
                end
            end
        end

        @testset "Models" begin
            @testset "Binary Knapsack" begin
                let n = 3               # size
                    v = [1.0, 2.0, 3.0] # value
                    w = [0.3, 0.5, 1.0] # weight
                    C = 3.2             # capacity

                    model = MOI.instantiate(
                        () ->
                            ToQUBO.Optimizer{Float64}(ExactSampler.Optimizer{Float64}),
                        with_bridge_type = Float64,
                    )

                    x, _ = MOI.add_constrained_variables(model, fill(MOI.ZeroOne(), n))

                    @test length(x) == length(v) == n

                    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
                    MOI.set(
                        model,
                        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                        MOI.ScalarAffineFunction{Float64}(
                            MOI.ScalarAffineTerm{Float64}.(v, x),
                            0.0,
                        ),
                    )
                    MOI.add_constraint(
                        model,
                        MOI.ScalarAffineFunction{Float64}(
                            MOI.ScalarAffineTerm{Float64}.(w, x),
                            0.0,
                        ),
                        MOI.LessThan{Float64}(C),
                    )

                    MOI.optimize!(model)

                    @test MOI.get.(model, MOI.VariablePrimal(), x) ≈ [1.0, 1.0, 1.0]
                end
            end
        end

        @testset "Attributes" begin
            let
                # Create Model
                # max x1 + x2 + x3
                # st  x1 + x2 + x3 <= 1
                #     0 <= x1 <= 1
                #     0 <= x2 <= 1
                #     0 <= x3 <= 1
                model = MOI.instantiate(
                    () -> ToQUBO.Optimizer(RandomSampler.Optimizer);
                    with_bridge_type = Float64,
                )

                x, _ = MOI.add_constrained_variables(model, fill(MOI.ZeroOne(), 3))

                MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

                MOI.set(
                    model,
                    MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                    MOI.ScalarAffineFunction{Float64}(
                        MOI.ScalarAffineTerm{Float64}[
                            MOI.ScalarAffineTerm{Float64}(1.0, x[1]),
                            MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
                            MOI.ScalarAffineTerm{Float64}(1.0, x[3]),
                        ],
                        0.0,
                    ),
                )

                c = MOI.add_constraint(
                    model,
                    MOI.ScalarAffineFunction{Float64}(
                        MOI.ScalarAffineTerm{Float64}[
                            MOI.ScalarAffineTerm{Float64}(1.0, x[1]),
                            MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
                            MOI.ScalarAffineTerm{Float64}(1.0, x[3]),
                        ],
                        0.0,
                    ),
                    MOI.LessThan{Float64}(1.0),
                )

                # MOI Attributes
                @test MOI.get(model, MOI.NumberOfVariables()) == 3

                if MOI.supports(model, MOI.TimeLimitSec())
                    @test MOI.get(model, MOI.TimeLimitSec()) === nothing
                    MOI.set(model, MOI.TimeLimitSec(), 1.0)
                    @test MOI.get(model, MOI.TimeLimitSec()) == 1.0
                end

                # Solver Attributes
                @test MOI.get(model, RandomSampler.RandomSeed()) === nothing
                MOI.set(model, RandomSampler.RandomSeed(), 13)
                @test MOI.get(model, RandomSampler.RandomSeed()) == 13

                @test MOI.get(model, RandomSampler.NumberOfReads()) == 1_000
                MOI.set(model, RandomSampler.NumberOfReads(), 13)
                @test MOI.get(model, RandomSampler.NumberOfReads()) == 13

                # Raw Solver Attributes
                @test MOI.get(model, MOI.RawOptimizerAttribute("seed")) == 13
                MOI.set(model, MOI.RawOptimizerAttribute("seed"), 1_001)
                @test MOI.get(model, MOI.RawOptimizerAttribute("seed")) == 1_001

                @test MOI.get(model, MOI.RawOptimizerAttribute("num_reads")) == 13
                MOI.set(model, MOI.RawOptimizerAttribute("num_reads"), 1_001)
                @test MOI.get(model, MOI.RawOptimizerAttribute("num_reads")) == 1_001

                # ToQUBO Attributes
                # @test MOI.get(model, Attributes.Architecture()) isa ToQUBO.GenericArchitecture
                # MOI.set(model, Attributes.Architecture(), SuperArchitecture(true))
                # @test MOI.get(model, Attributes.Architecture()) isa SuperArchitecture
                # @test MOI.get(model, Attributes.Architecture()).super === true

                @test MOI.get(model, Attributes.Discretize()) === false
                MOI.set(model, Attributes.Discretize(), true)
                @test MOI.get(model, Attributes.Discretize()) === true

                @test MOI.get(model, Attributes.Quadratize()) === false
                MOI.set(model, Attributes.Quadratize(), true)
                @test MOI.get(model, Attributes.Quadratize()) === true

                # @test MOI.get(model, Attributes.QuadratizationMethod()) === PBO.DEFAULT
                # MOI.set(model, Attributes.QuadratizationMethod(), PBO.PTR_BG)
                # @test MOI.get(model, Attributes.QuadratizationMethod()) === PBO.PTR_BG

                # @test MOI.get(model, Attributes.StableQuadratization()) === false
                # MOI.set(model, Attributes.StableQuadratization(), true)
                # @test MOI.get(model, Attributes.StableQuadratization()) === true

                # # Variable Encoding Method
                # @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa ToQUBO.Binary
                # MOI.set(model, Attributes.DefaultVariableEncodingMethod(), ToQUBO.Unary())
                # @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa ToQUBO.Unary

                # @test MOI.get(model, Attributes.VariableEncodingMethod(), x[1]) === nothing
                # @test MOI.get(model, Attributes.VariableEncodingMethod(), x[2]) === nothing

                # MOI.set(model, Attributes.VariableEncodingMethod(), x[1], ToQUBO.Arithmetic())
                # MOI.set(model, Attributes.VariableEncodingMethod(), x[2], ToQUBO.Arithmetic())

                # @test MOI.get(model, Attributes.VariableEncodingMethod(), x[1]) isa ToQUBO.Arithmetic
                # @test MOI.get(model, Attributes.VariableEncodingMethod(), x[2]) isa ToQUBO.Arithmetic

                # # Variable Encoding ATol
                # @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 1 / 4
                # MOI.set(model, Attributes.DefaultVariableEncodingATol(), 1E-6)
                # @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 1E-6

                # @test MOI.get(model, Attributes.VariableEncodingATol(), x[1]) === nothing
                # @test MOI.get(model, Attributes.VariableEncodingATol(), x[2]) === nothing

                # MOI.set(model, Attributes.VariableEncodingATol(), x[1], 1.0)
                # MOI.set(model, Attributes.VariableEncodingATol(), x[2], 2.0)

                # @test MOI.get(model, Attributes.VariableEncodingATol(), x[1]) ≈ 1.0
                # @test MOI.get(model, Attributes.VariableEncodingATol(), x[2]) ≈ 2.0

                # # Variable Encoding Bits
                # @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) === nothing
                # MOI.set(model, Attributes.DefaultVariableEncodingBits(), 3)
                # @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) == 3

                # @test MOI.get(model, Attributes.VariableEncodingBits(), x[1]) == nothing
                # @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) == nothing

                # MOI.set(model, Attributes.VariableEncodingBits(), x[1], 1)
                # MOI.set(model, Attributes.VariableEncodingBits(), x[2], 2)

                # @test MOI.get(model, Attributes.VariableEncodingBits(), x[1]) == 1
                # @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) == 2

                # # ToQUBO Variable Attributes
                # @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[1]) === nothing
                # @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[2]) === nothing

                # MOI.set(model, Attributes.VariableEncodingPenalty(), x[1], -1.0)
                # MOI.set(model, Attributes.VariableEncodingPenalty(), x[2], -2.0)

                # @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[1]) == -1.0
                # @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[2]) == -2.0

                # # Call to MOI.optimize!
                # MOI.optimize!(model)

                # @test MOI.get(model, Attributes.VariableEncodingATol(), x[3]) ≈ 1E-6
                # @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) == 3
            end
        end
    end

    return nothing
end

function test_interface_jump()
    @testset "JuMP" begin
        @testset "Instantiate" begin
            @testset "Compiler mode" begin
                let
                    model = Model(ToQUBO.Optimizer)

                    @test isempty(model)
                end
            end

            @testset "Optimizer mode" begin
                let
                    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

                    @test isempty(model)
                end
            end
        end

        @testset "Models" begin
            @testset "Binary Knapsack" begin
                let
                    n = 3               # size
                    v = [1.0, 2.0, 3.0] # value
                    w = [0.3, 0.5, 1.0] # weight
                    C = 3.2             # capacity

                    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

                    @variable(model, x[1:n], Bin)

                    @test length(x) == length(v) == n

                    @objective(model, Max, v'x)

                    @constraint(model, w'x <= C)

                    optimize!(model)

                    @test value.(x) ≈ [1.0, 1.0, 1.0]
                end
            end
        end

        @testset "Attributes" begin
            # let
            #     model = Model(() -> ToQUBO.Optimizer(RandomSampler.Optimizer))
            # end
        end
    end

    return nothing
end
