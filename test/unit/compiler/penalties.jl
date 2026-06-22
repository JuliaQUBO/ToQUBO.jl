struct _UnknownPenaltyPolicy <: Attributes.AutomaticPenaltyPolicy end

function _constraint_penalty_test_model(;
    scale = nothing,
    offset = nothing,
    constraint_scale = nothing,
    constraint_offset = nothing,
    hint = nothing,
    slack_encoding = nothing,
    policy = nothing,
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
    !isnothing(policy) && MOI.set(model, Attributes.PenaltyPolicy(), policy)

    MOI.optimize!(model)

    return model, c
end

function _variable_penalty_test_model(; scale = nothing, offset = nothing, policy = nothing)
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
    !isnothing(policy) && MOI.set(model, Attributes.PenaltyPolicy(), policy)

    MOI.optimize!(model)

    return model, x
end

function _fractional_gap_penalty_test_model()
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)

    MOI.set(model, Attributes.Discretize(), false)
    MOI.add_constraint(model, x, MOI.ZeroOne())
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[MOI.ScalarAffineTerm{Float64}(1.0, x)],
            0.0,
        ),
    )

    c = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[MOI.ScalarAffineTerm{Float64}(0.5, x)],
            0.0,
        ),
        MOI.LessThan{Float64}(0.0),
    )

    MOI.optimize!(model)

    return model, c
end

function test_compiler_penalty_default_policy()
    model, c = _constraint_penalty_test_model()
    penalty = MOI.get(model, Attributes.ConstraintEncodingPenalty(), c)
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())

    @test MOI.get(model, Attributes.PenaltyPolicy()) isa Attributes.ObjectiveRangePenalty
    @test penalty == -3.0
    @test metadata["policy"] == "ObjectiveRangePenalty"
    @test metadata["objective_bounds"]["source"] == "compiled_pbf_bounds"
    @test metadata["objective_bounds"]["lower"] == 0.0
    @test metadata["objective_bounds"]["upper"] == 2.0
    @test metadata["objective_bounds"]["range"] == 2.0
    @test metadata["objective_bounds"]["finite"] === true
    @test metadata["fallback_count"] == 0
    @test isempty(metadata["fallbacks"])
    inferred = only(metadata["inferred_penalties"]["constraints"])
    @test inferred["kind"] == "constraint"
    @test inferred["id"] == c.value
    @test inferred["penalty"] == penalty
    @test inferred["epsilon"] == 1.0
    @test inferred["epsilon_source"] == "integer_valued_penalty"
    @test inferred["automatic_policy"] == "ObjectiveRangePenalty"
    @test inferred["selected_policy"] == "ObjectiveRangePenalty"

    return nothing
end

function test_compiler_legacy_penalty_policy()
    model, c = _constraint_penalty_test_model(; policy = Attributes.LegacyPenalty())
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())

    @test MOI.get(model, Attributes.PenaltyPolicy()) isa Attributes.LegacyPenalty
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == -3.0
    @test metadata["policy"] == "LegacyPenalty"
    @test metadata["fallback_count"] == 0
    @test isempty(metadata["fallbacks"])

    return nothing
end

function test_compiler_fractional_penalty_gap_metadata()
    model, c = _fractional_gap_penalty_test_model()
    penalty = MOI.get(model, Attributes.ConstraintEncodingPenalty(), c)
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    inferred = only(metadata["inferred_penalties"]["constraints"])

    @test metadata["objective_bounds"]["range"] == 1.0
    @test penalty == 4.0
    @test inferred["penalty"] == penalty
    @test inferred["epsilon"] == 0.5
    @test inferred["epsilon_source"] == "pbo_mingap"
    @test inferred["scale"] == 1.0
    @test inferred["offset"] == 1.0
    @test inferred["selected_policy"] == "ObjectiveRangePenalty"
    @test metadata["fallback_count"] == 0

    return nothing
end

function test_compiler_penalty_policy_fallback_metadata()
    model, c = _constraint_penalty_test_model(; policy = _UnknownPenaltyPolicy())
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    fallback = only(metadata["fallbacks"])
    inferred = only(metadata["inferred_penalties"]["constraints"])

    @test metadata["policy"] == "_UnknownPenaltyPolicy"
    @test metadata["fallback_count"] == 1
    @test fallback["kind"] == "constraint"
    @test fallback["id"] == c.value
    @test fallback["reason"] == "Unknown automatic penalty policy"
    @test fallback["fallback_policy"] == "LegacyPenalty"
    @test inferred["penalty"] == MOI.get(model, Attributes.ConstraintEncodingPenalty(), c)
    @test inferred["epsilon"] == 1.0
    @test inferred["epsilon_source"] == "integer_valued_penalty"
    @test inferred["selected_policy"] == "LegacyPenalty"
    @test inferred["fallback_reason"] == fallback["reason"]

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
    @test metadata["penalty_policy"]["policy"] == "ObjectiveRangePenalty"
    @test metadata["penalty_policy"]["objective_bounds"]["range"] == 2.0
    @test metadata["penalty_policy"]["fallback_count"] == 0

    return nothing
end

function test_compiler_penalties()
    @testset "Penalty inference" begin
        test_compiler_penalty_default_policy()
        test_compiler_legacy_penalty_policy()
        test_compiler_fractional_penalty_gap_metadata()
        test_compiler_penalty_policy_fallback_metadata()
        test_compiler_penalty_scale_and_offset()
        test_compiler_applied_penalty_metadata()
    end

    return nothing
end
