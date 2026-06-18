function _constraint_penalty_test_model(;
    scale = nothing,
    offset = nothing,
    constraint_scale = nothing,
    constraint_offset = nothing,
    hint = nothing,
    slack_encoding = nothing,
)
    model = ToQUBO.Optimizer{Float64}()
    x = [MOI.add_variable(model) for _ = 1:2]

    for xi in x
        MOI.add_constraint(model, xi, MOI.ZeroOne())
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[
                MOI.ScalarAffineTerm{Float64}(1.0, x[1]),
                MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
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
            ],
            0.0,
        ),
        MOI.LessThan{Float64}(1.0),
    )

    !isnothing(scale) && MOI.set(model, Attributes.PenaltyScale(), scale)
    !isnothing(offset) && MOI.set(model, Attributes.PenaltyOffset(), offset)
    !isnothing(constraint_scale) &&
        MOI.set(model, Attributes.ConstraintPenaltyScale(), c, constraint_scale)
    !isnothing(constraint_offset) &&
        MOI.set(model, Attributes.ConstraintPenaltyOffset(), c, constraint_offset)
    !isnothing(hint) && MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, hint)
    !isnothing(slack_encoding) &&
        MOI.set(model, Attributes.SlackVariableEncodingMethod(), c, slack_encoding)

    MOI.optimize!(model)

    return model, c
end

function _variable_penalty_test_model(; scale = nothing, offset = nothing)
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)

    MOI.add_constraint(model, x, MOI.Integer())
    MOI.add_constraint(model, x, MOI.Interval{Float64}(0.0, 3.0))
    MOI.set(model, Attributes.VariableEncodingMethod(), x, Encoding.OneHot())
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
    )

    !isnothing(scale) && MOI.set(model, Attributes.PenaltyScale(), scale)
    !isnothing(offset) && MOI.set(model, Attributes.PenaltyOffset(), offset)

    MOI.optimize!(model)

    return model, x
end

function test_compiler_penalty_defaults_match_previous_heuristic()
    default_model, default_c = _constraint_penalty_test_model()
    explicit_model, explicit_c = _constraint_penalty_test_model(; scale = 1.0, offset = 1.0)

    @test MOI.get(default_model, Attributes.ConstraintEncodingPenalty(), default_c) ==
          MOI.get(explicit_model, Attributes.ConstraintEncodingPenalty(), explicit_c)
    @test MOI.get(default_model, Attributes.CompiledHamiltonian()) ==
          MOI.get(explicit_model, Attributes.CompiledHamiltonian())

    return nothing
end

function test_compiler_penalty_scale_and_offset()
    default_model, default_c = _constraint_penalty_test_model()
    default_penalty = MOI.get(default_model, Attributes.ConstraintEncodingPenalty(), default_c)
    base_gap_ratio = abs(default_penalty) - 1.0

    scaled_model, scaled_c = _constraint_penalty_test_model(; scale = 2.0, offset = 3.0)
    @test MOI.get(scaled_model, Attributes.ConstraintEncodingPenalty(), scaled_c) ==
          -2.0 * (base_gap_ratio + 3.0)

    override_model, override_c = _constraint_penalty_test_model(;
        scale = 10.0,
        offset = 10.0,
        constraint_scale = 2.0,
        constraint_offset = 3.0,
    )
    @test MOI.get(override_model, Attributes.ConstraintEncodingPenalty(), override_c) ==
          MOI.get(scaled_model, Attributes.ConstraintEncodingPenalty(), scaled_c)

    scaled_slack_model, scaled_slack_c = _constraint_penalty_test_model(;
        scale = 2.0,
        offset = 3.0,
        slack_encoding = Encoding.OneHot(),
    )
    override_slack_model, override_slack_c = _constraint_penalty_test_model(;
        scale = 10.0,
        offset = 10.0,
        constraint_scale = 2.0,
        constraint_offset = 3.0,
        slack_encoding = Encoding.OneHot(),
    )
    @test MOI.get(
        override_slack_model,
        Attributes.SlackVariableEncodingPenalty(),
        override_slack_c,
    ) == MOI.get(scaled_slack_model, Attributes.SlackVariableEncodingPenalty(), scaled_slack_c)

    hinted_model, hinted_c = _constraint_penalty_test_model(;
        scale = 10.0,
        offset = 10.0,
        constraint_scale = 2.0,
        constraint_offset = 3.0,
        hint = -7.0,
    )
    @test MOI.get(hinted_model, Attributes.ConstraintEncodingPenalty(), hinted_c) == -7.0
    @test MOI.get(hinted_model, Attributes.AppliedPenalty(), hinted_c) == -7.0
    @test_throws MOI.SetAttributeNotAllowed MOI.set(
        hinted_model,
        Attributes.AppliedPenalty(),
        hinted_c,
        -8.0,
    )

    default_variable_model, default_x = _variable_penalty_test_model()
    scaled_variable_model, scaled_x = _variable_penalty_test_model(;
        scale = 2.0,
        offset = 3.0,
    )
    default_variable_penalty =
        MOI.get(default_variable_model, Attributes.VariableEncodingPenalty(), default_x)
    variable_gap_ratio = default_variable_penalty - 1.0
    @test MOI.get(scaled_variable_model, Attributes.VariableEncodingPenalty(), scaled_x) ==
          2.0 * (variable_gap_ratio + 3.0)

    return nothing
end

function test_compiler_applied_penalty_metadata()
    model, c = _constraint_penalty_test_model(;
        scale = 2.0,
        offset = 3.0,
        slack_encoding = Encoding.OneHot(),
    )
    penalty = MOI.get(model, Attributes.AppliedPenalty(), c)
    metadata = ToQUBO.reformulation_metadata(model)

    @test metadata["applied_penalties"]["constraints"] == [
        Dict{String,Any}(
            "constraint" => Dict{String,Any}(
                "function_type" => "MathOptInterface.ScalarAffineFunction{Float64}",
                "id" => c.value,
                "set_type" => "MathOptInterface.LessThan{Float64}",
            ),
            "penalty" => penalty,
        ),
    ]
    @test only(metadata["constraint_encodings"])["penalty"] == penalty
    @test only(metadata["applied_penalties"]["slack_variables"])["penalty"] ==
          MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c)

    return nothing
end

function test_compiler_penalties()
    @testset "Penalty heuristic" begin
        test_compiler_penalty_defaults_match_previous_heuristic()
        test_compiler_penalty_scale_and_offset()
        test_compiler_applied_penalty_metadata()
    end

    return nothing
end
