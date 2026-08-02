# Iterative penalty refinement (design record: JuliaQUBO/QUBO.jl#67).
#
# After the first solve, while the best sample violates source constraints
# and the update budget is not exhausted, penalty coefficients are updated
# according to the configured strategy, the model is fully recompiled (user
# attributes survive `Compiler.reset!`), and the sampler is invoked again.
# Recompilation keeps every iteration on the ordinary compile path; penalty
# coefficients do not alter slack bounds, so the target model's structure is
# stable across iterations even though target indices are reassigned.

function _best_sample_violations(model::Virtual.Model, atol::Real)
    MOI.get(model, MOI.ResultCount()) > 0 || return nothing

    return filter(
        measurement -> measurement.violation > Float64(atol),
        _constraint_measurements(model, 1),
    )
end

function _apply_penalty_update!(
    model::Virtual.Model{T},
    strategy::Attributes.MultiplicativeUpdate,
    violated,
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

function _refine_penalties!(model::Virtual.Model{T}) where {T}
    budget = Attributes.max_penalty_updates(model)
    count = 0

    if budget > 0 && !isnothing(model.optimizer)
        strategy = Attributes.penalty_update_strategy(model)

        while count < budget
            violated = _best_sample_violations(model, _FEASIBILITY_ATOL)

            (isnothing(violated) || isempty(violated)) && break

            _apply_penalty_update!(model, strategy, violated) || break

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