# Probe sampler for the `ResultCount == 0` stop condition: returns a
# constraint-violating all-ones sample for the first `nonempty` calls and an
# empty sample set afterwards, counting invocations so the loop's solve count
# can be asserted exactly.
module RefinementProbeSampler

import QUBOTools
import QUBODrivers
import QUBODrivers: MOI, Sample, SampleSet

const CALLS = Ref(0)
const NONEMPTY = Ref(0)

QUBODrivers.@setup Optimizer begin
    name    = "Refinement Probe Sampler"
    version = v"1.0.0"
end

function reset!(; nonempty::Integer)
    CALLS[] = 0
    NONEMPTY[] = nonempty

    return nothing
end

function QUBODrivers.sample(sampler::Optimizer{T}) where {T}
    CALLS[] += 1

    n, L, Q, α, β = QUBOTools.qubo(sampler, :dict; sense = :min)

    samples = if CALLS[] <= NONEMPTY[]
        ψ = ones(Int, n)

        [Sample{T}(ψ, QUBOTools.value(ψ, L, Q, α, β))]
    else
        Sample{T,Int}[]
    end

    return SampleSet{T}(
        samples,
        Dict{String,Any}("origin" => "Refinement Probe Sampler");
        sense  = :min,
        domain = :bool,
    )
end

end

