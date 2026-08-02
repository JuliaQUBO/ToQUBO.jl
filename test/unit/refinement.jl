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

        @test MOI.get(model, Attributes.PenaltyUpdateCount()) === nothing
        @test MOI.is_set_by_optimize(Attributes.PenaltyUpdateCount())
    end

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

function test_refinement()
    @testset "→ Penalty Refinement" verbose = true begin
        test_refinement_attributes()
        test_refinement_hinted_escalation()
        test_refinement_scale_escalation()
        test_refinement_default_off()
        test_refinement_already_feasible()
        test_refinement_budget_exhaustion()
        test_refinement_smaller_factor()
    end

    return nothing
end