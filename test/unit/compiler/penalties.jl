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

# MAX x₁coef·x₁ + 10x₂ + 20x₁x₂ subject to x₁ + x₂ ≤ 1: a quadratic,
# asymmetric objective that locks the higher-degree monomial crediting of the
# one-flip scan (each nonlinear monomial credits every variable it contains).
function _quadratic_heuristic_model(policy; x1_coefficient = 1.0)
    model = ToQUBO.Optimizer{Float64}()
    x = [MOI.add_variable(model) for _ = 1:2]

    for xi in x
        MOI.add_constraint(model, xi, MOI.ZeroOne())
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
        MOI.ScalarQuadraticFunction{Float64}(
            MOI.ScalarQuadraticTerm{Float64}[
                MOI.ScalarQuadraticTerm{Float64}(20.0, x[1], x[2]),
            ],
            MOI.ScalarAffineTerm{Float64}[
                MOI.ScalarAffineTerm{Float64}(x1_coefficient, x[1]),
                MOI.ScalarAffineTerm{Float64}(10.0, x[2]),
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

    MOI.set(model, Attributes.PenaltyPolicy(), policy)

    MOI.optimize!(model)

    return model, c
end

function test_compiler_penalty_heuristic_quadratic_objective()
    # Objective x₁ + 10x₂ + 20x₁x₂: coefficient sum 31, maximum coefficient
    # 20; one-flip values credit the 20x₁x₂ monomial to both variables, so
    # inc(x₁) = 21, inc(x₂) = 30 → VLM bound 30. The slack-augmented penalty
    # has γ = 1 (MOMC = max(1, 30/1) = 30) and its largest absolute flip
    # ratio is 10 (x₂ decrease pair 10/1; increase pairs 21/3 and 30/3).
    # With σ = -1, scale = 1, offset = 1, ϵ = 1: ρ = -(λ + 1).
    expected = [
        (Attributes.UBPositivePenalty(), -32.0),
        (Attributes.MaxCoefficientPenalty(), -21.0),
        (Attributes.VLMPenalty(), -31.0),
        (Attributes.MOMCPenalty(), -31.0),
        (Attributes.MOCPenalty(), -11.0),
    ]

    for (policy, ρ) in expected
        model, c = _quadratic_heuristic_model(policy)
        metadata = MOI.get(model, Attributes.PenaltyPolicyMetadata())

        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == ρ
        @test metadata["fallback_count"] == 0
    end

    # Asymmetric variant -x₁ + 10x₂ + 20x₁x₂: the negative linear term makes
    # inc(x₁) = 19 while inc(x₂) = 30 stays, so any scan that credits the
    # quadratic monomial to a single variable computes a different (wrong)
    # VLM bound; the correct one is still 30.
    model, c = _quadratic_heuristic_model(
        Attributes.VLMPenalty();
        x1_coefficient = -1.0,
    )

    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == -31.0

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

function _enumerate_compiled_hamiltonian(model::ToQUBO.Optimizer{T}) where {T}
    target_vars = collect(MOI.get(model.target_model, MOI.ListOfVariableIndices()))
    source_vars = collect(MOI.get(model.source_model, MOI.ListOfVariableIndices()))
    n = length(target_vars)
    state = Dict{VI,Int}(v => 0 for v in target_vars)
    entries = NamedTuple[]

    for mask = 0:((1 << n) - 1)
        for i = 1:n
            state[target_vars[i]] = (mask >> (i - 1)) & 1
        end

        energy = ToQUBO.Compiler._eval_pbf_rational(model.H, state)
        obj = ToQUBO.Compiler._eval_pbf_rational(model.f, state)
        zero_pen =
            all(ToQUBO.Compiler._eval_pbf_rational(g, state) == 0 for g in values(model.g)) &&
            all(ToQUBO.Compiler._eval_pbf_rational(h, state) == 0 for h in values(model.h)) &&
            all(ToQUBO.Compiler._eval_pbf_rational(s, state) == 0 for s in values(model.s))
        decoded = Tuple(
            Float64(ToQUBO.Compiler._eval_pbf_rational(ToQUBO.Virtual.expansion(model.source[vi]), state))
            for vi in source_vars
        )

        push!(
            entries,
            (;
                mask,
                state = copy(state),
                decoded,
                energy = Float64(energy),
                objective = Float64(obj),
                zero_penalty = zero_pen,
            ),
        )
    end

    return entries
end

function _build_binary_equality_fixture(;
    sense = MOI.MIN_SENSE,
    c1 = 100.0,
    c2 = 1.0,
    constant = 0.0,
    incumbent = nothing,
    policy = nothing,
    var_incumbent = nothing,
    scale = nothing,
    offset = nothing,
    hint = nothing,
)
    model = ToQUBO.Optimizer{Float64}()
    x = [MOI.add_variable(model) for _ = 1:2]

    for xi in x
        MOI.add_constraint(model, xi, MOI.ZeroOne())
    end

    MOI.set(model, MOI.ObjectiveSense(), sense)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[
                MOI.ScalarAffineTerm{Float64}(c1, x[1]),
                MOI.ScalarAffineTerm{Float64}(c2, x[2]),
            ],
            constant,
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
        MOI.EqualTo{Float64}(1.0),
    )

    !isnothing(incumbent) && MOI.set(model, Attributes.PenaltyIncumbent(), incumbent)
    !isnothing(policy) && MOI.set(model, Attributes.PenaltyPolicy(), policy)
    if !isnothing(var_incumbent)
        for (xi, val) in zip(x, var_incumbent)
            !isnothing(val) && MOI.set(model, Attributes.VariablePenaltyIncumbent(), xi, val)
        end
    end
    !isnothing(scale) && MOI.set(model, Attributes.PenaltyScale(), scale)
    !isnothing(offset) && MOI.set(model, Attributes.PenaltyOffset(), offset)
    !isnothing(hint) && MOI.set(model, Attributes.ConstraintEncodingPenaltyHint(), c, hint)

    MOI.optimize!(model)

    return model, x, c
end

function test_compiler_incumbent_penalty_exact_fixture()
    # Acceptance Criterion 1: minimize 100*x1 + x2 s.t. x1 + x2 = 1 on binary variables.
    # Without incumbent: bound span is 101, squared-equality coefficient is 102.
    base_model, _, base_c = _build_binary_equality_fixture()
    base_meta = MOI.get(base_model, Attributes.PenaltyPolicyMetadata())
    base_enum = _enumerate_compiled_hamiltonian(base_model)
    base_min_energy = minimum(e.energy for e in base_enum)
    base_minimizers = [e.decoded for e in base_enum if e.energy == base_min_energy]

    @test MOI.get(base_model, Attributes.ConstraintEncodingPenalty(), base_c) == 102.0
    @test base_meta["objective_bounds"]["source"] == "compiled_pbf_bounds"
    @test base_meta["objective_bounds"]["lower"] == 0.0
    @test base_meta["objective_bounds"]["upper"] == 101.0
    @test base_meta["objective_bounds"]["range"] == 101.0
    @test base_meta["objective_bounds"]["tightened"] === false
    @test base_meta["incumbent"]["provided"] === false
    @test base_meta["incumbent"]["status"] == "none"
    @test base_meta["sufficient_bound"]["certified"] === true
    @test base_meta["sufficient_bound"]["tightened"] === false
    @test base_minimizers == [(0.0, 1.0)]

    # With incumbent (0, 1): bound span changes from 101 to 1, coefficient is 2 instead of 102,
    # and the constrained minimizer set [(0.0, 1.0)] is preserved across all three input surfaces.
    for (kwargs, label) in (
        ((; incumbent = (0, 1)), "PenaltyIncumbent tuple"),
        ((; incumbent = [0.0, 1.0]), "PenaltyIncumbent vector"),
        ((; policy = Attributes.ObjectiveRangePenalty((0, 1))), "ObjectiveRangePenalty"),
        ((; var_incumbent = (0, 1)), "VariablePenaltyIncumbent"),
    )
        model, x, c = _build_binary_equality_fixture(; kwargs...)
        meta = MOI.get(model, Attributes.PenaltyPolicyMetadata())
        enum = _enumerate_compiled_hamiltonian(model)
        min_energy = minimum(e.energy for e in enum)
        minimizers = [e.decoded for e in enum if e.energy == min_energy]
        u_inc = meta["incumbent"]["objective"]

        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 2.0
        @test meta["objective_bounds"]["source"] == "verified_incumbent_bounds"
        @test meta["objective_bounds"]["lower"] == 0.0
        @test meta["objective_bounds"]["upper"] == 1.0
        @test meta["objective_bounds"]["whole_domain_lower"] == 0.0
        @test meta["objective_bounds"]["whole_domain_upper"] == 101.0
        @test meta["objective_bounds"]["whole_domain_range"] == 101.0
        @test meta["objective_bounds"]["range"] == 1.0
        @test meta["objective_bounds"]["tightened"] === true
        @test meta["incumbent"]["provided"] === true
        @test meta["incumbent"]["status"] == "accepted"
        @test meta["incumbent"]["valid"] === true
        @test meta["incumbent"]["source_feasible"] === true
        @test meta["incumbent"]["representable"] === true
        @test meta["incumbent"]["zero_penalty"] === true
        @test meta["incumbent"]["used"] === true
        @test meta["incumbent"]["tightened"] === true
        @test meta["incumbent"]["objective"] == 1.0
        @test meta["incumbent"]["selected_bound"] == 1.0
        @test meta["incumbent"]["selected_range"] == 1.0
        @test meta["incumbent"]["whole_domain_range"] == 101.0
        @test meta["incumbent"]["reason"] === nothing
        @test meta["sufficient_bound"]["certified"] === true
        @test meta["sufficient_bound"]["tightened"] === true
        @test meta["sufficient_bound"]["selected_range"] == 1.0
        @test only(meta["applied_penalties"]["constraints"])["sufficient_bound"] === true
        @test minimizers == base_minimizers == [(0.0, 1.0)]
        @test all(e.energy > u_inc for e in enum if !e.zero_penalty)
        @test all(e.energy == e.objective for e in enum if e.zero_penalty)

        # Also test Dict{VI,Float64} key format on the first case.
        if label == "PenaltyIncumbent tuple"
            dict_model, _, dict_c =
                _build_binary_equality_fixture(; incumbent = Dict(x[1] => 0.0, x[2] => 1.0))
            @test MOI.get(dict_model, Attributes.ConstraintEncodingPenalty(), dict_c) == 2.0
        end
    end

    return nothing
end

function test_compiler_incumbent_enumerated_variants()
    # 1. Maximization with nonzero constant:
    # Maximize 100*x1 + x2 + 7.5 s.t. x1 + x2 = 1.
    # Whole-domain bounds: L = 7.5, U = 108.5 (span 101).
    # Incumbent (1, 0) has L_inc = 107.5, so U - L_inc = 1.0 and ρ = -2.0 instead of -102.0.
    max_base, _, max_base_c = _build_binary_equality_fixture(;
        sense = MOI.MAX_SENSE,
        constant = 7.5,
    )
    max_inc, _, max_inc_c = _build_binary_equality_fixture(;
        sense = MOI.MAX_SENSE,
        constant = 7.5,
        incumbent = (1, 0),
    )
    max_meta = MOI.get(max_inc, Attributes.PenaltyPolicyMetadata())
    max_enum = _enumerate_compiled_hamiltonian(max_inc)
    # In ToQUBO, model.H for MAX_SENSE stores the sign-retained objective + negative penalties
    # (which is maximized before sense conversion to target_model).
    max_energy = maximum(e.energy for e in max_enum)
    maximizers = [e.decoded for e in max_enum if e.energy == max_energy]
    l_inc = max_meta["incumbent"]["objective"]

    @test MOI.get(max_base, Attributes.ConstraintEncodingPenalty(), max_base_c) == -102.0
    @test MOI.get(max_inc, Attributes.ConstraintEncodingPenalty(), max_inc_c) == -2.0
    @test max_meta["objective_bounds"]["sense"] == "max"
    @test max_meta["objective_bounds"]["lower"] == 107.5
    @test max_meta["objective_bounds"]["upper"] == 108.5
    @test max_meta["objective_bounds"]["whole_domain_lower"] == 7.5
    @test max_meta["objective_bounds"]["whole_domain_upper"] == 108.5
    @test max_meta["objective_bounds"]["range"] == 1.0
    @test max_meta["sufficient_bound"]["certified"] === true
    @test maximizers == [(1.0, 0.0)]
    @test all(e.energy < l_inc for e in max_enum if !e.zero_penalty)

    # 2. Minimization with nonzero constant:
    const_model, _, const_c = _build_binary_equality_fixture(;
        constant = -25.0,
        incumbent = (0, 1),
    )
    const_meta = MOI.get(const_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(const_model, Attributes.ConstraintEncodingPenalty(), const_c) == 2.0
    @test const_meta["objective_bounds"]["lower"] == -25.0
    @test const_meta["objective_bounds"]["upper"] == -24.0
    @test const_meta["objective_bounds"]["range"] == 1.0
    @test const_meta["incumbent"]["objective"] == -24.0

    # 3. Multiple penalties across constraint, variable-encoding, and slack-encoding buckets:
    # Minimize 50*x1 + x2 + 2*z s.t. x1 + x2 == 1 and x1 + z <= 1, with x1, x2 in {0, 1}
    # and z in {0, 1, 2} encoded with OneHot, and slack on x1 + z <= 1 encoded with OneHot.
    multi_model = ToQUBO.Optimizer{Float64}()
    x1 = MOI.add_variable(multi_model)
    x2 = MOI.add_variable(multi_model)
    z = MOI.add_variable(multi_model)
    MOI.add_constraint(multi_model, x1, MOI.ZeroOne())
    MOI.add_constraint(multi_model, x2, MOI.ZeroOne())
    MOI.add_constraint(multi_model, z, MOI.Integer())
    MOI.add_constraint(multi_model, z, MOI.Interval{Float64}(0.0, 2.0))
    MOI.set(multi_model, Attributes.VariableEncodingMethod(), z, Encoding.OneHot())

    MOI.set(multi_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        multi_model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [
                MOI.ScalarAffineTerm(50.0, x1),
                MOI.ScalarAffineTerm(1.0, x2),
                MOI.ScalarAffineTerm(2.0, z),
            ],
            3.0,
        ),
    )

    c_eq = MOI.add_constraint(
        multi_model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, x1), MOI.ScalarAffineTerm(1.0, x2)],
            0.0,
        ),
        MOI.EqualTo{Float64}(1.0),
    )
    c_ineq = MOI.add_constraint(
        multi_model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, x1), MOI.ScalarAffineTerm(1.0, z)],
            0.0,
        ),
        MOI.LessThan{Float64}(1.0),
    )
    MOI.set(multi_model, Attributes.SlackVariableEncodingMethod(), c_ineq, Encoding.OneHot())

    # Incumbent (x1=0, x2=1, z=1) is feasible and has objective 3 + 0 + 1 + 2 = 6.0.
    # Whole-domain lower bound is 3.0, whole-domain upper bound is 3 + 50 + 1 + 2*(1+2) = 60.0 (span 57).
    # Tightened range is 6.0 - 3.0 = 3.0, so every unit-gap penalty is 4.0 instead of 58.0.
    MOI.set(
        multi_model,
        Attributes.PenaltyIncumbent(),
        Dict(x1 => 0.0, x2 => 1.0, z => 1.0),
    )
    MOI.optimize!(multi_model)

    multi_meta = MOI.get(multi_model, Attributes.PenaltyPolicyMetadata())
    multi_enum = _enumerate_compiled_hamiltonian(multi_model)
    multi_min_energy = minimum(e.energy for e in multi_enum)
    multi_minimizers = unique([e.decoded for e in multi_enum if e.energy == multi_min_energy])

    @test multi_meta["objective_bounds"]["whole_domain_range"] == 57.0
    @test multi_meta["objective_bounds"]["range"] == 3.0
    @test MOI.get(multi_model, Attributes.ConstraintEncodingPenalty(), c_eq) == 4.0
    @test MOI.get(multi_model, Attributes.ConstraintEncodingPenalty(), c_ineq) == 4.0
    @test MOI.get(multi_model, Attributes.VariableEncodingPenalty(), z) == 4.0
    @test MOI.get(multi_model, Attributes.SlackVariableEncodingPenalty(), c_ineq) == 4.0
    @test multi_meta["sufficient_bound"]["certified"] === true
    @test multi_meta["sufficient_bound"]["tightened"] === true
    @test multi_minimizers == [(0.0, 1.0, 0.0)]
    @test all(e.energy > 6.0 for e in multi_enum if !e.zero_penalty)

    # 4. Tied threshold (offset = 0.0 => rho * epsilon == U_inc - L == 1.0):
    # At the tied threshold, infeasible (0, 0) has energy 0 + 1*(0 - 1)^2 = 1.0, tying with
    # feasible optimal (0, 1) at 1.0, and sufficient_bound["certified"] is false.
    tied_model, _, tied_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        offset = 0.0,
    )
    tied_meta = MOI.get(tied_model, Attributes.PenaltyPolicyMetadata())
    tied_enum = _enumerate_compiled_hamiltonian(tied_model)
    tied_min_energy = minimum(e.energy for e in tied_enum)
    tied_minimizers = Set(e.decoded for e in tied_enum if e.energy == tied_min_energy)

    @test MOI.get(tied_model, Attributes.ConstraintEncodingPenalty(), tied_c) == 1.0
    @test tied_minimizers == Set([(0.0, 0.0), (0.0, 1.0)])
    @test tied_meta["sufficient_bound"]["certified"] === false
    @test tied_meta["sufficient_bound"]["tightened"] === false
    @test occursin("tied threshold", tied_meta["sufficient_bound"]["reason"])
    @test only(tied_meta["applied_penalties"]["constraints"])["sufficient_bound"] === false

    # 5. Settings that invalidate the strict sufficient inequality (scale < 1, small hint,
    # wrong-sign hint, heuristic policy) while preserving explicit-hint precedence:
    sub_model, _, sub_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        scale = 0.25,
    )
    sub_meta = MOI.get(sub_model, Attributes.PenaltyPolicyMetadata())
    sub_enum = _enumerate_compiled_hamiltonian(sub_model)
    sub_min_energy = minimum(e.energy for e in sub_enum)
    sub_minimizers = [e.decoded for e in sub_enum if e.energy == sub_min_energy]

    @test MOI.get(sub_model, Attributes.ConstraintEncodingPenalty(), sub_c) == 0.5
    @test sub_minimizers == [(0.0, 0.0)]
    @test sub_meta["sufficient_bound"]["certified"] === false
    @test occursin(
        "does not satisfy the strict sufficient inequality",
        sub_meta["sufficient_bound"]["reason"],
    )

    hint_small_model, _, hint_small_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        hint = 0.5,
    )
    hint_small_meta = MOI.get(hint_small_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(hint_small_model, Attributes.ConstraintEncodingPenalty(), hint_small_c) == 0.5
    @test hint_small_meta["sufficient_bound"]["certified"] === false
    @test only(hint_small_meta["applied_penalties"]["constraints"])["source"] == "explicit_hint"

    hint_neg_model, _, hint_neg_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        hint = -2.0,
    )
    hint_neg_meta = MOI.get(hint_neg_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(hint_neg_model, Attributes.ConstraintEncodingPenalty(), hint_neg_c) == -2.0
    @test hint_neg_meta["sufficient_bound"]["certified"] === false
    @test occursin("required sign", hint_neg_meta["sufficient_bound"]["reason"])

    hint_ok_model, _, hint_ok_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        hint = 5.0,
    )
    hint_ok_meta = MOI.get(hint_ok_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(hint_ok_model, Attributes.ConstraintEncodingPenalty(), hint_ok_c) == 5.0
    @test hint_ok_meta["sufficient_bound"]["certified"] === true
    @test hint_ok_meta["sufficient_bound"]["tightened"] === true

    heur_model, _, _ = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        policy = Attributes.VLMPenalty(),
    )
    heur_meta = MOI.get(heur_model, Attributes.PenaltyPolicyMetadata())
    @test heur_meta["incumbent"]["status"] == "rejected"
    @test heur_meta["sufficient_bound"]["certified"] === false

    return nothing