function _refinement_probe_model(; nonempty)
    RefinementProbeSampler.reset!(; nonempty)

    model = Model(() -> ToQUBO.Optimizer(RefinementProbeSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    set_attribute(model, Attributes.MaxPenaltyUpdates(), 5)

    return model, c
end

# Under-penalized fixture from the feasibility tests: with the weak hint the
# best sample sets both variables and violates the capacity constraint.
function _refinement_hinted_model(; updates = nothing)
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
    isnothing(updates) || set_attribute(model, Attributes.MaxPenaltyUpdates(), updates)

    return model, x, c
end

# Scale-driven variant: no hint, so the loop must escalate the per-constraint
# penalty scale. With scale 0.01 the inferred coefficient magnitude is
# 0.01·(6 + 1)/1 = 0.07 (objective range 6, offset 1, ϵ = 1), far below the
# objective gain of violating; 0.1 is still insufficient; 1.0 is feasible —
# so exactly two updates are required for either sense.
function _refinement_scaled_model(sense; updates = nothing)
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)

    if sense === :max
        @objective(model, Max, 3x[1] + 3x[2])
    else
        @objective(model, Min, -3x[1] - 3x[2])
    end

    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(c, Attributes.ConstraintPenaltyScale(), 0.01)
    isnothing(updates) || set_attribute(model, Attributes.MaxPenaltyUpdates(), updates)

    return model, x, c
end

function test_refinement_hinted_escalation()
    model, x, c = _refinement_hinted_model(; updates = 5)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 2
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test ToQUBO.is_feasible(model)
    @test objective_value(model) ≈ 3.0
    @test value(x[1]) + value(x[2]) ≈ 1.0

    # -0.1 → -1.0 → -10.0: the hint escalates preserving its MAX-sense sign.
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -10.0

    return nothing
end

function test_refinement_scale_escalation()
    for sense in (:max, :min)
        model, x, c = _refinement_scaled_model(sense; updates = 5)

        optimize!(model)

        backend = JuMP.unsafe_backend(model)

        @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 2
        @test primal_status(model) === MOI.FEASIBLE_POINT
        @test ToQUBO.is_feasible(model)
        @test value(x[1]) + value(x[2]) ≈ 1.0

        # 0.01 → 0.1 → 1.0: scales are sign-neutral magnitudes for both senses.
        @test MOI.get(backend, Attributes.ConstraintPenaltyScale(), JuMP.index(c)) ≈ 1.0
    end

    return nothing
end

function test_refinement_default_off()
    model, _, c = _refinement_hinted_model()

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    # Refinement is opt-in: the under-penalized solve stays infeasible and
    # the hint is untouched.
    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
    @test primal_status(model) === MOI.INFEASIBLE_POINT
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -0.1

    return nothing
end

function test_refinement_already_feasible()
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(model, Attributes.MaxPenaltyUpdates(), 5)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    # Default (certified) penalties are sufficient: no update fires.
    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test objective_value(model) ≈ 3.0

    return nothing
end

function test_refinement_budget_exhaustion()
    model, _, c = _refinement_hinted_model(; updates = 1)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    # One update (-0.1 → -1.0) is not enough: the loop stops on the budget
    # with the model still infeasible.
    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 1
    @test primal_status(model) === MOI.INFEASIBLE_POINT
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -1.0

    return nothing
end

function test_refinement_attributes()
    let model = ToQUBO.Optimizer{Float64}()
        @test MOI.supports(model, Attributes.MaxPenaltyUpdates())
        @test MOI.get(model, Attributes.MaxPenaltyUpdates()) == 0
        @test Attributes.max_penalty_updates(model) == 0

        MOI.set(model, Attributes.MaxPenaltyUpdates(), 5)
        @test MOI.get(model, Attributes.MaxPenaltyUpdates()) == 5

        MOI.set(model, Attributes.MaxPenaltyUpdates(), nothing)
        @test MOI.get(model, Attributes.MaxPenaltyUpdates()) == 0

        @test_throws ArgumentError MOI.set(model, Attributes.MaxPenaltyUpdates(), -1)

        @test MOI.supports(model, Attributes.PenaltyUpdateStrategy())
        @test MOI.get(model, Attributes.PenaltyUpdateStrategy()) isa
              Attributes.MultiplicativeUpdate
        @test MOI.get(model, Attributes.PenaltyUpdateStrategy()).factor == 10.0

        MOI.set(
            model,
            Attributes.PenaltyUpdateStrategy(),
            Attributes.MultiplicativeUpdate(2.0),
        )
        @test MOI.get(model, Attributes.PenaltyUpdateStrategy()).factor == 2.0

        MOI.set(model, Attributes.PenaltyUpdateStrategy(), nothing)
        @test MOI.get(model, Attributes.PenaltyUpdateStrategy()).factor == 10.0

        @test_throws ArgumentError Attributes.MultiplicativeUpdate(1.0)
        @test_throws ArgumentError Attributes.MultiplicativeUpdate(Inf)

        # A finite `Real` that overflows `Float64` storage must be rejected
        # by the converted value, not accepted as an infinite factor.
        @test_throws ArgumentError Attributes.MultiplicativeUpdate(big"1e400")
        @test Attributes.MultiplicativeUpdate(big"2.5").factor == 2.5

        @test MOI.get(model, Attributes.PenaltyUpdateCount()) === nothing
        @test MOI.is_set_by_optimize(Attributes.PenaltyUpdateCount())
    end

    return nothing
end

function test_refinement_zero_result_stop()
    # An empty result set on the first solve stops the loop at its
    # `ResultCount == 0` guard: no measurement, no update, no re-solve.
    model, c = _refinement_probe_model(; nonempty = 0)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test result_count(model) == 0
    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
    @test RefinementProbeSampler.CALLS[] == 1
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -0.1

    return nothing
end

function test_refinement_zero_result_mid_loop_stop()
    # The first solve violates the constraint (one update fires), the second
    # returns no results: the loop stops mid-flight instead of exhausting its
    # budget, and the escalated hint reflects exactly one update.
    model, c = _refinement_probe_model(; nonempty = 1)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test result_count(model) == 0
    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 1
    @test RefinementProbeSampler.CALLS[] == 2
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -1.0

    return nothing
end

function test_refinement_slack_escalation()
    # Scale escalation also drives the constraint's slack-encoding penalty:
    # with a one-hot slack, the final slack coefficient is the inferred
    # η = 1.0·σ·(range + offset)/ϵ = -7.0 after the scale reaches 1.0,
    # a hundredfold escalation from the initial 0.01-scaled value.
    model, x, c = _refinement_scaled_model(:max; updates = 5)

    set_attribute(c, Attributes.SlackVariableEncodingMethod(), Encoding.OneHot())

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 2
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test MOI.get(backend, Attributes.ConstraintPenaltyScale(), JuMP.index(c)) ≈ 1.0
    @test MOI.get(backend, Attributes.SlackVariableEncodingPenalty(), JuMP.index(c)) ≈
          -7.0

    return nothing
end

function test_refinement_smaller_factor()
    # A smaller factor needs more iterations: violation wins while
    # 6 - 7·scale > 3, i.e. scale < 3/7, so doubling from 0.01 first crosses
    # the threshold at 0.01·2⁶ = 0.64 — six updates.
    model, x, c = _refinement_scaled_model(:max; updates = 10)

    set_attribute(model, Attributes.PenaltyUpdateStrategy(), Attributes.MultiplicativeUpdate(2.0))

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 6
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test ToQUBO.is_feasible(model)

    return nothing
end

# MAX 3x₁ + 2x₂ subject to x₁ + x₂ ≤ 1 under AugmentedLagrangianPenalty(0, 1):
# the best sample (1,1) has H = 5 - λ - ρ and stays preferable to the feasible
# best (H = 3) while λ < 1, so with step 0.4 the multiplier path is
# 0 → 0.4 → 0.8 → 1.2 — three updates with ρ held fixed.
function _refinement_subgradient_model(; step, updates = 10)
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 2x[2])
    c = @constraint(model, x[1] + x[2] <= 1)

    set_attribute(
        c,
        Attributes.ConstraintEncodingMethod(),
        Attributes.AugmentedLagrangianPenalty(0.0, 1.0),
    )
    set_attribute(model, Attributes.MaxPenaltyUpdates(), updates)
    set_attribute(
        model,
        Attributes.PenaltyUpdateStrategy(),
        Attributes.SubgradientUpdate(; step),
    )

    return model, x, c
