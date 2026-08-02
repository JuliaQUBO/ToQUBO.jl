# Iterative penalty refinement (design record: JuliaQUBO/QUBO.jl#67).
#
# After the first solve, while the best sample violates source constraints
# and the update budget is not exhausted, penalty coefficients are updated
# according to the configured strategy, the model is fully recompiled (user
# attributes survive `Compiler.reset!`), and the sampler is invoked again.
# Recompilation keeps every iteration on the ordinary compile path; penalty
# coefficients do not alter slack bounds, so the target model's structure is
# stable across iterations even though target indices are reassigned.

function _violation_norm(violated)
    return sqrt(sum(measurement -> measurement.violation^2, violated; init = 0.0))
end

_stall_patience(::Attributes.MultiplicativeUpdate) = nothing
_stall_patience(strategy::Attributes.SubgradientUpdate) = strategy.patience

function _apply_penalty_update!(
    model::Virtual.Model{T},
    strategy::Attributes.MultiplicativeUpdate,
    measurements,
    violated,
    stalled::Bool,
) where {T}
    updated = false

    for measurement in violated
        ci = measurement.constraint

        # Only constraints backed by a penalty function have a coefficient to
        # escalate; violations driven by variable encodings (e.g. off-grid
        # decodes) have no per-constraint knob and are skipped.
        haskey(model.g, ci) || haskey(model.s, ci) || continue

        hint = Attributes.constraint_encoding_penalty_hint(model, ci)

        if !isnothing(hint)
            # Hints bypass scale/offset entirely, so escalate the hint itself;
            # multiplying preserves its sense-dependent sign.
            MOI.set(
                model,
                Attributes.ConstraintEncodingPenaltyHint(),
                ci,
                hint * strategy.factor,
            )
        else
            # Scales are sign-neutral magnitudes and also escalate the
            # constraint's slack-encoding penalty.
            scale = Attributes.constraint_penalty_scale(model, ci)

            MOI.set(model, Attributes.ConstraintPenaltyScale(), ci, scale * strategy.factor)
        end

        updated = true
    end

    return updated
end

function _apply_penalty_update!(
    model::Virtual.Model{T},
    strategy::Attributes.SubgradientUpdate,
    measurements,
    violated,
    stalled::Bool,
) where {T}
    violated_constraints = Set(measurement.constraint for measurement in violated)
    updated = false

    for measurement in measurements
        ci = measurement.constraint
        method = Attributes.constraint_encoding_method(model, ci)

        # The subgradient strategy drives augmented-Lagrangian constraints
        # only; every satisfied or violated such constraint is updated from
        # its signed residual (multipliers may also decrease).
        method isa Attributes.AugmentedLagrangianPenalty || continue
        measurement.raw_residual isa Real || continue

        set = MOI.get(model.source_model, MOI.ConstraintSet(), ci)
        r = Float64(measurement.raw_residual)
        λ = method.multiplier
        ρ = method.rho
        η = something(strategy.step, ρ)

        λ′ = if set isa MOI.EqualTo
            λ + η * r
        elseif set isa MOI.LessThan || set isa MOI.GreaterThan
            # One-sided dual update: r > 0 iff violated for both senses.
            max(zero(λ), λ + η * r)
        else
            continue
        end

        ρ′ = (stalled && ci in violated_constraints) ? ρ * strategy.escalation_factor : ρ

        if λ′ != λ || ρ′ != ρ
            MOI.set(
                model,
                Attributes.ConstraintEncodingMethod(),
                ci,
                Attributes.AugmentedLagrangianPenalty(λ′, ρ′),
            )

            updated = true
        end
    end

    return updated
end

function _refine_penalties!(model::Virtual.Model{T}) where {T}
    budget = Attributes.max_penalty_updates(model)
    count = 0

    if budget > 0 && !isnothing(model.optimizer)
        strategy = Attributes.penalty_update_strategy(model)
        patience = _stall_patience(strategy)
        previous_norm = nothing
        streak = 0

        while count < budget
            MOI.get(model, MOI.ResultCount()) > 0 || break

            measurements = _constraint_measurements(model, 1)
            violated = filter(
                measurement -> measurement.violation > Float64(_FEASIBILITY_ATOL),
                measurements,
            )

            isempty(violated) && break

            # Sampled binary problems have quantized violation norms, so a
            # stall is a run of `patience` iterations without improvement,
            # not a per-iteration ratio test.
            norm = _violation_norm(violated)
            improved =
                isnothing(previous_norm) || norm < previous_norm - Float64(_FEASIBILITY_ATOL)
            streak = improved ? 0 : streak + 1
            stalled = !isnothing(patience) && streak >= patience

            stalled && (streak = 0)

            _apply_penalty_update!(model, strategy, measurements, violated, stalled) ||
                break

            previous_norm = norm
            count += 1

            Compiler.reset!(model)

            let t = @elapsed Compiler.compile!(model)
                MOI.set(model, Attributes.CompilationStatus(), MOI.LOCALLY_SOLVED)
                MOI.set(model, Attributes.CompilationTime(), t)
            end

            MOI.optimize!(model.optimizer, model.target_model)
            MOI.set(
                model,
                MOI.RawStatusString(),
                MOI.get(model.optimizer, MOI.RawStatusString()),
            )
        end
    end

    model.compiler_settings[:penalty_update_count] = count

    return nothing
end