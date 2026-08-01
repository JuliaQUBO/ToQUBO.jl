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

function _fractional_gap_penalty_test_model(; policy = nothing)
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)

    !isnothing(policy) && MOI.set(model, Attributes.PenaltyPolicy(), policy)
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
    default_variable_metadata =
        MOI.get(default_variable_model, Attributes.PenaltyPolicyMetadata())
    variable_inferred = only(default_variable_metadata["inferred_penalties"]["variables"])
    @test variable_inferred["kind"] == "variable"
    @test variable_inferred["id"] == default_x.value
    @test variable_inferred["penalty"] == default_variable_penalty
    @test variable_inferred["epsilon"] == 1.0
    @test variable_inferred["epsilon_source"] == "integer_valued_penalty"
    @test variable_inferred["selected_policy"] == "ObjectiveRangePenalty"
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
    slack_penalty = MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c)
    metadata = ToQUBO.reformulation_metadata(model)
    penalty_metadata = metadata["penalty_policy"]

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
          slack_penalty
    @test penalty_metadata["policy"] == "ObjectiveRangePenalty"
    @test penalty_metadata["objective_bounds"]["range"] == 2.0
    @test penalty_metadata["fallback_count"] == 0
    slack_inferred = only(penalty_metadata["inferred_penalties"]["slack_variables"])
    @test slack_inferred["kind"] == "slack_variable"
    @test slack_inferred["id"] == c.value
    @test slack_inferred["penalty"] == slack_penalty
    @test slack_inferred["epsilon"] == 1.0
    @test slack_inferred["epsilon_source"] == "integer_valued_penalty"
    @test slack_inferred["selected_policy"] == "ObjectiveRangePenalty"

    return nothing
end

function test_compiler_slack_variable_encoding_penalty_is_constraint_keyed()
    model, c = _constraint_penalty_test_model(; slack_encoding = Encoding.OneHot())
    targets = MOI.get(model, Attributes.SlackVariableTargetVariables(), c)
    original_penalty = MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c)

    @test !isempty(targets)
    @test original_penalty == model.η[c]

    MOI.set(model, Attributes.SlackVariableEncodingPenalty(), c, -11.0)

    @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c) == -11.0
    @test model.η[c] == -11.0

    metadata = ToQUBO.reformulation_metadata(model)
    slack_entry = only(metadata["slack_variables"])
    applied_slack_entry = only(metadata["applied_penalties"]["slack_variables"])

    @test slack_entry["constraint"]["id"] == c.value
    @test slack_entry["target_variables"] == [vi.value for vi in targets]
    @test slack_entry["penalty"] == -11.0
    @test applied_slack_entry["constraint"] == slack_entry["constraint"]
    @test applied_slack_entry["penalty"] == -11.0

    MOI.set(model, Attributes.SlackVariableEncodingPenalty(), c, nothing)

    @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c) === nothing
    @test !haskey(model.η, c)

    cleared_metadata = ToQUBO.reformulation_metadata(model)
    cleared_slack_entry = only(cleared_metadata["slack_variables"])

    @test cleared_slack_entry["constraint"] == slack_entry["constraint"]
    @test cleared_slack_entry["target_variables"] == [vi.value for vi in targets]
    @test cleared_slack_entry["penalty"] === nothing
    @test isempty(cleared_metadata["applied_penalties"]["slack_variables"])

    return nothing
end

# MAX 3x₁ + x₂ subject to x₁ + x₂ ≤ 1 and 2x₁ + 2x₂ ≤ 3: the two constraint
# penalty functions have different one-flip structure, so the per-penalty
# policies (MOMC/MOC) must infer distinct coefficients.
function _two_constraint_heuristic_model(policy)
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
                MOI.ScalarAffineTerm{Float64}(3.0, x[1]),
                MOI.ScalarAffineTerm{Float64}(1.0, x[2]),
            ],
            0.0,
        ),
    )

    c1 = MOI.add_constraint(
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
    c2 = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[
                MOI.ScalarAffineTerm{Float64}(2.0, x[1]),
                MOI.ScalarAffineTerm{Float64}(2.0, x[2]),
            ],
            0.0,
        ),
        MOI.LessThan{Float64}(3.0),
    )

    MOI.set(model, Attributes.PenaltyPolicy(), policy)

    MOI.optimize!(model)

    return model, c1, c2
end

function test_compiler_penalty_heuristic_policies()
    # MAX x₁ + x₂ s.t. x₁ + x₂ ≤ 1: objective coefficient sum 2, maximum
    # coefficient 1, one-flip bound (VLM) 1; the slack-augmented penalty
    # (x₁ + x₂ + s - 1)² has smallest positive one-flip change γ = 1. With
    # σ = -1, scale = 1, offset = 1, ϵ = 1: ρ = -(λ + 1).
    expected = [
        (Attributes.UBPositivePenalty(), -3.0),
        (Attributes.MaxCoefficientPenalty(), -2.0),
        (Attributes.VLMPenalty(), -2.0),
        (Attributes.MOMCPenalty(), -2.0),
        (Attributes.MOCPenalty(), -2.0),
    ]

    for (policy, ρ) in expected
        model, c = _constraint_penalty_test_model(; policy)
        metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
        inferred = only(metadata["inferred_penalties"]["constraints"])
        name = string(nameof(typeof(policy)))

        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == ρ
        @test metadata["policy"] == name
        @test metadata["fallback_count"] == 0
        @test inferred["selected_policy"] == name
        @test inferred["penalty"] == ρ
    end

    return nothing