end

function test_refinement_subgradient_inequality()
    model, x, c = _refinement_subgradient_model(; step = 0.4)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c))

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 3
    @test method.multiplier ≈ 1.2
    @test method.rho == 1.0 # bounded ρ: the multiplier does the work
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test objective_value(model) ≈ 3.0
    @test MOI.get(backend, Attributes.ConstraintEncodingPenalty(), JuMP.index(c)) ≈ -1.0

    return nothing
end

function test_refinement_subgradient_equality()
    # Violated from above: MAX drives (1,1), residual h = +1, λ climbs by
    # η = 0.75 to 2.25 (H(1,1) = 5 - λ crosses the feasible best 3 past λ = 2).
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Max, 3x[1] + 3x[2])
    c = @constraint(model, x[1] + x[2] == 1)

    set_attribute(
        c,
        Attributes.ConstraintEncodingMethod(),
        Attributes.AugmentedLagrangianPenalty(0.0, 1.0),
    )
    set_attribute(model, Attributes.MaxPenaltyUpdates(), 10)
    set_attribute(
        model,
        Attributes.PenaltyUpdateStrategy(),
        Attributes.SubgradientUpdate(; step = 0.75),
    )

    optimize!(model)

    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c))

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 3
    @test method.multiplier ≈ 2.25
    @test method.rho == 1.0
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test objective_value(model) ≈ 3.0

    # Violated from below: MIN drives (0,0), residual h = -1, the equality
    # multiplier goes negative (-1.2 after two steps of η = 0.6).
    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, y[1:2], Bin)
    @objective(model, Min, 2y[1] + 2y[2])
    c = @constraint(model, y[1] + y[2] == 1)

    set_attribute(
        c,
        Attributes.ConstraintEncodingMethod(),
        Attributes.AugmentedLagrangianPenalty(0.0, 1.0),
    )
    set_attribute(model, Attributes.MaxPenaltyUpdates(), 10)
    set_attribute(
        model,
        Attributes.PenaltyUpdateStrategy(),
        Attributes.SubgradientUpdate(; step = 0.6),
    )

    optimize!(model)

    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c))

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 2
    @test method.multiplier ≈ -1.2
    @test primal_status(model) === MOI.FEASIBLE_POINT
    @test objective_value(model) ≈ 2.0

    return nothing
end

function test_refinement_subgradient_stall_escalation()
    # A tiny step cannot move λ meaningfully, so after `patience` (default 3)
    # non-improving iterations ρ escalates ×10 once, which resolves the model
    # on the fourth update.
    model, x, c = _refinement_subgradient_model(; step = 0.001)

    optimize!(model)

    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(c))

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 4
    @test method.rho == 10.0 # escalated exactly once
    @test primal_status(model) === MOI.FEASIBLE_POINT

    return nothing
