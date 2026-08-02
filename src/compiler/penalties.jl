function _uses_linear_equality_penalty(model::Virtual.Model, ci::CI)::Bool
    return MOI.get(model, MOI.ConstraintSet(), ci) isa MOI.EqualTo &&
           Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty
end

function _uses_unbalanced_penalty(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa Attributes.UnbalancedPenalty
end

function _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    return scale * sign * (δ / ϵ + offset)
end

function _objective_range_metadata(model::Virtual.Model)
    lower, upper = PBO.bounds(model.f)
    range = upper - lower
    finite = isfinite(lower) && isfinite(upper) && isfinite(range) && range >= zero(range)

    return Dict{String,Any}(
        "source" => "compiled_pbf_bounds",
        "lower" => lower,
        "upper" => upper,
        "range" => range,
        "finite" => finite,
    )
end

function _penalty_context(model::Virtual.Model)
    policy = Attributes.penalty_policy(model)
    objective_bounds = _objective_range_metadata(model)

    return Dict{String,Any}(
        "policy" => string(nameof(typeof(policy))),
        "objective_bounds" => objective_bounds,
        "inferred_penalties" => Dict{String,Any}(
            "constraints" => Dict{String,Any}[],
            "variables" => Dict{String,Any}[],
            "slack_variables" => Dict{String,Any}[],
        ),
        "fallbacks" => Dict{String,Any}[],
    )
end

function _fallback!(context::AbstractDict, kind::String, id::Integer, reason::String)
    push!(
        context["fallbacks"],
        Dict{String,Any}(
            "kind" => kind,
            "id" => id,
            "reason" => reason,
            "fallback_policy" => "LegacyPenalty",
        ),
    )

    return nothing
end

function _objective_range_penalty_factor(
    sign,
    range,
    ϵ,
    scale,
    offset,
)
    return scale * sign * ((range + offset) / ϵ)
end

# One-flip change bounds of a pseudo-Boolean function (Ayodele 2022,
# arXiv:2206.11040, Eq. 14 generalized to arbitrary degree): every monomial is
# credited to each variable it contains, so `increase[v]`/`decrease[v]` bound
# the objective gain/loss of flipping `v` with all other variables free.
function _flip_values(f::PBO.PBF{VI,T}) where {T}
    increase = Dict{VI,T}()
    decrease = Dict{VI,T}()

    for (ω, c) in f
        isempty(ω) && continue

        if length(ω) == 1
            v = first(ω)
            increase[v] = get(increase, v, zero(T)) + c
            decrease[v] = get(decrease, v, zero(T)) - c
        else
            for v in ω
                if c > zero(T)
                    increase[v] = get(increase, v, zero(T)) + c
                else
                    decrease[v] = get(decrease, v, zero(T)) - c
                end
            end
        end
    end

    return increase, decrease
end

function _min_positive_flip(p::PBO.PBF{VI,T}) where {T}
    increase, decrease = _flip_values(p)
    γ = typemax(T)

    for w in Iterators.flatten((values(increase), values(decrease)))
        if w > zero(T)
            γ = min(γ, w)
        end
    end

    return γ
end

function _objective_penalty_scan(f::PBO.PBF{VI,T}) where {T}
    coefficient_sum = zero(T)
    has_negative = false
    max_coefficient = typemin(T)
    term_count = 0

    for (ω, c) in f
        isempty(ω) && continue

        term_count += 1
        coefficient_sum += c
        has_negative |= c < zero(T)
        max_coefficient = max(max_coefficient, c)
    end

    increase, decrease = _flip_values(f)
    vlm = typemin(T)

    for w in Iterators.flatten((values(increase), values(decrease)))
        vlm = max(vlm, w)
    end

    return (; coefficient_sum, has_negative, max_coefficient, term_count, increase, decrease, vlm)
end

const _HEURISTIC_PENALTY_POLICIES = Union{
    Attributes.UBPositivePenalty,
    Attributes.MaxCoefficientPenalty,
    Attributes.VLMPenalty,
    Attributes.MOMCPenalty,
    Attributes.MOCPenalty,
}

# Returns `(λ, nothing)` on success or `(nothing, reason)` when the policy's
# validity conditions do not hold and the coefficient must fall back.
function _heuristic_penalty_bound(
    ::Attributes.UBPositivePenalty,
    scan,
    ::PBO.PBF{VI,T},
) where {T}
    scan.term_count > 0 ||
        return nothing, "UBPositivePenalty requires a non-constant objective"
    !scan.has_negative ||
        return nothing, "UBPositivePenalty requires nonnegative objective coefficients"
    isfinite(scan.coefficient_sum) ||
        return nothing, "Objective coefficient sum is not finite"

    return scan.coefficient_sum, nothing
end

function _heuristic_penalty_bound(
    ::Attributes.MaxCoefficientPenalty,
    scan,
    ::PBO.PBF{VI,T},
) where {T}
    scan.term_count > 0 ||
        return nothing, "MaxCoefficientPenalty requires a non-constant objective"
    (isfinite(scan.max_coefficient) && scan.max_coefficient > zero(T)) ||
        return nothing, "Maximum objective coefficient is not strictly positive"

    return scan.max_coefficient, nothing
end

function _heuristic_penalty_bound(
    ::Attributes.VLMPenalty,
    scan,
    ::PBO.PBF{VI,T},
) where {T}
    (isfinite(scan.vlm) && scan.vlm > zero(T)) ||
        return nothing, "Objective one-flip bound is not strictly positive"

    return scan.vlm, nothing
end

function _heuristic_penalty_bound(
    ::Attributes.MOMCPenalty,
    scan,
    p::PBO.PBF{VI,T},
) where {T}
    (isfinite(scan.vlm) && scan.vlm > zero(T)) ||
        return nothing, "Objective one-flip bound is not strictly positive"

    γ = _min_positive_flip(p)

    γ < typemax(T) ||
        return nothing, "Penalty function has no strictly positive one-flip change"

    return max(one(T), scan.vlm / γ), nothing
end

function _heuristic_penalty_bound(
    ::Attributes.MOCPenalty,
    scan,
    p::PBO.PBF{VI,T},
) where {T}
    increase, decrease = _flip_values(p)
    ratio = zero(T)
    positive = false

    for (v, w) in increase
        if w > zero(T)
            positive = true
            ratio = max(ratio, abs(get(scan.increase, v, zero(T)) / w))
        end
    end

    for (v, w) in decrease
        if w > zero(T)
            positive = true
            ratio = max(ratio, abs(get(scan.decrease, v, zero(T)) / w))
        end
    end

    positive ||
        return nothing, "Penalty function has no strictly positive one-flip change"
    isfinite(ratio) ||
        return nothing, "Objective-to-constraint flip ratio is not finite"

    return max(one(T), ratio), nothing
end

# Same composition as the objective-range policy: the heuristic bound plays
# the role of the certified objective range.
function _heuristic_penalty_factor(sign, λ, ϵ, scale, offset)
    return scale * sign * ((λ + offset) / ϵ)
end

function _is_integer_valued(p::PBO.PBF)
    for (_ω, coefficient) in p
        isinteger(coefficient) || return false
    end

    return true
end

function _positive_penalty_gap(p::PBO.PBF{VI,T}) where {T}
    if _is_integer_valued(p)
        return one(T), "integer_valued_penalty"
    else
        return PBO.mingap(p), "pbo_mingap"
    end
end

function _inferred_penalty_factor(
    model::Virtual.Model,
    context::AbstractDict,
    scan,
    sign,
    δ,
    p::PBO.PBF,
    ϵ,
    scale,
    offset,
    kind::String,
    id::Integer,
)
    policy = Attributes.penalty_policy(model)

    if policy isa Attributes.LegacyPenalty
        return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    end

    if policy isa _HEURISTIC_PENALTY_POLICIES
        if !(isfinite(ϵ) && ϵ > zero(ϵ))
            _fallback!(context, kind, id, "Penalty function positive gap is not finite")
            return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
        end

        λ, reason = _heuristic_penalty_bound(policy, scan, p)

        if isnothing(λ)
            _fallback!(context, kind, id, reason)
            return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
        end

        return _heuristic_penalty_factor(sign, λ, ϵ, scale, offset)
    end

    objective_bounds = context["objective_bounds"]

    if !(policy isa Attributes.ObjectiveRangePenalty)
        _fallback!(context, kind, id, "Unknown automatic penalty policy")
        return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    elseif !objective_bounds["finite"]
        _fallback!(context, kind, id, "Objective range is not finite")
        return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    elseif !(isfinite(ϵ) && ϵ > zero(ϵ))
        _fallback!(context, kind, id, "Penalty function positive gap is not finite")
        return _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    end

    return _objective_range_penalty_factor(
        sign,
        objective_bounds["range"],
        ϵ,
        scale,
        offset,
    )
end

function _inferred_penalty_bucket(kind::String)
    if kind == "constraint"
        return "constraints"
    elseif kind == "variable"
        return "variables"
    elseif kind == "slack_variable"
        return "slack_variables"
    end

    error("Unknown inferred penalty kind: $(kind)")
end

function _record_inferred_penalty!(
    context::AbstractDict,
    kind::String,
    id::Integer,
    ρ,
    ϵ,
    gap_source::String,
    scale,
    offset,
    fallback,
)
    entry = Dict{String,Any}(
        "kind" => kind,
        "id" => id,
        "penalty" => ρ,
        "epsilon" => ϵ,
        "epsilon_source" => gap_source,
        "scale" => scale,
        "offset" => offset,
        "automatic_policy" => context["policy"],
        "selected_policy" =>
            isnothing(fallback) ? context["policy"] : fallback["fallback_policy"],
    )

    if !isnothing(fallback)
        entry["fallback_reason"] = fallback["reason"]
    end

    push!(context["inferred_penalties"][_inferred_penalty_bucket(kind)], entry)

    return nothing
end

function _infer_and_record_penalty_factor(
    model::Virtual.Model,
    context::AbstractDict,
    scan,
    sign,
    δ,
    p::PBO.PBF,
    scale,
    offset,
    kind::String,
    id::Integer,
)
    ϵ, gap_source = _positive_penalty_gap(p)
    fallback_count = length(context["fallbacks"])
    ρ = _inferred_penalty_factor(
        model,
        context,
        scan,
        sign,
        δ,
        p,
        ϵ,
        scale,
        offset,
        kind,
        id,
    )
    fallback = length(context["fallbacks"]) > fallback_count ? last(context["fallbacks"]) : nothing

    _record_inferred_penalty!(context, kind, id, ρ, ϵ, gap_source, scale, offset, fallback)

    return ρ
end

function penalties!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Adjust Sign
    σ = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    δ = PBO.maxgap(model.f)
    scan = _objective_penalty_scan(model.f)
    context = _penalty_context(model)

    for (ci, g) in model.g
        ρ = Attributes.constraint_encoding_penalty_hint(model, ci)

        if isnothing(ρ)
            if _uses_linear_equality_penalty(model, ci)
                compilation_error!(
                    model,
                    "LinearPenalty requires an explicit ConstraintEncodingPenaltyHint";
                    status = "Missing linear constraint penalty hint",
                )
            elseif _uses_unbalanced_penalty(model, ci)
                compilation_error!(
                    model,
                    "UnbalancedPenalty requires an explicit ConstraintEncodingPenaltyHint";
                    status = "Missing unbalanced constraint penalty hint",
                )
            end

            scale = Attributes.constraint_penalty_scale(model, ci)
            offset = Attributes.constraint_penalty_offset(model, ci)
            ρ = _infer_and_record_penalty_factor(
                model,
                context,
                scan,
                σ,
                δ,
                g,
                scale,
                offset,
                "constraint",
                ci.value,
            )
        end

        MOI.set(model, Attributes.ConstraintEncodingPenalty(), ci, ρ)
    end

    for (vi, h) in model.h
        θ = Attributes.variable_encoding_penalty_hint(model, vi)

        if isnothing(θ)
            scale = Attributes.penalty_scale(model)
            offset = Attributes.penalty_offset(model)
            θ = _infer_and_record_penalty_factor(
                model,
                context,
                scan,
                σ,
                δ,
                h,
                scale,
                offset,
                "variable",
                vi.value,
            )
        end

        MOI.set(model, Attributes.VariableEncodingPenalty(), vi, θ)
    end

    for (ci, s) in model.s
        η = Attributes.slack_variable_encoding_penalty_hint(model, ci)

        if isnothing(η)
            scale = Attributes.constraint_penalty_scale(model, ci)
            offset = Attributes.constraint_penalty_offset(model, ci)
            η = _infer_and_record_penalty_factor(
                model,
                context,
                scan,
                σ,
                δ,
                s,
                scale,
                offset,
                "slack_variable",
                ci.value,
            )
        end

        MOI.set(model, Attributes.SlackVariableEncodingPenalty(), ci, η)
    end

    context["fallback_count"] = length(context["fallbacks"])
    context["legacy_objective_gap"] = δ
    model.compiler_settings[:penalty_policy_metadata] = context

    return nothing
end