end

function test_compiler_penalty_per_constraint_heuristics()
    # Objective one-flip bound is 3 (from 3x₁). First constraint's penalty
    # has γ = 1, the second's γ = 5 (slack bits 1 and 2 over range [0, 3]),
    # so MOMC gives max(1, 3/1) = 3 and max(1, 3/5) = 1. MOC's largest
    # absolute flip ratio is 3 (x₁ decrease pair 3/1) for the first
    # constraint and 3/8 < 1 for the second.
    for policy in (Attributes.MOMCPenalty(), Attributes.MOCPenalty())
        model, c1, c2 = _two_constraint_heuristic_model(policy)
        metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())

        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c1) == -4.0
        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c2) == -2.0
        @test metadata["fallback_count"] == 0
        @test length(metadata["inferred_penalties"]["constraints"]) == 2
    end

    return nothing
end

function test_compiler_penalty_heuristic_fallbacks()
    # A negative objective coefficient invalidates the UB-positive bound; the
    # coefficient falls back to LegacyPenalty (δ = maxgap = 2, ϵ = 1, β = 1).
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
                MOI.ScalarAffineTerm{Float64}(-1.0, x[2]),
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

    MOI.set(model, Attributes.PenaltyPolicy(), Attributes.UBPositivePenalty())
    MOI.optimize!(model)

    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    fallback = only(metadata["fallbacks"])
    inferred = only(metadata["inferred_penalties"]["constraints"])

    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == -3.0
    @test fallback["reason"] == "UBPositivePenalty requires nonnegative objective coefficients"
    @test inferred["selected_policy"] == "LegacyPenalty"

    # An empty (feasibility-style) objective invalidates the global bounds:
    # MaxCoefficient and VLM fall back (δ = 0 → θ = 1), while MOC hits its
    # literature floor λ = 1 without falling back (θ = (1 + 1)/1 = 2, positive
    # since the model minimizes).
    for (policy, θ, reason) in (
        (
            Attributes.MaxCoefficientPenalty(),
            1.0,
            "MaxCoefficientPenalty requires a non-constant objective",
        ),
        (
            Attributes.VLMPenalty(),
            1.0,
            "Objective one-flip bound is not strictly positive",
        ),
        (Attributes.MOMCPenalty(), 1.0, "Objective one-flip bound is not strictly positive"),
    )
        var_model, xv = _variable_penalty_test_model(; policy)
        var_metadata = MOI.get(var_model, Attributes.PenaltyPolicyMetadata())
        var_fallback = only(var_metadata["fallbacks"])

        @test MOI.get(var_model, Attributes.VariableEncodingPenalty(), xv) == θ
        @test var_fallback["reason"] == reason
    end

    moc_model, xv = _variable_penalty_test_model(; policy = Attributes.MOCPenalty())
    moc_metadata = MOI.get(moc_model, Attributes.PenaltyPolicyMetadata())

    @test MOI.get(moc_model, Attributes.VariableEncodingPenalty(), xv) == 2.0
    @test moc_metadata["fallback_count"] == 0

    return nothing
end

function test_compiler_penalty_heuristic_slack_bucket()
    # With a one-hot slack encoding, the slack-encoding penalty χ (one-hot
    # exactly-one gadget) has smallest positive one-flip change γ = 1, and the
    # objective one-flip bound is 1, so MOMC infers η = -(1 + 1)/1 = -2.0 for
    # the slack bucket as well.
    model, c = _constraint_penalty_test_model(;
        slack_encoding = Encoding.OneHot(),
        policy = Attributes.MOMCPenalty(),
    )
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    slack_entry = only(metadata["inferred_penalties"]["slack_variables"])

    @test MOI.get(model, Attributes.SlackVariableEncodingPenalty(), c) == -2.0
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == -2.0
    @test slack_entry["selected_policy"] == "MOMCPenalty"
    @test slack_entry["penalty"] == -2.0
    @test metadata["fallback_count"] == 0

    return nothing
end

function test_compiler_penalty_heuristic_fractional_gap()
    # Same fractional model as the default-policy test (ϵ = 0.5 via
    # pbo_mingap): MaxCoefficient's bound is the single objective coefficient
    # λ = 1, so ρ = (λ + 1)/ϵ = 4.0 — locking the (λ + β)/ϵ composition on
    # the non-integer penalty path.
    model, c = _fractional_gap_penalty_test_model(;
        policy = Attributes.MaxCoefficientPenalty(),
    )
    metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    inferred = only(metadata["inferred_penalties"]["constraints"])

    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 4.0
    @test inferred["epsilon"] == 0.5
    @test inferred["epsilon_source"] == "pbo_mingap"
    @test inferred["selected_policy"] == "MaxCoefficientPenalty"
    @test metadata["fallback_count"] == 0

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
        test_compiler_slack_variable_encoding_penalty_is_constraint_keyed()
        test_compiler_penalty_heuristic_policies()
        test_compiler_penalty_per_constraint_heuristics()
        test_compiler_penalty_heuristic_fallbacks()
        test_compiler_penalty_heuristic_slack_bucket()
        test_compiler_penalty_heuristic_fractional_gap()
    end

    return nothing
end