end

function test_refinement_subgradient_requires_al()
    # Without AugmentedLagrangianPenalty constraints the strategy has nothing
    # to update: the loop breaks immediately and the model stays infeasible.
    model, _, c = _refinement_hinted_model(; updates = 5)

    set_attribute(
        model,
        Attributes.PenaltyUpdateStrategy(),
        Attributes.SubgradientUpdate(),
    )

    optimize!(model)

    backend = JuMP.unsafe_backend(model)

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
    @test primal_status(model) === MOI.INFEASIBLE_POINT
    @test MOI.get(backend, Attributes.ConstraintEncodingPenaltyHint(), JuMP.index(c)) ≈
          -0.1

    return nothing
end

function test_refinement_al_compiles_without_hint()
    for (sense, applied) in ((:max, -1.0), (:min, 1.0))
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)

        if sense === :max
            @objective(model, Max, x[1] + x[2])
        else
            @objective(model, Min, x[1] + x[2])
        end

        c = @constraint(model, x[1] + x[2] <= 1)

        set_attribute(
            c,
            Attributes.ConstraintEncodingMethod(),
            Attributes.AugmentedLagrangianPenalty(0.5, 2.0),
        )

        optimize!(model)

        backend = JuMP.unsafe_backend(model)

        # No hint required: the applied coefficient carries only the sense
        # sign; λ and ρ live in the method.
        @test MOI.get(backend, Attributes.ConstraintEncodingPenalty(), JuMP.index(c)) ==
              applied

        # AL constraints stay visible in the penalty metadata inventory.
        metadata = MOI.get(backend, Attributes.PenaltyPolicyMetadata())
        entry = only(metadata["inferred_penalties"]["constraints"])

        @test entry["selected_policy"] == "AugmentedLagrangianPenalty"
        @test entry["penalty"] == applied
        @test entry["id"] == JuMP.index(c).value
    end

    return nothing
end

function test_refinement_subgradient_unreachable_violation_break()
    # The violated constraint is quadratic (not AL-managed); an additional
    # satisfied AL constraint must not keep the loop alive, and its
    # multiplier must stay untouched.
    model, x, c = _refinement_hinted_model(; updates = 5)

    al = @constraint(model, x[1] + x[2] >= 0)

    set_attribute(
        al,
        Attributes.ConstraintEncodingMethod(),
        Attributes.AugmentedLagrangianPenalty(1.0, 1.0),
    )
    set_attribute(
        model,
        Attributes.PenaltyUpdateStrategy(),
        Attributes.SubgradientUpdate(),
    )

    optimize!(model)

    backend = JuMP.unsafe_backend(model)
    method = MOI.get(backend, Attributes.ConstraintEncodingMethod(), JuMP.index(al))

    @test MOI.get(backend, Attributes.PenaltyUpdateCount()) == 0
    @test method.multiplier == 1.0

    return nothing
end

function test_refinement_al_coefficient_conversion()
    function solve_with(method)
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)
        @objective(model, Max, 3x[1] + 2x[2])
        c = @constraint(model, x[1] + x[2] <= 1)

        set_attribute(c, Attributes.ConstraintEncodingMethod(), method)
        optimize!(model)

        return objective_value(model)
    end

    # A method parameterized on a wider type than the model's coefficients
    # (BigFloat method, Float64 model) converts instead of building a
    # malformed pseudo-Boolean function, and matches the Float64 method.
    @test solve_with(Attributes.AugmentedLagrangianPenalty(big"0.5", big"1.0")) ≈
          solve_with(Attributes.AugmentedLagrangianPenalty(0.5, 1.0))

    # Values that cannot be represented in the model's numeric type are
    # rejected instead of silently becoming `Inf` or `0.0`.
    for method in (
        Attributes.AugmentedLagrangianPenalty(big"1e400", big"1.0"),
        Attributes.AugmentedLagrangianPenalty(big"0.0", big"1e-400"),
    )
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)
        @objective(model, Max, 3x[1] + 2x[2])
        c = @constraint(model, x[1] + x[2] <= 1)

        set_attribute(c, Attributes.ConstraintEncodingMethod(), method)

        @test_throws ToQUBO.Compiler.CompilationError optimize!(model)
    end

    return nothing