end

function test_compiler_incumbent_rejections_and_fallbacks()
    # 1. Incomplete, extra/stale, scalar, conflicting, and non-finite candidates:
    for (bad_inc, expected_substr) in (
        ([0.0], "incomplete"),
        ([0.0, 1.0, 0.0], "stale or extra"),
        (Dict{VI,Float64}(), "incomplete"),
        (Dict(VI(1) => 0.0), "incomplete"),
        (Dict(VI(1) => 0.0, VI(2) => 1.0, VI(99) => 0.0), "stale or unknown"),
        (Dict("x1" => 0.0, "x2" => 1.0), "invalid or non-variable keys"),
        (1.0, "variable assignment"),
        ([NaN, 1.0], "invalid or non-finite"),
        ([Inf, 1.0], "invalid or non-finite"),
        ((0, 0), "violates source constraint"),
        ((1, 1), "violates source constraint"),
        ((0.5, 0.5), "violates source constraint"),
    )
        model, _, c = _build_binary_equality_fixture(; incumbent = bad_inc)
        meta = MOI.get(model, Attributes.PenaltyPolicyMetadata())

        @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 102.0
        @test meta["incumbent"]["provided"] === true
        @test meta["incumbent"]["status"] == "rejected"
        @test meta["incumbent"]["used"] === false
        @test meta["incumbent"]["tightened"] === false
        @test meta["incumbent"]["fallback_source"] == "compiled_pbf_bounds"
        @test occursin(expected_substr, meta["incumbent"]["reason"])
        @test meta["objective_bounds"]["range"] == 101.0
    end

    # Conflicting incumbent sources (PenaltyIncumbent vs ObjectiveRangePenalty(inc)):
    conflict_model, _, conflict_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        policy = Attributes.ObjectiveRangePenalty((1, 0)),
    )
    conflict_meta = MOI.get(conflict_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(conflict_model, Attributes.ConstraintEncodingPenalty(), conflict_c) == 102.0
    @test conflict_meta["incumbent"]["status"] == "rejected"
    @test occursin("Conflicting", conflict_meta["incumbent"]["reason"])

    # 2. Source-feasible continuous point that lies outside the chosen discretization grid:
    cont_model = ToQUBO.Optimizer{Float64}()
    x_cont = MOI.add_variable(cont_model)
    y_bin = MOI.add_variable(cont_model)
    MOI.add_constraint(cont_model, x_cont, MOI.Interval{Float64}(0.0, 1.0))
    MOI.add_constraint(cont_model, y_bin, MOI.ZeroOne())
    MOI.set(cont_model, Attributes.VariableEncodingBits(), x_cont, 1) # grid is {0.0, 1.0}
    MOI.set(cont_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        cont_model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(10.0, x_cont), MOI.ScalarAffineTerm(1.0, y_bin)],
            0.0,
        ),
    )
    c_cont = MOI.add_constraint(
        cont_model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, x_cont), MOI.ScalarAffineTerm(1.0, y_bin)],
            0.0,
        ),
        MOI.LessThan{Float64}(1.0),
    )
    # (0.5, 0.0) satisfies 0 <= x_cont <= 1 and x_cont + y_bin <= 1, but 0.5 is off the 1-bit grid.
    MOI.set(cont_model, Attributes.PenaltyIncumbent(), [0.5, 0.0])
    MOI.optimize!(cont_model)
    cont_meta = MOI.get(cont_model, Attributes.PenaltyPolicyMetadata())

    @test cont_meta["incumbent"]["status"] == "rejected"
    @test cont_meta["incumbent"]["source_feasible"] === true
    @test cont_meta["incumbent"]["representable"] === false
    @test cont_meta["incumbent"]["zero_penalty"] === false
    @test occursin("not representable", cont_meta["incumbent"]["reason"])
    @test cont_meta["objective_bounds"]["range"] == 11.0
    @test MOI.get(cont_model, Attributes.ConstraintEncodingPenalty(), c_cont) == 12.0

    # 3. Unrepresentable continuous slack under Discretize(false):
    slack_model = ToQUBO.Optimizer{Float64}()
    xs = [MOI.add_variable(slack_model) for _ = 1:2]
    for xi in xs
        MOI.add_constraint(slack_model, xi, MOI.ZeroOne())
    end
    MOI.set(slack_model, Attributes.Discretize(), false)
    MOI.set(slack_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        slack_model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(10.0, xs[1]), MOI.ScalarAffineTerm(1.0, xs[2])],
            0.0,
        ),
    )
    c_slack = MOI.add_constraint(
        slack_model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, xs[1]), MOI.ScalarAffineTerm(1.0, xs[2])],
            0.0,
        ),
        MOI.LessThan{Float64}(1.5),
    )
    # Slack range is [0, 1.5]; with 1 slack bit the slack grid is {0.0, 1.5}, so candidate
    # (0, 1) needing slack 0.5 cannot achieve zero penalty.
    MOI.set(slack_model, Attributes.SlackVariableEncodingBits(), c_slack, 1)
    MOI.set(slack_model, Attributes.PenaltyIncumbent(), (0, 1))
    MOI.optimize!(slack_model)
    slack_meta = MOI.get(slack_model, Attributes.PenaltyPolicyMetadata())

    @test slack_meta["incumbent"]["status"] == "rejected"
    @test slack_meta["incumbent"]["source_feasible"] === true
    @test slack_meta["incumbent"]["representable"] === false
    @test occursin("slack variable encoding", slack_meta["incumbent"]["reason"])

    # 4. Non-exact constraint penalty method (AugmentedLagrangianPenalty) rejects incumbent tightening:
    al_model = ToQUBO.Optimizer{Float64}()
    xa = [MOI.add_variable(al_model) for _ = 1:2]
    for xi in xa
        MOI.add_constraint(al_model, xi, MOI.ZeroOne())
    end
    MOI.set(al_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        al_model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(10.0, xa[1]), MOI.ScalarAffineTerm(1.0, xa[2])],
            0.0,
        ),
    )
    c_al = MOI.add_constraint(
        al_model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(1.0, xa[1]), MOI.ScalarAffineTerm(1.0, xa[2])],
            0.0,
        ),
        MOI.EqualTo{Float64}(1.0),
    )
    MOI.set(
        al_model,
        Attributes.ConstraintEncodingMethod(),
        c_al,
        Attributes.AugmentedLagrangianPenalty(1.0, 2.0),
    )
    MOI.set(al_model, Attributes.PenaltyIncumbent(), (0, 1))
    MOI.optimize!(al_model)
    al_meta = MOI.get(al_model, Attributes.PenaltyPolicyMetadata())

    @test al_meta["incumbent"]["status"] == "rejected"
    @test occursin("non-exact penalty method", al_meta["incumbent"]["reason"])
    @test al_meta["sufficient_bound"]["certified"] === false

    # 5. Soundness check: stored Float64 coefficient cannot establish strict inequality due to
    # floating-point precision loss (1e16 + 1.0 == 1e16 in Float64), so tightened bound is declined.
    prec_model, _, _ = _build_binary_equality_fixture(;
        c1 = 1e16,
        c2 = 1e16,
        incumbent = (1, 0),
        offset = 1.0,
    )
    prec_meta = MOI.get(prec_model, Attributes.PenaltyPolicyMetadata())
    @test prec_meta["incumbent"]["status"] == "rejected"
    @test occursin(
        "cannot establish strict sufficient inequality in target precision",
        prec_meta["incumbent"]["reason"],
    )
    @test prec_meta["objective_bounds"]["tightened"] === false

    # 6. Zero-set rounding in Float64 when squaring g^2:
    # For 100000001*x1 - 100000000*x2 = 0, (1, 1) violates the source constraint by 1,
    # but in Float64 (100000001*x1 - 100000000*x2)^2 loses the +1 in 100000001.0^2 and
    # evaluates to 0.0 at (1, 1). Incumbent tightening and sufficient_bound certification
    # must both be declined.
    zeroset_model = ToQUBO.Optimizer{Float64}()
    xz = [MOI.add_variable(zeroset_model) for _ = 1:2]
    for xi in xz
        MOI.add_constraint(zeroset_model, xi, MOI.ZeroOne())
    end
    MOI.set(zeroset_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        zeroset_model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(-100.0, xz[1]), MOI.ScalarAffineTerm(1.0, xz[2])],
            100.0,
        ),
    )
    MOI.add_constraint(
        zeroset_model,
        MOI.ScalarAffineFunction{Float64}(
            [
                MOI.ScalarAffineTerm(100000001.0, xz[1]),
                MOI.ScalarAffineTerm(-100000000.0, xz[2]),
            ],
            0.0,
        ),
        MOI.EqualTo{Float64}(0.0),
    )
    MOI.set(zeroset_model, Attributes.PenaltyIncumbent(), (0, 0))
    MOI.optimize!(zeroset_model)
    zeroset_meta = MOI.get(zeroset_model, Attributes.PenaltyPolicyMetadata())
    @test zeroset_meta["incumbent"]["status"] == "rejected"
    @test occursin("rounded in floating-point arithmetic", zeroset_meta["incumbent"]["reason"])
    @test zeroset_meta["sufficient_bound"]["certified"] === false
    @test zeroset_meta["sufficient_bound"]["tightened"] === false

    # 7. >10-variable constraint penalty rounded in Float64 when squaring g^2:
    # 7383546712*x1 - 7383546711*x2 + sum(x3:x11) = 0 loses precision in Float64 when squared,
    # making model.g take negative value -8192 at (1, 1, 0, ..., 0). Both incumbent tightening
    # and sufficient_bound certification must reject it.
    n11_bad = ToQUBO.Optimizer{Float64}()
    x11_bad = [MOI.add_variable(n11_bad) for _ = 1:11]
    for xi in x11_bad
        MOI.add_constraint(n11_bad, xi, MOI.ZeroOne())
    end
    MOI.set(n11_bad, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        n11_bad,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [
                [MOI.ScalarAffineTerm(-100.0, x11_bad[1]), MOI.ScalarAffineTerm(1.0, x11_bad[2])]
                [MOI.ScalarAffineTerm(1000.0, x11_bad[i]) for i = 3:11]
            ],
            100.0,
        ),
    )
    MOI.add_constraint(
        n11_bad,
        MOI.ScalarAffineFunction{Float64}(
            [
                [
                    MOI.ScalarAffineTerm(7383546712.0, x11_bad[1]),
                    MOI.ScalarAffineTerm(-7383546711.0, x11_bad[2]),
                ]
                [MOI.ScalarAffineTerm(1.0, x11_bad[i]) for i = 3:11]
            ],
            0.0,
        ),
        MOI.EqualTo{Float64}(0.0),
    )
    MOI.set(n11_bad, Attributes.PenaltyIncumbent(), Tuple(zeros(Int, 11)))
    MOI.optimize!(n11_bad)
    n11_bad_meta = MOI.get(n11_bad, Attributes.PenaltyPolicyMetadata())
    @test n11_bad_meta["incumbent"]["status"] == "rejected"
    @test occursin("rounded in floating-point arithmetic", n11_bad_meta["incumbent"]["reason"])
    @test n11_bad_meta["sufficient_bound"]["certified"] === false
    @test n11_bad_meta["sufficient_bound"]["tightened"] === false

    # Conversely, an exact 11-variable binary equality 2*x1 - x2 + sum(x3:x11) = 0 whose square
    # has exact Float64 coefficients is certified and tightened:
    n11_ok = ToQUBO.Optimizer{Float64}()
    x11_ok = [MOI.add_variable(n11_ok) for _ = 1:11]
    for xi in x11_ok
        MOI.add_constraint(n11_ok, xi, MOI.ZeroOne())
    end
    MOI.set(n11_ok, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        n11_ok,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [
                [MOI.ScalarAffineTerm(100.0, x11_ok[1]), MOI.ScalarAffineTerm(1.0, x11_ok[2])]
                [MOI.ScalarAffineTerm(10.0, x11_ok[i]) for i = 3:11]
            ],
            0.0,
        ),
    )
    c11_ok = MOI.add_constraint(
        n11_ok,
        MOI.ScalarAffineFunction{Float64}(
            [
                [MOI.ScalarAffineTerm(2.0, x11_ok[1]), MOI.ScalarAffineTerm(-1.0, x11_ok[2])]
                [MOI.ScalarAffineTerm(1.0, x11_ok[i]) for i = 3:11]
            ],
            0.0,
        ),
        MOI.EqualTo{Float64}(0.0),
    )
    MOI.set(n11_ok, Attributes.PenaltyIncumbent(), Tuple(zeros(Int, 11)))
    MOI.optimize!(n11_ok)
    n11_ok_meta = MOI.get(n11_ok, Attributes.PenaltyPolicyMetadata())
    @test n11_ok_meta["incumbent"]["status"] == "accepted"
    @test n11_ok_meta["sufficient_bound"]["certified"] === true
    @test n11_ok_meta["sufficient_bound"]["tightened"] === true

    # With incumbent (1, 1, 0, ..., 0) on x1 - x2 + sum(x3:x11) = 0, objective is 101 vs whole-domain 191:
    n11_tight = ToQUBO.Optimizer{Float64}()
    x11_t = [MOI.add_variable(n11_tight) for _ = 1:11]
    for xi in x11_t
        MOI.add_constraint(n11_tight, xi, MOI.ZeroOne())
    end
    MOI.set(n11_tight, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        n11_tight,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [
                [MOI.ScalarAffineTerm(100.0, x11_t[1]), MOI.ScalarAffineTerm(1.0, x11_t[2])]
                [MOI.ScalarAffineTerm(10.0, x11_t[i]) for i = 3:11]
            ],
            0.0,
        ),
    )
    c11_t = MOI.add_constraint(
        n11_tight,
        MOI.ScalarAffineFunction{Float64}(
            [
                [MOI.ScalarAffineTerm(1.0, x11_t[1]), MOI.ScalarAffineTerm(-1.0, x11_t[2])]
                [MOI.ScalarAffineTerm(1.0, x11_t[i]) for i = 3:11]
            ],
            0.0,
        ),
        MOI.EqualTo{Float64}(0.0),
    )
    inc11 = [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    MOI.set(n11_tight, Attributes.PenaltyIncumbent(), inc11)
    MOI.optimize!(n11_tight)
    n11_t_meta = MOI.get(n11_tight, Attributes.PenaltyPolicyMetadata())
    @test n11_t_meta["incumbent"]["status"] == "accepted"
    @test n11_t_meta["objective_bounds"]["range"] == 101.0
    @test MOI.get(n11_tight, Attributes.ConstraintEncodingPenalty(), c11_t) == 102.0
    @test n11_t_meta["sufficient_bound"]["certified"] === true
    @test n11_t_meta["sufficient_bound"]["tightened"] === true

    # 8. Hamiltonian assembly precision loss with huge explicit hint (1e20 absorbs objective terms
    # 100.0 and 1.0 in Float64 so (1,0) and (0,1) tie at 0.0):
    huge_hint_model, _, huge_c = _build_binary_equality_fixture(;
        incumbent = (0, 1),
        hint = 1e20,
    )
    huge_meta = MOI.get(huge_hint_model, Attributes.PenaltyPolicyMetadata())
    @test MOI.get(huge_hint_model, Attributes.ConstraintEncodingPenalty(), huge_c) == 1e20
    @test huge_meta["sufficient_bound"]["certified"] === false
    @test huge_meta["sufficient_bound"]["tightened"] === false
    @test occursin("lost precision", huge_meta["sufficient_bound"]["reason"])
    @test only(huge_meta["applied_penalties"]["constraints"])["sufficient_bound"] === false

    # 9. No-incumbent compilation preserves exact floating-point PBO.bounds(model.f) behavior:
    no_inc_float, _, c_no_inc = _build_binary_equality_fixture(;
        c1 = 1e16,
        c2 = 1.0,
        incumbent = nothing,
        offset = 1.0,
    )
    @test MOI.get(no_inc_float, Attributes.ConstraintEncodingPenalty(), c_no_inc) ==
          10000000000000000.0

    # 10. JuMP CachingOptimizer variable-keyed dictionary mapping after variable deletion:
    for use_policy_incumbent in (false, true)
        jm = JuMP.Model(ToQUBO.Optimizer)
        @variable(jm, x_del, Bin)
        @variable(jm, xj[1:2], Bin)
        delete(jm, x_del)
        @objective(jm, Min, 100.0 * xj[1] + 1.0 * xj[2])
        @constraint(jm, c_jm, xj[1] + xj[2] == 1.0)
        cand_dict = Dict(xj[1] => 0.0, xj[2] => 1.0)
        if use_policy_incumbent
            MOI.set(
                jm,
                Attributes.PenaltyPolicy(),
                Attributes.ObjectiveRangePenalty(cand_dict),
            )
        else
            MOI.set(jm, Attributes.PenaltyIncumbent(), cand_dict)
        end
        optimize!(jm)
        jm_meta = MOI.get(jm, Attributes.PenaltyPolicyMetadata())
        @test jm_meta["incumbent"]["status"] == "accepted"
        @test jm_meta["objective_bounds"]["range"] == 1.0
        @test MOI.get(jm, Attributes.ConstraintEncodingPenalty(), c_jm) == 2.0
        @test jm_meta["sufficient_bound"]["certified"] === true
        @test jm_meta["sufficient_bound"]["tightened"] === true
    end

    # Stale deleted JuMP variable in dictionary is rejected cleanly without KeyError:
    jm_stale = JuMP.Model(ToQUBO.Optimizer)
    @variable(jm_stale, x_del_s, Bin)
    @variable(jm_stale, x_s[1:2], Bin)
    stale_dict = Dict(x_del_s => 0.0, x_s[1] => 0.0, x_s[2] => 1.0)
    delete(jm_stale, x_del_s)
    @objective(jm_stale, Min, 100.0 * x_s[1] + 1.0 * x_s[2])
    @constraint(jm_stale, c_stale, x_s[1] + x_s[2] == 1.0)
    MOI.set(jm_stale, Attributes.PenaltyIncumbent(), stale_dict)
    optimize!(jm_stale)
    stale_meta = MOI.get(jm_stale, Attributes.PenaltyPolicyMetadata())
    @test stale_meta["incumbent"]["status"] == "rejected"
    @test MOI.get(jm_stale, Attributes.ConstraintEncodingPenalty(), c_stale) == 102.0

    # MOI CachingOptimizer with VI-keyed dictionary after variable deletion:
    for use_policy_incumbent in (false, true)
        cached = MOIU.CachingOptimizer(
            MOIU.UniversalFallback(MOIU.Model{Float64}()),
            ToQUBO.Optimizer{Float64}(),
        )
        v_del = MOI.add_variable(cached)
        v1 = MOI.add_variable(cached)
        v2 = MOI.add_variable(cached)
        MOI.delete(cached, v_del)
        MOI.add_constraint(cached, v1, MOI.ZeroOne())
        MOI.add_constraint(cached, v2, MOI.ZeroOne())
        MOI.set(cached, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        MOI.set(
            cached,
            MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
            MOI.ScalarAffineFunction{Float64}(
                [MOI.ScalarAffineTerm(100.0, v1), MOI.ScalarAffineTerm(1.0, v2)],
                0.0,
            ),
        )
        c_cached = MOI.add_constraint(
            cached,
            MOI.ScalarAffineFunction{Float64}(
                [MOI.ScalarAffineTerm(1.0, v1), MOI.ScalarAffineTerm(1.0, v2)],
                0.0,
            ),
            MOI.EqualTo{Float64}(1.0),
        )
        vi_dict = Dict(v1 => 0.0, v2 => 1.0)
        if use_policy_incumbent
            MOI.set(
                cached,
                Attributes.PenaltyPolicy(),
                Attributes.ObjectiveRangePenalty(vi_dict),
            )
        else
            MOI.set(cached, Attributes.PenaltyIncumbent(), vi_dict)
        end
        MOI.optimize!(cached)
        cached_meta = MOI.get(cached, Attributes.PenaltyPolicyMetadata())
        @test cached_meta["incumbent"]["status"] == "accepted"
        @test cached_meta["objective_bounds"]["range"] == 1.0
        @test MOI.get(cached, Attributes.ConstraintEncodingPenalty(), c_cached) == 2.0
    end

    return nothing
end

function test_compiler_incumbent_revalidation_after_model_edits()
    # Acceptance Criterion 4: second compilation after changing objective, constraints, or encoding
    # cannot reuse stale validation or bound values.
    model, x, c = _build_binary_equality_fixture(; incumbent = (0, 1))
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 2.0
    @test MOI.get(model, Attributes.PenaltyPolicyMetadata())["objective_bounds"]["range"] == 1.0

    # 1. Edit objective (100*x1 + 10*x2 + 5 => L = 5, U_inc = 15, range = 10, rho = 11):
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(100.0, x[1]), MOI.ScalarAffineTerm(10.0, x[2])],
            5.0,
        ),
    )
    MOI.optimize!(model)
    meta_obj = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    @test meta_obj["incumbent"]["status"] == "accepted"
    @test meta_obj["incumbent"]["objective"] == 15.0
    @test meta_obj["objective_bounds"]["lower"] == 5.0
    @test meta_obj["objective_bounds"]["upper"] == 15.0
    @test meta_obj["objective_bounds"]["range"] == 10.0
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 11.0

    # 2. Add an integer variable with VariableEncodingSet, compile with valid incumbent (0, 1, 1),
    # then restrict VariableEncodingSet so the candidate becomes unrepresentable after an encoding edit:
    z = MOI.add_variable(model)
    MOI.add_constraint(model, z, MOI.Integer())
    MOI.add_constraint(model, z, MOI.Interval{Float64}(0.0, 2.0))
    MOI.set(model, Attributes.VariableEncodingMethod(), z, Encoding.OneHot())
    MOI.set(model, Attributes.VariableEncodingSet(), z, [0.0, 1.0, 2.0])
    MOI.set(model, Attributes.PenaltyIncumbent(), (0, 1, 1))
    MOI.optimize!(model)
    @test MOI.get(model, Attributes.PenaltyPolicyMetadata())["incumbent"]["status"] == "accepted"

    MOI.set(model, Attributes.VariableEncodingSet(), z, [0.0, 2.0])
    MOI.optimize!(model)
    meta_enc = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    @test meta_enc["incumbent"]["status"] == "rejected"
    @test occursin("VariableEncodingSet", meta_enc["incumbent"]["reason"])

    # 3. Restore VariableEncodingSet, then add a constraint that makes (0, 1, 1) infeasible:
    MOI.set(model, Attributes.VariableEncodingSet(), z, [0.0, 1.0, 2.0])
    MOI.optimize!(model)
    @test MOI.get(model, Attributes.PenaltyPolicyMetadata())["incumbent"]["status"] == "accepted"

    MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}([MOI.ScalarAffineTerm(1.0, x[2])], 0.0),
        MOI.EqualTo{Float64}(0.0),
    )
    MOI.optimize!(model)
    meta_infeas = MOI.get(model, Attributes.PenaltyPolicyMetadata())
    @test meta_infeas["incumbent"]["status"] == "rejected"
    @test meta_infeas["incumbent"]["source_feasible"] === false
    @test meta_infeas["objective_bounds"]["tightened"] === false
    @test meta_infeas["objective_bounds"]["range"] == 110.0
    @test MOI.get(model, Attributes.ConstraintEncodingPenalty(), c) == 111.0

    # 4. Binary variable with extra bound constraint (x >= 1.0) not enforced by Mirror encoding:
    # must decline incumbent tightening and mark sufficient_bound uncertified.
    let jm_unenf = JuMP.Model(ToQUBO.Optimizer)
        JuMP.@variable(jm_unenf, xb >= 1.0, Bin)
        JuMP.@variable(jm_unenf, yb, Bin)
        JuMP.@variable(jm_unenf, zb, Bin)
        c_yz = JuMP.@constraint(jm_unenf, yb + zb == 1)
        JuMP.@objective(jm_unenf, Min, 1.0 * xb + 100.0 * yb + 1.0 * zb)
        MOI.set(
            jm_unenf,
            Attributes.PenaltyIncumbent(),
            Dict(xb => 1, yb => 0, zb => 1),
        )
        JuMP.optimize!(jm_unenf)
        meta_unenf = MOI.get(jm_unenf, Attributes.PenaltyPolicyMetadata())
        @test meta_unenf["incumbent"]["status"] == "rejected"
        @test meta_unenf["incumbent"]["used"] === false
        @test meta_unenf["incumbent"]["tightened"] === false
        @test meta_unenf["objective_bounds"]["tightened"] === false
        @test meta_unenf["objective_bounds"]["range"] == 102.0
        @test meta_unenf["sufficient_bound"]["certified"] === false
        @test meta_unenf["sufficient_bound"]["tightened"] === false
        @test occursin("lower bound", meta_unenf["incumbent"]["reason"])
        @test occursin("lower bound", meta_unenf["sufficient_bound"]["reason"])
        @test MOI.get(jm_unenf, Attributes.ConstraintEncodingPenalty(), c_yz) == 103.0
    end

    # 5. Cached JuMP model recompiled after variable deletion with VariableRef, VI, and integer keys:
    for use_policy in (false, true)
        let jm_recomp = JuMP.Model(ToQUBO.Optimizer)
            JuMP.@variable(jm_recomp, d_del, Bin)
            JuMP.@variable(jm_recomp, xr[1:2], Bin)
            JuMP.@objective(jm_recomp, Min, d_del + xr[1] + 10.0 * xr[2])
            c_recomp = JuMP.@constraint(jm_recomp, xr[1] + xr[2] == 1)
            inc1 = Dict(d_del => 0, xr[1] => 0, xr[2] => 1)
            if use_policy
                MOI.set(jm_recomp, Attributes.PenaltyPolicy(), Attributes.ObjectiveRangePenalty(inc1))
            else
                MOI.set(jm_recomp, Attributes.PenaltyIncumbent(), inc1)
            end
            JuMP.optimize!(jm_recomp)
            @test MOI.get(jm_recomp, Attributes.PenaltyPolicyMetadata())["incumbent"]["status"] ==
                  "accepted"

            JuMP.delete(jm_recomp, d_del)
            JuMP.@objective(jm_recomp, Min, 100.0 * xr[1] + 1.0 * xr[2])
            for inc2 in (
                Dict(xr[1] => 0, xr[2] => 1),
                Dict(VI(2) => 0, VI(3) => 1),
                Dict(2 => 0, 3 => 1),
            )
                if use_policy
                    MOI.set(
                        jm_recomp,
                        Attributes.PenaltyPolicy(),
                        Attributes.ObjectiveRangePenalty(inc2),
                    )
                else
                    MOI.set(jm_recomp, Attributes.PenaltyIncumbent(), inc2)
                end
                JuMP.optimize!(jm_recomp)
                meta_recomp = MOI.get(jm_recomp, Attributes.PenaltyPolicyMetadata())
                @test meta_recomp["incumbent"]["status"] == "accepted"
                @test meta_recomp["incumbent"]["used"] === true
                @test meta_recomp["incumbent"]["tightened"] === true
                @test meta_recomp["objective_bounds"]["range"] == 1.0
                @test MOI.get(jm_recomp, Attributes.ConstraintEncodingPenalty(), c_recomp) == 2.0
            end
        end
    end

    # 6. Pre-compilation variable deletion with integer and VI keys on JuMP and CachingOptimizer:
    for dict_cand in (Dict(2 => 0, 3 => 1), Dict(VI(2) => 0, VI(3) => 1))
        let jm_pre = JuMP.Model(ToQUBO.Optimizer)
            JuMP.@variable(jm_pre, d_pre, Bin)
            JuMP.@variable(jm_pre, xp[1:2], Bin)
            JuMP.delete(jm_pre, d_pre)
            JuMP.@objective(jm_pre, Min, 100.0 * xp[1] + 1.0 * xp[2])
            c_pre = JuMP.@constraint(jm_pre, xp[1] + xp[2] == 1)
            MOI.set(jm_pre, Attributes.PenaltyIncumbent(), dict_cand)
            JuMP.optimize!(jm_pre)
            meta_pre = MOI.get(jm_pre, Attributes.PenaltyPolicyMetadata())
            @test meta_pre["incumbent"]["status"] == "accepted"
            @test meta_pre["incumbent"]["tightened"] === true
            @test MOI.get(jm_pre, Attributes.ConstraintEncodingPenalty(), c_pre) == 2.0
        end

        let cached_int = MOIU.CachingOptimizer(
                MOIU.UniversalFallback(MOIU.Model{Float64}()),
                ToQUBO.Optimizer{Float64}(),
            )
            vc1 = MOI.add_variable(cached_int)
            vc2 = MOI.add_variable(cached_int)
            vc3 = MOI.add_variable(cached_int)
            MOI.add_constraint(cached_int, vc2, MOI.ZeroOne())
            MOI.add_constraint(cached_int, vc3, MOI.ZeroOne())
            MOI.delete(cached_int, vc1)
            c_ci = MOI.add_constraint(
                cached_int,
                MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(1.0, vc2), MOI.ScalarAffineTerm(1.0, vc3)],
                    0.0,
                ),
                MOI.EqualTo{Float64}(1.0),
            )
            MOI.set(cached_int, MOI.ObjectiveSense(), MOI.MIN_SENSE)
            MOI.set(
                cached_int,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                MOI.ScalarAffineFunction{Float64}(
                    [MOI.ScalarAffineTerm(100.0, vc2), MOI.ScalarAffineTerm(1.0, vc3)],
                    0.0,
                ),
            )
            MOI.set(cached_int, Attributes.PenaltyIncumbent(), dict_cand)
            MOI.optimize!(cached_int)
            meta_ci = MOI.get(cached_int, Attributes.PenaltyPolicyMetadata())
            @test meta_ci["incumbent"]["status"] == "accepted"
            @test meta_ci["incumbent"]["tightened"] === true
            @test MOI.get(cached_int, Attributes.ConstraintEncodingPenalty(), c_ci) == 2.0
        end
    end

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
        test_compiler_penalty_heuristic_quadratic_objective()
        test_compiler_penalty_heuristic_slack_bucket()
        test_compiler_penalty_heuristic_fractional_gap()
        test_compiler_incumbent_penalty_exact_fixture()
        test_compiler_incumbent_enumerated_variants()
        test_compiler_incumbent_rejections_and_fallbacks()
        test_compiler_incumbent_revalidation_after_model_edits()
    end

    return nothing
end
