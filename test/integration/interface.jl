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
        test_interface_jump()
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
                    C = 1.6             # capacity

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

                    @test MOI.get.(model, MOI.VariablePrimal(), x) ≈ [0.0, 1.0, 1.0]
                end
            end
        end

        @testset "Attributes" begin
            let # Create Model
                # max x1 + x2 + x3
                # st  x1 + x2 <= 1 (c1)
                #     x2 + x3 <= 1 (c2)
                #     0 <= x1 <= 1
                #     0 <= x2 <= 1
                #     0 <= x3 <= 1

                model = MOI.instantiate(
                    () -> ToQUBO.Optimizer(RandomSampler.Optimizer);
                    with_bridge_type = Float64,
                )

                x, _ = MOI.add_constrained_variables(model, fill(MOI.Interval{Float64}(0.0, 1.0), 3))

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

                c = (
                    MOI.add_constraint(
                        model,
                        MOI.ScalarAffineFunction{Float64}(
                            MOI.ScalarAffineTerm{Float64}[
                                MOI.ScalarAffineTerm{Float64}(1.0, x[1]),
                                MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
                            ],
                            0.0,
                        ),
                        MOI.LessThan{Float64}(1.0),
                    ),
                    MOI.add_constraint(
                        model,
                        MOI.ScalarAffineFunction{Float64}(
                            MOI.ScalarAffineTerm{Float64}[
                                MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
                                MOI.ScalarAffineTerm{Float64}(1.0, x[3]),
                            ],
                            0.0,
                        ),
                        MOI.LessThan{Float64}(1.0),
                    )
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
                @test MOI.get(model, Attributes.Architecture()) isa QUBOTools.GenericArchitecture
                MOI.set(model, Attributes.Architecture(), SuperArchitecture(true))
                @test MOI.get(model, Attributes.Architecture()) isa SuperArchitecture
                @test MOI.get(model, Attributes.Architecture()).super === true

                @test MOI.get(model, Attributes.Optimization()) === 0
                MOI.set(model, Attributes.Optimization(), 3)
                @test MOI.get(model, Attributes.Optimization()) === 3

                @test MOI.get(model, Attributes.Discretize()) === false
                MOI.set(model, Attributes.Discretize(), true)
                @test MOI.get(model, Attributes.Discretize()) === true

                @test MOI.get(model, Attributes.Quadratize()) === false
                MOI.set(model, Attributes.Quadratize(), true)
                @test MOI.get(model, Attributes.Quadratize()) === true

                @test MOI.get(model, Attributes.Warnings()) === true
                MOI.set(model, Attributes.Warnings(), false)
                @test MOI.get(model, Attributes.Warnings()) === false

                @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.DEFAULT
                MOI.set(model, Attributes.QuadratizationMethod(), PBO.PTR_BG())
                @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.PTR_BG

                @test MOI.get(model, Attributes.StableQuadratization()) === false
                MOI.set(model, Attributes.StableQuadratization(), true)
                @test MOI.get(model, Attributes.StableQuadratization()) === true

                # Variable Encoding Method
                @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Binary
                MOI.set(model, Attributes.DefaultVariableEncodingMethod(), Encoding.Unary())
                @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Unary

                @test MOI.get(model, Attributes.VariableEncodingMethod(), x[1]) === nothing
                @test MOI.get(model, Attributes.VariableEncodingMethod(), x[2]) === nothing

                MOI.set(model, Attributes.VariableEncodingMethod(), x[1], Encoding.OneHot())
                MOI.set(model, Attributes.VariableEncodingMethod(), x[2], Encoding.Arithmetic())

                @test MOI.get(model, Attributes.VariableEncodingMethod(), x[1]) isa Encoding.OneHot
                @test MOI.get(model, Attributes.VariableEncodingMethod(), x[2]) isa Encoding.Arithmetic

                # Variable Encoding ATol
                @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 1 / 4
                MOI.set(model, Attributes.DefaultVariableEncodingATol(), 1E-6)
                @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 1E-6

                @test MOI.get(model, Attributes.VariableEncodingATol(), x[1]) === nothing
                @test MOI.get(model, Attributes.VariableEncodingATol(), x[2]) === nothing

                MOI.set(model, Attributes.VariableEncodingATol(), x[1], 1 / 2)
                MOI.set(model, Attributes.VariableEncodingATol(), x[2], 1 / 3)

                @test MOI.get(model, Attributes.VariableEncodingATol(), x[1]) ≈ 1 / 2
                @test MOI.get(model, Attributes.VariableEncodingATol(), x[2]) ≈ 1 / 3

                # Variable Encoding Bits
                @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) === nothing
                MOI.set(model, Attributes.DefaultVariableEncodingBits(), 3)
                @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) == 3

                @test MOI.get(model, Attributes.VariableEncodingBits(), x[1]) === nothing
                @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) === nothing

                MOI.set(model, Attributes.VariableEncodingBits(), x[1], 10)
                MOI.set(model, Attributes.VariableEncodingBits(), x[2], 20)

                @test MOI.get(model, Attributes.VariableEncodingBits(), x[1]) == 10
                @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) == 20

                # Variable Encoding Penalty
                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[1]) === nothing
                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[2]) === nothing

                MOI.set(model, Attributes.VariableEncodingPenaltyHint(), x[1], -1.0)

                @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[1]) == -1.0

                @test_throws Exception MOI.get(model, Attributes.VariableEncodingPenalty(), x[1])
                @test_throws Exception MOI.get(model, Attributes.VariableEncodingPenalty(), x[2])

                # ToQUBO Constraint Attributes
                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), c[1]) === nothing
                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), c[2]) === nothing

                MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c[1], -10.0)

                @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), c[1]) == -10.0

                @test_throws Exception MOI.get(model, Attributes.ConstraintEncodingPenalty(), c[1])
                @test_throws Exception MOI.get(model, Attributes.ConstraintEncodingPenalty(), c[2])

                # Slack Variable Attributes
                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), c[1]) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), c[2]) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingMethod(), c[1], Encoding.DomainWall())

                @test MOI.get(model, Attributes.SlackVariableEncodingMethod(), c[1]) isa Encoding.DomainWall

                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), c[1]) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), c[2]) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingATol(), c[1], 1 / 2)

                @test MOI.get(model, Attributes.SlackVariableEncodingATol(), c[1]) ≈ 1 / 2

                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), c[1]) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), c[2]) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingBits(), c[2], 1)

                @test MOI.get(model, Attributes.SlackVariableEncodingBits(), c[2]) == 1

                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), c[1]) === nothing
                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), c[2]) === nothing

                MOI.set(model, Attributes.SlackVariableEncodingPenaltyHint(), c[1], -100.0)

                @test MOI.get(model, Attributes.SlackVariableEncodingPenaltyHint(), c[1]) == -100.0

                @test_throws Exception MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c[1])
                @test_throws Exception MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c[2])

                # Call to MOI.optimize!
                MOI.optimize!(model)

                let virtual_model = model.model.optimizer
                    # MOI Attributes
                    @test MOI.get(model, MOI.ResultCount()) > 0
                    @test MOI.get(model, MOI.SolveTimeSec()) > 0.0
                    @test MOI.get(model, MOI.TerminationStatus()) isa MOI.TerminationStatusCode
                    @test MOI.get(model, MOI.RawStatusString()) isa String

                    # MOI Variable Attributes
                    @test MOI.get(model, MOI.PrimalStatus()) isa MOI.ResultStatusCode
                    @test MOI.get(model, MOI.DualStatus()) isa MOI.ResultStatusCode
                    @test 0.0 <= MOI.get(model, MOI.VariablePrimal(), x[1]) <= 1.0
                    @test 0.0 <= MOI.get(model, MOI.VariablePrimal(), x[2]) <= 1.0
                    @test 0.0 <= MOI.get(model, MOI.VariablePrimal(), x[3]) <= 1.0

                    # ToQUBO Attribtues
                    @test MOI.get(model, Attributes.Optimization()) == 3
                    @test Attributes.optimization(virtual_model) == 3

                    @test MOI.get(model, Attributes.Discretize()) === true
                    @test Attributes.discretize(virtual_model) === true

                    @test MOI.get(model, Attributes.Quadratize()) === true
                    @test Attributes.quadratize(virtual_model) === true

                    @test MOI.get(model, Attributes.Warnings()) === false
                    @test Attributes.warnings(virtual_model) === false

                    @test MOI.get(model, Attributes.Architecture()) isa SuperArchitecture
                    @test MOI.get(model, Attributes.Architecture()).super === true
                    @test Attributes.architecture(virtual_model) isa SuperArchitecture
                    @test Attributes.architecture(virtual_model).super === true
                    
                    @test MOI.get(model, Attributes.QuadratizationMethod()) isa PBO.PTR_BG
                    @test MOI.get(model, Attributes.StableQuadratization()) === true

                    @test MOI.get(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Unary
                    @test MOI.get(model, Attributes.VariableEncodingMethod(), x[1]) isa Encoding.OneHot
                    @test MOI.get(model, Attributes.VariableEncodingMethod(), x[2]) isa Encoding.Arithmetic
                    @test MOI.get(model, Attributes.VariableEncodingMethod(), x[3]) === nothing

                    @test MOI.get(model, Attributes.DefaultVariableEncodingATol()) ≈ 1E-6
                    @test MOI.get(model, Attributes.VariableEncodingATol(), x[1]) ≈ 1 / 2
                    @test MOI.get(model, Attributes.VariableEncodingATol(), x[2]) ≈ 1 / 3
                    @test MOI.get(model, Attributes.VariableEncodingATol(), x[3]) === nothing

                    @test MOI.get(model, Attributes.DefaultVariableEncodingBits()) == 3
                    @test MOI.get(model, Attributes.VariableEncodingBits(), x[1]) == 10
                    @test MOI.get(model, Attributes.VariableEncodingBits(), x[2]) == 20
                    @test MOI.get(model, Attributes.VariableEncodingBits(), x[3]) === nothing

                    @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[1]) == -1.0
                    @test Attributes.variable_encoding_penalty_hint(virtual_model, x[1]) == -1.0
                    @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[2]) === nothing
                    @test Attributes.variable_encoding_penalty_hint(virtual_model, x[2]) === nothing
                    @test MOI.get(model, Attributes.VariableEncodingPenaltyHint(), x[3]) === nothing
                    @test Attributes.variable_encoding_penalty_hint(virtual_model, x[3]) === nothing

                    @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[1]) == -1.0
                    @test Attributes.variable_encoding_penalty(virtual_model, x[1]) == -1.0
                    @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[2]) === nothing
                    @test Attributes.variable_encoding_penalty(virtual_model, x[2]) === nothing
                    @test MOI.get(model, Attributes.VariableEncodingPenalty(), x[3]) === nothing
                    @test Attributes.variable_encoding_penalty(virtual_model, x[3]) === nothing

                    @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), c[1]) == -10.0
                    @test MOI.get(model, Attributes.ConstraintEncodingPenaltyHint(), c[2]) === nothing

                    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c[1]) == -10.0
                    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c[2]) <= 0.0

                    @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c[1]) == -100.0

                    @test MOI.get(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED
                    @test Attributes.compilation_status(virtual_model) === MOI.LOCALLY_SOLVED

                    @test MOI.get(model, Attributes.CompilationTime()) > 0.0
                    @test Attributes.compilation_time(virtual_model) > 0.0
                end
            end
        end
    end

    return nothing
end

function test_interface_jump()
    @testset "JuMP" begin
        @testset "Instantiate" begin
            @testset "Compiler mode" begin
                let model = Model(ToQUBO.Optimizer)

                    @test isempty(model)
                end
            end

            @testset "Optimizer mode" begin
                let model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

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
                    C = 1.6             # capacity

                    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

                    @variable(model, x[1:n], Bin)

                    @test length(x) == length(v) == n

                    @objective(model, Max, v'x)

                    @constraint(model, w'x <= C)

                    optimize!(model)

                    @test value.(x) ≈ [0.0, 1.0, 1.0]
                end
            end
        end
        
        @testset "Attributes" begin
            let # Create Model
                # max x1 + x2 + x3
                # st  x1 + x2 <= 1 (c1)
                #     x2 + x3 <= 1 (c2)
                #     x1 ∈ {0, 1}
                #     x2 ∈ {0, 1}
                #     x3 ∈ {0, 1}
                model = Model(() -> ToQUBO.Optimizer(RandomSampler.Optimizer))

                @variable(model, x[1:3], Bin)

                @objective(model, Max, sum(x))

                @constraint(model, c[i = 1:2], x[i] + x[i + 1] <= 1)

                # MOI Attributes
                @test JuMP.num_variables(model) == 3
                
                # @test JuMP.time_limit_sec(model) === nothing
                # JuMP.set_time_limit_sec(model, 1.0)
                # @test JuMP.time_limit_sec(model) == 1.0
                
                # Solver Attributes
                @test JuMP.get_attribute(model, RandomSampler.RandomSeed()) === nothing
                JuMP.set_attribute(model, RandomSampler.RandomSeed(), 13)
                @test JuMP.get_attribute(model, RandomSampler.RandomSeed()) == 13
                
                @test JuMP.get_attribute(model, RandomSampler.NumberOfReads()) == 1_000
                JuMP.set_attribute(model, RandomSampler.NumberOfReads(), 13)
                @test JuMP.get_attribute(model, RandomSampler.NumberOfReads()) == 13

                # Raw Solver Attributes
                @test JuMP.get_attribute(model, "seed") == 13
                JuMP.set_attribute(model, "seed", 1_001)
                @test JuMP.get_attribute(model, "seed") == 1_001

                @test JuMP.get_attribute(model, "num_reads") == 13
                JuMP.set_attribute(model, "num_reads", 1_001)
                @test JuMP.get_attribute(model, "num_reads") == 1_001

                # ToQUBO Attributes
                @test JuMP.get_attribute(model, Attributes.Architecture()) isa QUBOTools.GenericArchitecture
                JuMP.set_attribute(model, Attributes.Architecture(), SuperArchitecture(true))
                @test JuMP.get_attribute(model, Attributes.Architecture()) isa SuperArchitecture
                @test JuMP.get_attribute(model, Attributes.Architecture()).super === true

                @test JuMP.get_attribute(model, Attributes.Optimization()) === 0
                JuMP.set_attribute(model, Attributes.Optimization(), 3)
                @test JuMP.get_attribute(model, Attributes.Optimization()) == 3

                @test JuMP.get_attribute(model, Attributes.Discretize()) === false
                JuMP.set_attribute(model, Attributes.Discretize(), true)
                @test JuMP.get_attribute(model, Attributes.Discretize()) === true

                @test JuMP.get_attribute(model, Attributes.Quadratize()) === false
                JuMP.set_attribute(model, Attributes.Quadratize(), true)
                @test JuMP.get_attribute(model, Attributes.Quadratize()) === true

                @test JuMP.get_attribute(model, Attributes.Warnings()) === true
                JuMP.set_attribute(model, Attributes.Warnings(), false)
                @test JuMP.get_attribute(model, Attributes.Warnings()) === false

                @test JuMP.get_attribute(model, Attributes.QuadratizationMethod()) isa PBO.DEFAULT
                JuMP.set_attribute(model, Attributes.QuadratizationMethod(), PBO.PTR_BG())
                @test JuMP.get_attribute(model, Attributes.QuadratizationMethod()) isa PBO.PTR_BG

                @test JuMP.get_attribute(model, Attributes.StableQuadratization()) === false
                JuMP.set_attribute(model, Attributes.StableQuadratization(), true)
                @test JuMP.get_attribute(model, Attributes.StableQuadratization()) === true

                # Variable Encoding Method
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Binary
                JuMP.set_attribute(model, Attributes.DefaultVariableEncodingMethod(), Encoding.Unary())
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Unary

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingMethod()) === nothing
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingMethod()) === nothing

                JuMP.set_attribute(x[1], Attributes.VariableEncodingMethod(), Encoding.Arithmetic())
                JuMP.set_attribute(x[2], Attributes.VariableEncodingMethod(), Encoding.Arithmetic())

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingMethod()) isa Encoding.Arithmetic
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingMethod()) isa Encoding.Arithmetic

                # Variable Encoding ATol
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingATol()) ≈ 1 / 4
                JuMP.set_attribute(model, Attributes.DefaultVariableEncodingATol(), 1E-6)
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingATol()) ≈ 1E-6

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingATol()) === nothing
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingATol()) === nothing

                JuMP.set_attribute(x[1], Attributes.VariableEncodingATol(), 1 / 2)
                JuMP.set_attribute(x[2], Attributes.VariableEncodingATol(), 1 / 3)

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingATol()) ≈ 1 / 2
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingATol()) ≈ 1 / 3

                # Variable Encoding Bits
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingBits()) === nothing
                JuMP.set_attribute(model, Attributes.DefaultVariableEncodingBits(), 3)
                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingBits()) == 3

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingBits()) === nothing
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingBits()) === nothing

                JuMP.set_attribute(x[1], Attributes.VariableEncodingBits(), 1)
                JuMP.set_attribute(x[2], Attributes.VariableEncodingBits(), 2)

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingBits()) == 1
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingBits()) == 2

                # Variable Encoding Penalty
                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingPenaltyHint()) === nothing
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingPenaltyHint()) === nothing

                JuMP.set_attribute(x[1], Attributes.VariableEncodingPenaltyHint(), -1.0)

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingPenaltyHint()) == -1.0

                # ToQUBO Constraint Attributes
                @test JuMP.get_attribute(c[1], Attributes.ConstraintEncodingPenaltyHint()) === nothing
                @test JuMP.get_attribute(c[2], Attributes.ConstraintEncodingPenaltyHint()) === nothing

                JuMP.set_attribute(c[1], Attributes.ConstraintEncodingPenaltyHint(), -10.0)

                @test JuMP.get_attribute(c[1], Attributes.ConstraintEncodingPenaltyHint()) == -10.0

                JuMP.optimize!(model)

                @test JuMP.get_attribute(model, Attributes.Architecture()) isa SuperArchitecture
                @test JuMP.get_attribute(model, Attributes.Architecture()).super === true

                @test JuMP.get_attribute(model, Attributes.Optimization()) === 3
                @test JuMP.get_attribute(model, Attributes.Discretize()) === true
                @test JuMP.get_attribute(model, Attributes.Quadratize()) === true
                @test JuMP.get_attribute(model, Attributes.Warnings()) === false

                @test JuMP.get_attribute(model, Attributes.QuadratizationMethod()) isa PBO.PTR_BG
                @test JuMP.get_attribute(model, Attributes.StableQuadratization()) === true

                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingMethod()) isa Encoding.Unary

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingMethod()) isa Encoding.Arithmetic
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingMethod()) isa Encoding.Arithmetic
                @test JuMP.get_attribute(x[3], Attributes.VariableEncodingMethod()) === nothing

                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingATol()) ≈ 1E-6

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingATol()) ≈ 1 / 2
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingATol()) ≈ 1 / 3
                @test JuMP.get_attribute(x[3], Attributes.VariableEncodingATol()) === nothing

                @test JuMP.get_attribute(model, Attributes.DefaultVariableEncodingBits()) == 3

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingBits()) == 1
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingBits()) == 2
                @test JuMP.get_attribute(x[3], Attributes.VariableEncodingBits()) === nothing

                @test JuMP.get_attribute(x[1], Attributes.VariableEncodingPenaltyHint()) == -1.0
                @test JuMP.get_attribute(x[2], Attributes.VariableEncodingPenaltyHint()) === nothing
                @test JuMP.get_attribute(x[3], Attributes.VariableEncodingPenaltyHint()) === nothing

                @test JuMP.get_attribute(c[1], Attributes.ConstraintEncodingPenaltyHint()) == -10.0
                @test JuMP.get_attribute(c[2], Attributes.ConstraintEncodingPenaltyHint()) === nothing

                @test JuMP.get_attribute(c[1], Attributes.ConstraintEncodingPenalty()) == -10.0
                @test JuMP.get_attribute(c[2], Attributes.ConstraintEncodingPenalty()) == -4.0
            end
        end
    end

    return nothing
end