end

function test_refinement_subgradient_multiplier_decrease()
    # White-box: a satisfied inequality (negative residual) shrinks the
    # multiplier toward zero and floors at zero.
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)
    MOI.add_constraint(model, x, MOI.ZeroOne())
    c = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm{Float64}(1.0, x)],
            0.0,
        ),
        MOI.LessThan{Float64}(1.0),
    )

    strategy = Attributes.SubgradientUpdate(; step = 1.0)

    satisfied(residual) = ToQUBO.ConstraintViolation(
        c,
        MOI.ScalarAffineFunction{Float64},
        MOI.LessThan{Float64},
        1.0 + residual,
        residual,
        0.0,
        Dict{VI,Any}(),
    )

    MOI.set(
        model,
        Attributes.ConstraintEncodingMethod(),
        c,
        Attributes.AugmentedLagrangianPenalty(1.0, 1.0),
    )
    @test ToQUBO._apply_penalty_update!(model, strategy, [satisfied(-0.5)], [], false)
    @test MOI.get(model, Attributes.ConstraintEncodingMethod(), c).multiplier ≈ 0.5

    MOI.set(
        model,
        Attributes.ConstraintEncodingMethod(),
        c,
        Attributes.AugmentedLagrangianPenalty(0.2, 1.0),
    )
    @test ToQUBO._apply_penalty_update!(model, strategy, [satisfied(-0.5)], [], false)
    @test MOI.get(model, Attributes.ConstraintEncodingMethod(), c).multiplier == 0.0

    return nothing
end

function test_refinement_subgradient_validations()
    @test_throws ArgumentError Attributes.SubgradientUpdate(; step = 0.0)
    @test_throws ArgumentError Attributes.SubgradientUpdate(; step = -1.0)
    @test_throws ArgumentError Attributes.SubgradientUpdate(; patience = 0)
    @test_throws ArgumentError Attributes.SubgradientUpdate(; escalation_factor = 1.0)

    # Finite `Real` inputs that overflow or underflow `Float64` storage must
    # be rejected by the converted value, not stored as `Inf`/`0.0`.
    @test_throws ArgumentError Attributes.SubgradientUpdate(; step = big"1e400")
    @test_throws ArgumentError Attributes.SubgradientUpdate(; step = big"1e-400")
    @test_throws ArgumentError Attributes.SubgradientUpdate(;
        escalation_factor = big"1e400",
    )

    # Values that convert cleanly are still accepted and stored exactly.
    let strategy = Attributes.SubgradientUpdate(;
            step = big"0.25",
            escalation_factor = big"2.5",
        )
        @test strategy.step == 0.25
        @test strategy.escalation_factor == 2.5
    end

    @test isnothing(Attributes.SubgradientUpdate().step)

    @test_throws ArgumentError Attributes.AugmentedLagrangianPenalty(0.0, 0.0)
    @test_throws ArgumentError Attributes.AugmentedLagrangianPenalty(0.0, -1.0)
    @test_throws ArgumentError Attributes.AugmentedLagrangianPenalty(NaN, 1.0)

    # Negative multipliers are legal (equality duals) and types promote.
    method = Attributes.AugmentedLagrangianPenalty(-1, 2.0)
    @test method.multiplier == -1.0
    @test method.rho == 2.0

    return nothing
end

function test_refinement()
    @testset "→ Penalty Refinement" verbose = true begin
        test_refinement_attributes()
        test_refinement_hinted_escalation()
        test_refinement_scale_escalation()
        test_refinement_default_off()
        test_refinement_already_feasible()
        test_refinement_budget_exhaustion()
        test_refinement_zero_result_stop()
        test_refinement_zero_result_mid_loop_stop()
        test_refinement_slack_escalation()
        test_refinement_smaller_factor()
        test_refinement_subgradient_validations()
        test_refinement_subgradient_inequality()
        test_refinement_subgradient_equality()
        test_refinement_subgradient_stall_escalation()
        test_refinement_subgradient_requires_al()
        test_refinement_subgradient_unreachable_violation_break()
        test_refinement_al_compiles_without_hint()
        test_refinement_al_coefficient_conversion()
        test_refinement_subgradient_multiplier_decrease()
    end

    return nothing
end