function _uses_linear_equality_penalty(model::Virtual.Model, ci::CI)::Bool
    return MOI.get(model, MOI.ConstraintSet(), ci) isa MOI.EqualTo &&
           Attributes.constraint_encoding_method(model, ci) isa Attributes.LinearPenalty
end

function _uses_unbalanced_penalty(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa Attributes.UnbalancedPenalty
end

function _uses_augmented_lagrangian(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa
           Attributes.AugmentedLagrangianPenalty
end

function _legacy_penalty_factor(sign, δ, ϵ, scale, offset)
    return scale * sign * (δ / ϵ + offset)
end

function _exact_rational(x)::Union{Rational{BigInt},Nothing}
    if !(x isa Real) || x isa Bool || !isfinite(x)
        return nothing
    end

    try
        return Rational{BigInt}(x)
    catch
        return nothing
    end
end

function _round_down(::Type{T}, q::Rational{BigInt}) where {T<:AbstractFloat}
    x = T(q)
    isfinite(x) || return x

    if Rational{BigInt}(x) > q
        x = prevfloat(x)
    end

    return x
end

function _round_down(::Type{T}, q::Rational{BigInt}) where {T<:Real}
    return convert(T, q)
end

function _round_up(::Type{T}, q::Rational{BigInt}) where {T<:AbstractFloat}
    x = T(q)
    isfinite(x) || return x

    if Rational{BigInt}(x) < q
        x = nextfloat(x)
    end

    return x
end

function _round_up(::Type{T}, q::Rational{BigInt}) where {T<:Real}
    return convert(T, q)
end

function _pbf_bounds_rational(f::PBO.PBF{VI,T}) where {T}
    lower_q = zero(Rational{BigInt})
    upper_q = zero(Rational{BigInt})

    for (ω, c) in f
        cq = _exact_rational(c)
        isnothing(cq) && return nothing

        if isempty(ω)
            lower_q += cq
            upper_q += cq
        elseif cq < 0
            lower_q += cq
        elseif cq > 0
            upper_q += cq
        end
    end

    return lower_q, upper_q
end

function _eval_pbf_rational(
    f::PBO.PBF{VI,T},
    state::AbstractDict{VI,Int},
)::Union{Rational{BigInt},Nothing} where {T}
    total = zero(Rational{BigInt})

    for (ω, c) in f
        cq = _exact_rational(c)
        isnothing(cq) && return nothing
        active = true

        for v in ω
            haskey(state, v) || return nothing
            bit = state[v]
            (bit == 0 || bit == 1) || return nothing

            if bit == 0
                active = false
                break
            end
        end

        if active
            total += cq
        end
    end

    return total
end

function _eval_source_function_rational(
    vi::VI,
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Rational{BigInt},Nothing}
    return get(cand_q, vi, nothing)
end

function _eval_source_function_rational(
    f::SAF{T},
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Rational{BigInt},Nothing} where {T}
    total = _exact_rational(f.constant)
    isnothing(total) && return nothing

    for term in f.terms
        cq = _exact_rational(term.coefficient)
        isnothing(cq) && return nothing
        haskey(cand_q, term.variable) || return nothing
        total += cq * cand_q[term.variable]
    end

    return total
end

function _eval_source_function_rational(
    f::SQF{T},
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Rational{BigInt},Nothing} where {T}
    total = _exact_rational(f.constant)
    isnothing(total) && return nothing

    for term in f.affine_terms
        cq = _exact_rational(term.coefficient)
        isnothing(cq) && return nothing
        haskey(cand_q, term.variable) || return nothing
        total += cq * cand_q[term.variable]
    end

    for term in f.quadratic_terms
        cq = _exact_rational(term.coefficient)
        isnothing(cq) && return nothing
        (haskey(cand_q, term.variable_1) && haskey(cand_q, term.variable_2)) ||
            return nothing

        if term.variable_1 === term.variable_2
            cq //= 2
        end

        total += cq * cand_q[term.variable_1] * cand_q[term.variable_2]
    end

    return total
end

function _eval_source_function_rational(
    f::MOI.VectorOfVariables,
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Vector{Rational{BigInt}},Nothing}
    vals = Vector{Rational{BigInt}}(undef, length(f.variables))

    for (i, vi) in enumerate(f.variables)
        haskey(cand_q, vi) || return nothing
        vals[i] = cand_q[vi]
    end

    return vals
end

function _eval_source_function_rational(
    f::MOI.VectorAffineFunction{T},
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Vector{Rational{BigInt}},Nothing} where {T}
    vals = Vector{Rational{BigInt}}(undef, length(f.constants))

    for (i, c) in enumerate(f.constants)
        cq = _exact_rational(c)
        isnothing(cq) && return nothing
        vals[i] = cq
    end

    for term in f.terms
        cq = _exact_rational(term.scalar_term.coefficient)
        isnothing(cq) && return nothing
        vi = term.scalar_term.variable
        haskey(cand_q, vi) || return nothing
        vals[term.output_index] += cq * cand_q[vi]
    end

    return vals
end

function _eval_source_function_rational(
    f::MOI.VectorQuadraticFunction{T},
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Vector{Rational{BigInt}},Nothing} where {T}
    vals = Vector{Rational{BigInt}}(undef, length(f.constants))

    for (i, c) in enumerate(f.constants)
        cq = _exact_rational(c)
        isnothing(cq) && return nothing
        vals[i] = cq
    end

    for term in f.affine_terms
        cq = _exact_rational(term.scalar_term.coefficient)
        isnothing(cq) && return nothing
        vi = term.scalar_term.variable
        haskey(cand_q, vi) || return nothing
        vals[term.output_index] += cq * cand_q[vi]
    end

    for term in f.quadratic_terms
        cq = _exact_rational(term.scalar_term.coefficient)
        isnothing(cq) && return nothing
        v1 = term.scalar_term.variable_1
        v2 = term.scalar_term.variable_2
        (haskey(cand_q, v1) && haskey(cand_q, v2)) || return nothing

        if v1 === v2
            cq //= 2
        end

        vals[term.output_index] += cq * cand_q[v1] * cand_q[v2]
    end

    return vals
end

function _eval_source_function_rational(::MOI.AbstractFunction, ::Dict{VI,Rational{BigInt}})
    return nothing
end

function _in_source_set_rational(val::Rational{BigInt}, ::MOI.ZeroOne)::Bool
    return val == 0 || val == 1
end

function _in_source_set_rational(val::Rational{BigInt}, ::MOI.Integer)::Bool
    return denominator(val) == 1
end

function _in_source_set_rational(val::Rational{BigInt}, s::EQ{T})::Bool where {T}
    rhs = _exact_rational(s.value)
    return !isnothing(rhs) && val == rhs
end

function _in_source_set_rational(val::Rational{BigInt}, s::LT{T})::Bool where {T}
    upper = _exact_rational(s.upper)
    return !isnothing(upper) && val <= upper
end

function _in_source_set_rational(val::Rational{BigInt}, s::GT{T})::Bool where {T}
    lower = _exact_rational(s.lower)
    return !isnothing(lower) && val >= lower
end

function _in_source_set_rational(val::Rational{BigInt}, s::MOI.Interval{T})::Bool where {T}
    lower = _exact_rational(s.lower)
    upper = _exact_rational(s.upper)
    return !isnothing(lower) && !isnothing(upper) && lower <= val <= upper
end

function _in_source_set_rational(
    val::Rational{BigInt},
    s::MOI.Semicontinuous{T},
)::Bool where {T}
    lower = _exact_rational(s.lower)
    upper = _exact_rational(s.upper)
    return !isnothing(lower) && !isnothing(upper) &&
           (iszero(val) || (lower <= val <= upper))
end

function _in_source_set_rational(
    val::Rational{BigInt},
    s::MOI.Semiinteger{T},
)::Bool where {T}
    lower = _exact_rational(s.lower)
    upper = _exact_rational(s.upper)
    return !isnothing(lower) && !isnothing(upper) &&
           (iszero(val) || (denominator(val) == 1 && lower <= val <= upper))
end

function _in_source_set_rational(
    vals::Vector{Rational{BigInt}},
    ::MOI.SOS1{T},
)::Bool where {T}
    return count(!iszero, vals) <= 1
end

function _in_source_set_rational(
    vals::Vector{Rational{BigInt}},
    s::MOI.Indicator{A,S},
)::Bool where {A,S}
    length(vals) >= 2 || return false
    z = vals[1]
    (z == 0 || z == 1) || return false

    active = if A === MOI.ACTIVATE_ON_ONE
        z == 1
    elseif A === MOI.ACTIVATE_ON_ZERO
        z == 0
    else
        return false
    end

    !active && return true

    inner = length(vals) == 2 ? vals[2] : vals[2:end]
    return _in_source_set_rational(inner, s.set)
end

function _in_source_set_rational(::Any, ::MOI.AbstractSet)::Bool
    return false
end

function _source_variables_in_order(model::Virtual.Model)
    return collect(MOI.get(model.source_model, MOI.ListOfVariableIndices()))
end

function _normalize_candidate_value(::Type{T}, raw_val) where {T}
    vq = _exact_rational(raw_val)
    isnothing(vq) && return nothing, nothing

    vt = try
        convert(T, raw_val)
    catch
        nothing
    end

    if isnothing(vt) || !isfinite(vt) || _exact_rational(vt) != vq
        return nothing, nothing
    end

    return vt, vq
end

function _resolve_jump_variable_key(model::Virtual.Model, k)::VI
    vi = getproperty(k, :index)::VI
    !hasproperty(k, :model) && return vi
    jm = getproperty(k, :model)
    b = hasproperty(jm, :moi_backend) ? getproperty(jm, :moi_backend) : jm
    if !(b isa MOI.ModelLike) || !MOI.is_valid(b, vi)
        return VI(-abs(vi.value) - 1)
    end
    cur = b
    while cur !== model
        if cur isa MOI.Utilities.CachingOptimizer
            cur = cur.optimizer
        elseif cur isa MOI.Bridges.LazyBridgeOptimizer
            cur = cur.model
        else
            return VI(-abs(vi.value) - 1)
        end
    end
    outer_vars = MOI.get(b, MOI.ListOfVariableIndices())
    source_vars = _source_variables_in_order(model)
    pos = findfirst(==(vi), outer_vars)
    if !isnothing(pos) && length(outer_vars) == length(source_vars)
        return source_vars[pos]
    end
    return VI(-abs(vi.value) - 1)
end

function _normalize_candidate_assignment(model::Virtual.Model{T}, raw) where {T}
    source_vars = _source_variables_in_order(model)
    source_set = Set(source_vars)

    if raw isa AbstractDict
        if isempty(raw) && !isempty(source_vars)
            return nothing, nothing, "Candidate assignment is incomplete: missing source variables"
        end

        cand_t = Dict{VI,T}()
        cand_q = Dict{VI,Rational{BigInt}}()

        for (k, v) in raw
            vi = if k isa VI
                k
            elseif k isa Integer && !(k isa Bool)
                VI(Int(k))
            elseif !(k isa Number) && hasproperty(k, :index) && getproperty(k, :index) isa VI
                _resolve_jump_variable_key(model, k)
            else
                return nothing, nothing, "Candidate assignment contains invalid or non-variable keys"
            end

            vt, vq = _normalize_candidate_value(T, v)
            if isnothing(vq)
                return nothing, nothing, "Candidate assignment contains invalid or non-finite numeric values"
            end

            if haskey(cand_q, vi) && cand_q[vi] != vq
                return nothing, nothing, "Candidate assignment contains duplicate variable keys"
            end

            cand_t[vi] = vt
            cand_q[vi] = vq
        end

        for vi in keys(cand_q)
            if !(vi in source_set)
                return nothing, nothing, "Candidate assignment contains stale or unknown source variables"
            end
        end

        if length(cand_q) < length(source_vars)
            return nothing, nothing, "Candidate assignment is incomplete: missing source variables"
        end

        return cand_t, cand_q, nothing
    elseif raw isa Union{AbstractVector,Tuple}
        if length(raw) < length(source_vars)
            return nothing, nothing, "Candidate assignment is incomplete: missing source variables"
        elseif length(raw) > length(source_vars)
            return nothing, nothing, "Candidate assignment contains stale or extra entries"
        end

        cand_t = Dict{VI,T}()
        cand_q = Dict{VI,Rational{BigInt}}()

        for (vi, v) in zip(source_vars, raw)
            vt, vq = _normalize_candidate_value(T, v)
            if isnothing(vq)
                return nothing, nothing, "Candidate assignment contains invalid or non-finite numeric values"
            end

            cand_t[vi] = vt
            cand_q[vi] = vq
        end

        return cand_t, cand_q, nothing
    else
        return nothing,
        nothing,
        "Candidate incumbent must be a variable assignment (dictionary, vector, or tuple), not a scalar or unsupported value"
    end
end

function _resolve_candidate_assignment(model::Virtual.Model{T}) where {T}
    model_inc = MOI.get(model, Attributes.PenaltyIncumbent())
    policy = Attributes.penalty_policy(model)
    policy_inc = policy isa Attributes.ObjectiveRangePenalty ? policy.incumbent : nothing
    var_dict = get(model.variable_settings, :variable_penalty_incumbent, nothing)
    has_var_inc = !isnothing(var_dict) && !isempty(var_dict)

    sources = Any[]
    !isnothing(model_inc) && push!(sources, model_inc)
    !isnothing(policy_inc) && push!(sources, policy_inc)
    has_var_inc && push!(sources, var_dict)

    if isempty(sources)
        return false, nothing, nothing, nothing
    end

    cand_t, cand_q, reason = _normalize_candidate_assignment(model, first(sources))
    if !isnothing(reason)
        return true, nothing, nothing, reason
    end

    for other in Iterators.drop(sources, 1)
        _, other_q, other_reason = _normalize_candidate_assignment(model, other)
        if !isnothing(other_reason)
            return true, nothing, nothing, other_reason
        elseif other_q != cand_q
            return true, nothing, nothing, "Conflicting penalty incumbent inputs"
        end
    end

    return true, cand_t, cand_q, nothing
end

function _validate_source_feasibility_rational(
    model::Virtual.Model{T},
    cand_q::Dict{VI,Rational{BigInt}},
) where {T}
    for vi in _source_variables_in_order(model)
        γ = Attributes.variable_encoding_set(model, vi)
        if !isnothing(γ)
            if !any(g -> _exact_rational(g) == cand_q[vi], γ)
                return false,
                "Candidate value lies outside VariableEncodingSet for variable $(vi.value)"
            end
        end
    end

    for (F, S) in MOI.get(model.source_model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model.source_model, MOI.ListOfConstraintIndices{F,S}())
            f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)
            val_q = _eval_source_function_rational(f, cand_q)

            if isnothing(val_q)
                return false,
                "Source constraint $(ci.value) cannot be evaluated in exact arithmetic"
            elseif !_in_source_set_rational(val_q, s)
                return false,
                "Candidate assignment violates source constraint $(ci.value) ($(F) in $(S))"
            end
        end
    end

    return true, nothing
end

function _solve_affine_expansion_bits(
    targets::Vector{VI},
    ξ::PBO.PBF{VI,T},
    target_val_q::Rational{BigInt},
)::Union{Vector{Int},Nothing} where {T}
    n = length(targets)
    const_q = zero(Rational{BigInt})
    weights = zeros(Rational{BigInt}, n)
    idx_map = Dict{VI,Int}(vi => i for (i, vi) in enumerate(targets))

    for (ω, c) in ξ
        cq = _exact_rational(c)
        isnothing(cq) && return nothing

        if isempty(ω)
            const_q += cq
        elseif length(ω) == 1
            v = only(ω)
            haskey(idx_map, v) || return nothing
            weights[idx_map[v]] += cq
        else
            return nothing
        end
    end

    rem_q = target_val_q - const_q
    if n == 0
        return iszero(rem_q) ? Int[] : nothing
    end

    order = sortperm(1:n; by = i -> abs(weights[i]), rev = true)
    w_sorted = [weights[i] for i in order]
    suffix_min = zeros(Rational{BigInt}, n + 1)
    suffix_max = zeros(Rational{BigInt}, n + 1)

    for i = n:-1:1
        w = w_sorted[i]
        suffix_min[i] = suffix_min[i+1] + min(zero(Rational{BigInt}), w)
        suffix_max[i] = suffix_max[i+1] + max(zero(Rational{BigInt}), w)
    end

    chosen = zeros(Int, n)
    nodes = Ref(0)
    max_nodes = 100_000

    function search(pos::Int, current_rem::Rational{BigInt})::Bool
        if current_rem < suffix_min[pos] || current_rem > suffix_max[pos]
            return false
        end
        if pos > n
            return iszero(current_rem)
        end

        nodes[] += 1
        nodes[] > max_nodes && return false

        w = w_sorted[pos]
        first_bit = (w > 0 && current_rem >= w) || (w < 0 && current_rem <= w) ? 1 : 0

        for bit in (first_bit, 1 - first_bit)
            chosen[pos] = bit
            if search(pos + 1, current_rem - bit * w)
                return true
            end
        end

        return false
    end

    search(1, rem_q) || return nothing

    bits = zeros(Int, n)
    for (pos, orig_idx) in enumerate(order)
        bits[orig_idx] = chosen[pos]
    end

    return bits
end

function _lift_encoded_variable!(
    y_inc::Dict{VI,Int},
    v::Virtual.Variable{T},
    target_val_q::Rational{BigInt};
    is_slack::Bool = false,
)::Tuple{Bool,Union{String,Nothing}} where {T}
    e = Virtual.encoding(v)
    targets = Virtual.target(v)
    ξ = Virtual.expansion(v)
    χ = Virtual.penaltyfn(v)
    label = is_slack ? "slack variable encoding" : "variable encoding"

    if !(
        e isa Encoding.Mirror ||
        e isa Encoding.Binary ||
        e isa Encoding.Unary ||
        e isa Encoding.Arithmetic ||
        e isa Encoding.Bounded ||
        e isa Encoding.OneHot ||
        e isa Encoding.DomainWall
    )
        return false,
        "Unsupported $(label) $(nameof(typeof(e))) for incumbent lifting"
    end

    if isempty(targets)
        val_q = _eval_pbf_rational(ξ, y_inc)
        pen_ok = isnothing(χ) || _eval_pbf_rational(χ, y_inc) == 0
        if val_q == target_val_q && pen_ok
            return true, nothing
        else
            return false, "Candidate value is not representable by $(label)"
        end
    end

    if e isa Encoding.Mirror
        if length(targets) != 1 || !(target_val_q == 0 || target_val_q == 1)
            return false, "Candidate value is not representable by Mirror $(label)"
        end
        y_inc[targets[1]] = Int(target_val_q)
        if _eval_pbf_rational(ξ, y_inc) == target_val_q &&
           (isnothing(χ) || _eval_pbf_rational(χ, y_inc) == 0)
            return true, nothing
        end
        delete!(y_inc, targets[1])
        return false, "Candidate value is not representable by Mirror $(label)"
    elseif e isa Encoding.OneHot
        for k = 1:length(targets)
            for (j, yj) in enumerate(targets)
                y_inc[yj] = (j == k ? 1 : 0)
            end
            if _eval_pbf_rational(ξ, y_inc) == target_val_q &&
               (isnothing(χ) || _eval_pbf_rational(χ, y_inc) == 0)
                return true, nothing
            end
        end
        for yj in targets
            delete!(y_inc, yj)
        end
        return false, "Candidate value is not representable by OneHot $(label)"
    elseif e isa Encoding.DomainWall
        for k = 0:length(targets)
            for (j, yj) in enumerate(targets)
                y_inc[yj] = (j <= k ? 1 : 0)
            end
            if _eval_pbf_rational(ξ, y_inc) == target_val_q &&
               (isnothing(χ) || _eval_pbf_rational(χ, y_inc) == 0)
                return true, nothing
            end
        end
        for yj in targets
            delete!(y_inc, yj)
        end
        return false, "Candidate value is not representable by DomainWall $(label)"
    else
        bits = _solve_affine_expansion_bits(targets, ξ, target_val_q)
        if isnothing(bits)
            return false, "Candidate value is not representable by $(label)"
        end
        for (yj, bit) in zip(targets, bits)
            y_inc[yj] = bit
        end
        if _eval_pbf_rational(ξ, y_inc) == target_val_q &&
           (isnothing(χ) || _eval_pbf_rational(χ, y_inc) == 0)
            return true, nothing
        end
        for yj in targets
            delete!(y_inc, yj)
        end
        return false, "Candidate value is not representable by $(label)"
    end
end

function _is_exact_scalar_discretization(
    model::Virtual.Model{T},
    f::Union{SAF{T},SQF{T}},
    s::Union{EQ{T},LT{T},GT{T}},
    arch::AbstractArchitecture,
)::Bool where {T}
    !Attributes.discretize(model) && return true
    g_raw = _parse(model, f, s, arch)
    g_disc = copy(g_raw)
    _discretize!(g_disc)

    scale_q = nothing
    for ω in union(keys(g_raw), keys(g_disc))
        raw_q = _exact_rational(g_raw[ω])
        disc_q = _exact_rational(g_disc[ω])
        (isnothing(raw_q) || isnothing(disc_q)) && return false

        if iszero(raw_q) && iszero(disc_q)
            continue
        elseif iszero(raw_q) || iszero(disc_q)
            return false
        end

        ratio = disc_q // raw_q
        ratio > 0 || return false
        if isnothing(scale_q)
            scale_q = ratio
        elseif scale_q != ratio
            return false
        end
    end

    return true
end

function _check_exact_discretizations(
    model::Virtual.Model{T},
    arch::AbstractArchitecture,
)::Tuple{Bool,Union{String,Nothing}} where {T}
    !Attributes.discretize(model) && return true, nothing

    for (F, S) in MOI.get(model.source_model, MOI.ListOfConstraintTypesPresent())
        F <: Union{SAF{T},SQF{T}} || continue
        for ci in MOI.get(model.source_model, MOI.ListOfConstraintIndices{F,S}())
            f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)

            if s isa Union{EQ{T},LT{T},GT{T}}
                if !_is_exact_scalar_discretization(model, f, s, arch)
                    return false,
                    "Constraint $(ci.value) discretization rounded non-commensurable coefficients"
                end
            elseif s isa MOI.Interval{T}
                if !_is_exact_scalar_discretization(model, f, LT{T}(s.upper), arch) ||
                   !_is_exact_scalar_discretization(model, f, GT{T}(s.lower), arch)
                    return false,
                    "Constraint $(ci.value) discretization rounded non-commensurable coefficients"
                end
            end
        end
    end

    return true, nothing
end

function _lift_constraint_slacks!(
    model::Virtual.Model{T},
    y_inc::Dict{VI,Int},
    arch::AbstractArchitecture,
)::Tuple{Bool,Union{String,Nothing}} where {T}
    for (F, S) in MOI.get(model.source_model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model.source_model, MOI.ListOfConstraintIndices{F,S}())
            slack_vars = [v for v in model.variables if Virtual.source(v) == ci]
            isempty(slack_vars) && continue

            if count(v -> !isnothing(Virtual.penaltyfn(v)), slack_vars) > 1
                return false,
                "Multiple slack encoding penalties on constraint $(ci.value) are not supported"
            end

            f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)

            if s isa MOI.SOS1{T}
                v = only(slack_vars)
                if Virtual.encoding(v) isa Encoding.DomainWall
                    continue
                elseif Virtual.encoding(v) isa Encoding.Mirror &&
                       length(Virtual.target(v)) == 1 &&
                       haskey(model.g, ci)
                    yz = only(Virtual.target(v))
                    matched = false
                    for bit in (0, 1)
                        y_inc[yz] = bit
                        if _eval_pbf_rational(model.g[ci], y_inc) == 0
                            matched = true
                            break
                        end
                    end
                    matched || return false,
                    "Required SOS1 slack value is not representable by slack variable encoding"
                else
                    return false, "Unsupported SOS1 slack variable encoding for incumbent lifting"
                end
            elseif f isa Union{SAF{T},SQF{T}} && s isa LT{T}
                length(slack_vars) == 1 ||
                    return false, "Unexpected slack variable count on constraint $(ci.value)"
                g_pre = _parse(model, f, s, arch)
                Attributes.discretize(model) && _discretize!(g_pre)
                r_q = _eval_pbf_rational(g_pre, y_inc)
                isnothing(r_q) &&
                    return false, "Failed to evaluate constraint $(ci.value) residual"
                ok, reason = _lift_encoded_variable!(y_inc, only(slack_vars), -r_q; is_slack = true)
                ok || return false, reason
            elseif f isa Union{SAF{T},SQF{T}} && s isa GT{T}
                length(slack_vars) == 1 ||
                    return false, "Unexpected slack variable count on constraint $(ci.value)"
                g_pre = _parse(model, f, s, arch)
                Attributes.discretize(model) && _discretize!(g_pre)
                r_q = _eval_pbf_rational(g_pre, y_inc)
                isnothing(r_q) &&
                    return false, "Failed to evaluate constraint $(ci.value) residual"
                ok, reason = _lift_encoded_variable!(y_inc, only(slack_vars), r_q; is_slack = true)
                ok || return false, reason
            elseif f isa Union{SAF{T},SQF{T}} && s isa MOI.Interval{T}
                idx = 1
                s_lt = LT{T}(s.upper)
                g_lt = _parse(model, f, s_lt, arch)
                Attributes.discretize(model) && _discretize!(g_lt)
                l_lt, u_lt = PBO.bounds(g_lt)
                if !(u_lt <= zero(T) && Attributes.ignore_feasible_constraints(model)) &&
                   !_is_unbalanced_penalty(model, ci) &&
                   !_is_augmented_lagrangian(model, ci) &&
                   !_is_nonnegative(g_lt)
                    idx <= length(slack_vars) ||
                        return false, "Missing LessThan slack variable on interval constraint $(ci.value)"
                    r_lt = _eval_pbf_rational(g_lt, y_inc)
                    isnothing(r_lt) &&
                        return false, "Failed to evaluate constraint $(ci.value) upper residual"
                    ok, reason = _lift_encoded_variable!(
                        y_inc,
                        slack_vars[idx],
                        -r_lt;
                        is_slack = true,
                    )
                    ok || return false, reason
                    idx += 1
                end

                s_gt = GT{T}(s.lower)
                g_gt = _parse(model, f, s_gt, arch)
                Attributes.discretize(model) && _discretize!(g_gt)
                l_gt, u_gt = PBO.bounds(g_gt)
                if !(l_gt >= zero(T) && Attributes.ignore_feasible_constraints(model)) &&
                   !_is_unbalanced_penalty(model, ci) &&
                   !_is_augmented_lagrangian(model, ci) &&
                   !_is_nonpositive(g_gt)
                    idx <= length(slack_vars) ||
                        return false, "Missing GreaterThan slack variable on interval constraint $(ci.value)"
                    r_gt = _eval_pbf_rational(g_gt, y_inc)
                    isnothing(r_gt) &&
                        return false, "Failed to evaluate constraint $(ci.value) lower residual"
                    ok, reason = _lift_encoded_variable!(
                        y_inc,
                        slack_vars[idx],
                        r_gt;
                        is_slack = true,
                    )
                    ok || return false, reason
                    idx += 1
                end

                idx == length(slack_vars) + 1 ||
                    return false, "Unexpected slack variable count on interval constraint $(ci.value)"
            else
                return false,
                "Unsupported slack variable on constraint $(ci.value) for incumbent lifting"
            end
        end
    end

    return true, nothing
end

function _lift_candidate_assignment(
    model::Virtual.Model{T},
    cand_q::Dict{VI,Rational{BigInt}},
    arch::AbstractArchitecture,
)::Tuple{Union{Dict{VI,Int},Nothing},Bool,Bool,Union{String,Nothing}} where {T}
    for (ci, _) in model.g
        method = Attributes.constraint_encoding_method(model, ci)
        if !(method isa Attributes.QuadraticPenalty)
            return nothing,
            false,
            false,
            "Constraint $(ci.value) uses non-exact penalty method $(nameof(typeof(method)))"
        end
    end

    if MOI.get(model, Attributes.Quadratize()) ||
       PBO.degree(model.f) > 2 ||
       any(p -> PBO.degree(p) > 2, values(model.g)) ||
       any(p -> PBO.degree(p) > 2, values(model.h)) ||
       any(p -> PBO.degree(p) > 2, values(model.s))
        return nothing,
        false,
        false,
        "Higher-order quadratization is not supported for certified incumbent penalty tightening"
    end

    disc_ok, disc_reason = _check_exact_discretizations(model, arch)
    if !disc_ok
        return nothing, false, false, disc_reason
    end

    y_inc = Dict{VI,Int}()

    for ci in MOI.get(
        model.source_model,
        MOI.ListOfConstraintIndices{MOI.VectorOfVariables,MOI.SOS1{T}}(),
    )
        if haskey(model.slack, ci)
            v = model.slack[ci]
            if Virtual.encoding(v) isa Encoding.DomainWall
                f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
                targets = Virtual.target(v)
                active_idx = findfirst(vi -> cand_q[vi] == 1, f.variables)
                k = isnothing(active_idx) ? 0 : active_idx
                for (i, yi) in enumerate(targets)
                    y_inc[yi] = (i <= k ? 1 : 0)
                end
            end
        end
    end

    for vi in _source_variables_in_order(model)
        if !haskey(model.source, vi)
            return nothing, false, false, "Source variable $(vi.value) has not been encoded"
        end

        v = model.source[vi]
        targets = Virtual.target(v)
        if !isempty(targets) || any(y -> !haskey(y_inc, y), keys(Virtual.expansion(v)))
            ok, reason = _lift_encoded_variable!(y_inc, v, cand_q[vi]; is_slack = false)
            if !ok
                return nothing, false, false, reason
            end
        end

        if _eval_pbf_rational(Virtual.expansion(v), y_inc) != cand_q[vi]
            return nothing,
            false,
            false,
            "Lifted target state does not reproduce candidate value for variable $(vi.value)"
        end

        if haskey(model.h, vi) && _eval_pbf_rational(model.h[vi], y_inc) != 0
            return nothing,
            true,
            false,
            "Lifted target state has nonzero variable encoding penalty for variable $(vi.value)"
        end
    end

    slack_ok, slack_reason = _lift_constraint_slacks!(model, y_inc, arch)
    if !slack_ok
        return nothing, false, false, slack_reason
    end

    for yi in MOI.get(model.target_model, MOI.ListOfVariableIndices())
        if !haskey(y_inc, yi) || !(y_inc[yi] == 0 || y_inc[yi] == 1)
            return nothing,
            false,
            false,
            "Lifted target state is missing target binary variable $(yi.value)"
        end
    end

    for (vi, h) in model.h
        if _eval_pbf_rational(h, y_inc) != 0
            return nothing,
            true,
            false,
            "Generated variable encoding penalty for variable $(vi.value) is nonzero at candidate"
        end
    end

    for (ci, s) in model.s
        if _eval_pbf_rational(s, y_inc) != 0
            return nothing,
            true,
            false,
            "Generated slack encoding penalty for constraint $(ci.value) is nonzero at candidate"
        end
    end

    for (ci, g) in model.g
        if _eval_pbf_rational(g, y_inc) != 0
            return nothing,
            true,
            false,
            "Generated constraint penalty for constraint $(ci.value) is nonzero at candidate"
        end
    end

    return y_inc, true, true, nothing
end

function _pbf_to_rational(
    p::PBO.PBF{VI,T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    q = PBO.PBF{VI,Rational{BigInt}}()

    for (ω, c) in p
        cq = _exact_rational(c)
        isnothing(cq) && return nothing

        if !iszero(cq)
            q[ω] = cq
        end
    end

    return q
end

function _pbf_matches_exact_rational(
    p::PBO.PBF{VI,T},
    q_exact::PBO.PBF{VI,Rational{BigInt}},
)::Bool where {T}
    p_q = _pbf_to_rational(p)
    return !isnothing(p_q) && p_q == q_exact
end

function _is_positive_rational_multiple(
    a::PBO.PBF{VI,Rational{BigInt}},
    b::PBO.PBF{VI,Rational{BigInt}},
)::Bool
    isempty(a) && isempty(b) && return true
    scale_q = nothing

    for ω in union(keys(a), keys(b))
        ca = a[ω]
        cb = b[ω]

        if iszero(ca) && iszero(cb)
            continue
        elseif iszero(ca) || iszero(cb)
            return false
        end

        ratio = ca // cb
        ratio > 0 || return false

        if isnothing(scale_q)
            scale_q = ratio
        elseif scale_q != ratio
            return false
        end
    end

    return !isnothing(scale_q)
end

function _pbf_all_coeff_gcd(q::PBO.PBF{VI,Rational{BigInt}})::Rational{BigInt}
    g_q = zero(Rational{BigInt})

    for (_, c) in q
        g_q = gcd(g_q, c)
    end

    return g_q
end

function _parse_function_exact_rational(
    model::Virtual.Model{T},
    vi::VI,
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    haskey(model.source, vi) || return nothing
    return _pbf_to_rational(Virtual.expansion(model.source[vi]))
end

function _parse_function_exact_rational(
    model::Virtual.Model{T},
    f::SAF{T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    c0 = _exact_rational(f.constant)
    isnothing(c0) && return nothing
    g = PBO.PBF{VI,Rational{BigInt}}(c0)

    for a in f.terms
        ca = _exact_rational(a.coefficient)
        isnothing(ca) && return nothing
        haskey(model.source, a.variable) || return nothing
        ξ_q = _pbf_to_rational(Virtual.expansion(model.source[a.variable]))
        isnothing(ξ_q) && return nothing

        for (ω, d) in ξ_q
            g[ω] += ca * d
        end
    end

    return g
end

function _parse_function_exact_rational(
    model::Virtual.Model{T},
    f::SQF{T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    c0 = _exact_rational(f.constant)
    isnothing(c0) && return nothing
    g = PBO.PBF{VI,Rational{BigInt}}(c0)

    for q in f.quadratic_terms
        cq = _exact_rational(q.coefficient)
        isnothing(cq) && return nothing
        (haskey(model.source, q.variable_1) && haskey(model.source, q.variable_2)) ||
            return nothing

        if q.variable_1 === q.variable_2
            cq //= 2
        end

        ξ_i = _pbf_to_rational(Virtual.expansion(model.source[q.variable_1]))
        ξ_j = _pbf_to_rational(Virtual.expansion(model.source[q.variable_2]))
        (isnothing(ξ_i) || isnothing(ξ_j)) && return nothing

        for (ωi, di) in ξ_i, (ωj, dj) in ξ_j
            g[PBO.varmul(ωi, ωj)] += cq * di * dj
        end
    end

    for a in f.affine_terms
        ca = _exact_rational(a.coefficient)
        isnothing(ca) && return nothing
        haskey(model.source, a.variable) || return nothing
        ξ_q = _pbf_to_rational(Virtual.expansion(model.source[a.variable]))
        isnothing(ξ_q) && return nothing

        for (ω, d) in ξ_q
            g[ω] += ca * d
        end
    end

    return g
end

function _parse_function_exact_rational(
    ::Virtual.Model,
    ::MOI.AbstractFunction,
)
    return nothing
end

function _parse_set_exact_rational(
    model::Virtual.Model{T},
    f::Union{SAF{T},SQF{T}},
    s::EQ{T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    g = _parse_function_exact_rational(model, f)
    rhs = _exact_rational(s.value)
    (isnothing(g) || isnothing(rhs)) && return nothing
    g[nothing] -= rhs
    return g
end

function _parse_set_exact_rational(
    model::Virtual.Model{T},
    f::Union{SAF{T},SQF{T}},
    s::LT{T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    g = _parse_function_exact_rational(model, f)
    rhs = _exact_rational(s.upper)
    (isnothing(g) || isnothing(rhs)) && return nothing
    g[nothing] -= rhs
    return g
end

function _parse_set_exact_rational(
    model::Virtual.Model{T},
    f::Union{SAF{T},SQF{T}},
    s::GT{T},
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    g = _parse_function_exact_rational(model, f)
    rhs = _exact_rational(s.lower)
    (isnothing(g) || isnothing(rhs)) && return nothing
    g[nothing] -= rhs
    return g
end

function _parse_objective_exact_rational(
    model::Virtual.Model{T},
    f_obj::MOI.AbstractScalarFunction,
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    if !Attributes._has_custom_objective_scalarization(model)
        return _parse_function_exact_rational(model, f_obj)
    end

    f_q = _parse_function_exact_rational(model, f_obj)
    isnothing(f_q) && return nothing

    w_q = _exact_rational(Attributes.objective_weight(model, 1))
    isnothing(w_q) && return nothing

    target_sense = MOI.get(model.target_model, MOI.ObjectiveSense())
    s_1 = Attributes.objective_sense(model, 1)
    rel_sign_q = s_1 === target_sense ? one(Rational{BigInt}) : -one(Rational{BigInt})
    scale_q = rel_sign_q * w_q

    total_q = PBO.PBF{VI,Rational{BigInt}}()
    iszero(scale_q) && return total_q

    for (ω, c) in f_q
        total_q[ω] += scale_q * c
    end

    return total_q
end

function _parse_objective_exact_rational(
    model::Virtual.Model{T},
    f_obj::MOI.AbstractVectorFunction,
)::Union{PBO.PBF{VI,Rational{BigInt}},Nothing} where {T}
    total_q = PBO.PBF{VI,Rational{BigInt}}()
    target_sense = MOI.get(model.target_model, MOI.ObjectiveSense())

    for (i, f_i) in enumerate(MOI.Utilities.eachscalar(f_obj))
        f_i_q = _parse_function_exact_rational(model, f_i)
        isnothing(f_i_q) && return nothing

        w_q = _exact_rational(Attributes.objective_weight(model, i))
        isnothing(w_q) && return nothing

        s_i = Attributes.objective_sense(model, i)
        rel_sign_q = s_i === target_sense ? one(Rational{BigInt}) : -one(Rational{BigInt})
        scale_q = rel_sign_q * w_q

        iszero(scale_q) && continue

        for (ω, c) in f_i_q
            total_q[ω] += scale_q * c
        end
    end

    return total_q
end

function _parse_objective_exact_rational(
    ::Virtual.Model,
    ::MOI.AbstractFunction,
)
    return nothing
end

function _eval_source_objective_rational(
    model::Virtual.Model{T},
    f_obj::MOI.AbstractScalarFunction,
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Rational{BigInt},Nothing} where {T}
    val_q = _eval_source_function_rational(f_obj, cand_q)
    isnothing(val_q) && return nothing

    if !Attributes._has_custom_objective_scalarization(model)
        return val_q
    end

    w_q = _exact_rational(Attributes.objective_weight(model, 1))
    isnothing(w_q) && return nothing

    target_sense = MOI.get(model.target_model, MOI.ObjectiveSense())
    s_1 = Attributes.objective_sense(model, 1)
    rel_sign_q = s_1 === target_sense ? one(Rational{BigInt}) : -one(Rational{BigInt})

    return (rel_sign_q * w_q) * val_q
end

function _eval_source_objective_rational(
    model::Virtual.Model{T},
    f_obj::MOI.AbstractVectorFunction,
    cand_q::Dict{VI,Rational{BigInt}},
)::Union{Rational{BigInt},Nothing} where {T}
    vals_q = _eval_source_function_rational(f_obj, cand_q)
    isnothing(vals_q) && return nothing

    total_q = zero(Rational{BigInt})
    target_sense = MOI.get(model.target_model, MOI.ObjectiveSense())

    for (i, val_q) in enumerate(vals_q)
        w_q = _exact_rational(Attributes.objective_weight(model, i))
        isnothing(w_q) && return nothing

        s_i = Attributes.objective_sense(model, i)
        rel_sign_q = s_i === target_sense ? one(Rational{BigInt}) : -one(Rational{BigInt})

        total_q += (rel_sign_q * w_q) * val_q
    end

    return total_q
end

function _eval_source_objective_rational(
    ::Virtual.Model,
    ::MOI.AbstractFunction,
    ::Dict{VI,Rational{BigInt}},
)
    return nothing
end

function _verify_objective_exact_rational(
    model::Virtual.Model{T},
)::Tuple{Bool,Union{String,Nothing}} where {T}
    F_obj = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
    f_obj = MOI.get(model.source_model, MOI.ObjectiveFunction{F_obj}())
    f_exact_q = _parse_objective_exact_rational(model, f_obj)

    if isnothing(f_exact_q) || !_pbf_matches_exact_rational(model.f, f_exact_q)
        return false,
        "Compiled objective polynomial was rounded in floating-point arithmetic and cannot be certified as exact"
    end

    return true, nothing
end

function _pbf_min_and_positive_gap_enumerated(
    p::PBO.PBF{VI,T},
    vars::Vector{VI},
)::Union{Tuple{Rational{BigInt},Union{Rational{BigInt},Nothing}},Nothing} where {T}
    n = length(vars)
    state = Dict{VI,Int}(v => 0 for v in vars)
    min_val = nothing
    min_pos = nothing

    for mask = 0:((1 << n) - 1)
        for i = 1:n
            state[vars[i]] = (mask >> (i - 1)) & 1
        end
        val = _eval_pbf_rational(p, state)
        isnothing(val) && return nothing

        if isnothing(min_val) || val < min_val
            min_val = val
        end
        if val > 0 && (isnothing(min_pos) || val < min_pos)
            min_pos = val
        end
    end

    isnothing(min_val) && return nothing
    return min_val, min_pos
end

function _certify_nonnegative_linear_or_square_gap(
    p_q::PBO.PBF{VI,Rational{BigInt}},
    lower_bound_gap_q::Rational{BigInt},
)::Union{Rational{BigInt},Nothing}
    vars = PBO.variables(p_q)
    if length(vars) <= 10
        enum_res = _pbf_min_and_positive_gap_enumerated(p_q, vars)
        isnothing(enum_res) && return nothing
        min_val_q, min_pos_q = enum_res
        min_val_q < 0 && return nothing
        return min_pos_q
    end

    g_all = _pbf_all_coeff_gcd(p_q)
    certified_gap = max(lower_bound_gap_q, g_all)
    return certified_gap > 0 ? certified_gap : nothing
end

function _certify_encoding_penalty_rational(
    v::Virtual.Variable{T},
    p::PBO.PBF{VI,T},
    kind::String,
    id::Integer,
)::Tuple{Union{Rational{BigInt},Nothing},Union{String,Nothing}} where {T}
    e = Virtual.encoding(v)
    targets = Virtual.target(v)
    n = length(targets)
    n >= 2 || return nothing, "Encoding penalty on $(kind) $(id) has fewer than 2 target variables"

    if e isa Encoding.OneHot
        r_oh = PBO.PBF{VI,Rational{BigInt}}([targets; -one(Rational{BigInt})])
        χ_exact = r_oh^2
        if !_pbf_matches_exact_rational(p, χ_exact)
            return nothing,
            "OneHot penalty polynomial on $(kind) $(id) was rounded in floating-point arithmetic"
        end
        return one(Rational{BigInt}), nothing
    elseif e isa Encoding.DomainWall
        χ_exact = PBO.PBF{VI,Rational{BigInt}}(
            [
                [targets[i] => 2 // 1 for i = 2:n]
                [(targets[i], targets[i+1]) => -2 // 1 for i = 1:(n-1)]
            ],
        )
        if !_pbf_matches_exact_rational(p, χ_exact)
            return nothing,
            "DomainWall penalty polynomial on $(kind) $(id) was rounded in floating-point arithmetic"
        end
        return 2 // 1, nothing
    else
        return nothing,
        "Unsupported encoding penalty $(nameof(typeof(e))) on $(kind) $(id) for exact certification"
    end
end

function _certify_scalar_inequality_piece_rational(
    model::Virtual.Model{T},
    f::Union{SAF{T},SQF{T}},
    s::Union{LT{T},GT{T}},
    slack_var::Union{Virtual.Variable{T},Nothing},
    arch::AbstractArchitecture,
    ci_id::Integer,
)::Tuple{
    Union{PBO.PBF{VI,Rational{BigInt}},Nothing},
    Union{Rational{BigInt},Nothing},
    Union{String,Nothing},
} where {T}
    r_raw_q = _parse_set_exact_rational(model, f, s)
    isnothing(r_raw_q) &&
        return nothing, nothing, "Constraint $(ci_id) residual could not be parsed in exact arithmetic"

    g_disc = _parse(model, f, s, arch)
    Attributes.discretize(model) && _discretize!(g_disc)
    r_disc_q = _pbf_to_rational(g_disc)

    if isnothing(r_disc_q) || !_is_positive_rational_multiple(r_disc_q, r_raw_q)
        return nothing,
        nothing,
        "Constraint $(ci_id) residual was rounded in floating-point arithmetic or discretization"
    end

    if isnothing(slack_var)
        g_piece_q = s isa LT{T} ? r_disc_q : -r_disc_q
        l_q, _ = PBO.bounds(g_piece_q)
        if l_q < 0
            return nothing,
            nothing,
            "Constraint $(ci_id) linear inequality penalty is not nonnegative over the encoded domain"
        end
        g_r = _pbf_all_coeff_gcd(g_piece_q)
        gap_q = _certify_nonnegative_linear_or_square_gap(g_piece_q, g_r)
        isnothing(gap_q) &&
            return nothing, nothing, "Constraint $(ci_id) positive gap could not be certified"
        return g_piece_q, gap_q, nothing
    else
        ξ_z_q = _pbf_to_rational(Virtual.expansion(slack_var))
        isnothing(ξ_z_q) &&
            return nothing, nothing, "Constraint $(ci_id) slack expansion is not exact"
        l_z, _ = PBO.bounds(ξ_z_q)
        if l_z < 0
            return nothing,
            nothing,
            "Constraint $(ci_id) slack expansion takes negative values"
        end
        r_aug_q = s isa LT{T} ? (r_disc_q + ξ_z_q) : (r_disc_q - ξ_z_q)
        g_piece_q = r_aug_q^2
        g_r = _pbf_all_coeff_gcd(r_aug_q)
        gap_q = _certify_nonnegative_linear_or_square_gap(g_piece_q, g_r^2)
        isnothing(gap_q) &&
            return nothing, nothing, "Constraint $(ci_id) positive gap could not be certified"
        return g_piece_q, gap_q, nothing
    end
end

function _certify_constraint_penalty_rational(
    model::Virtual.Model{T},
    ci::CI,
    p::PBO.PBF{VI,T},
    arch::AbstractArchitecture,
)::Tuple{Union{Rational{BigInt},Nothing},Union{String,Nothing}} where {T}
    id = ci.value
    method = Attributes.constraint_encoding_method(model, ci)
    if !(method isa Attributes.QuadraticPenalty)
        return nothing, "Constraint $(id) uses non-exact penalty method $(nameof(typeof(method)))"
    end

    p_q = _pbf_to_rational(p)
    isnothing(p_q) &&
        return nothing, "Constraint $(id) penalty coefficients are not finite in exact arithmetic"

    f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
    s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)

    if f isa Union{SAF{T},SQF{T}} && s isa EQ{T}
        r_raw_q = _parse_set_exact_rational(model, f, s)
        isnothing(r_raw_q) &&
            return nothing, "Constraint $(id) residual could not be parsed in exact arithmetic"

        g_disc = _parse(model, f, s, arch)
        Attributes.discretize(model) && _discretize!(g_disc)
        r_disc_q = _pbf_to_rational(g_disc)

        if isnothing(r_disc_q) || !_is_positive_rational_multiple(r_disc_q, r_raw_q)
            return nothing,
            "Constraint $(id) residual was rounded in floating-point arithmetic or discretization and does not preserve the exact constraint zero set"
        end

        if f isa SQF{T} && !_is_nonnegative(g_disc) &&
           !isnothing(_boolean_logic_gadget_penalty(model, f, g_disc))
            vars = sort!(
                collect(union(PBO.variables(p_q), PBO.variables(r_raw_q)));
                by = v -> v.value,
            )
            length(vars) <= 10 ||
                return nothing, "Boolean gadget on constraint $(id) exceeds variable bound"
            state = Dict{VI,Int}(v => 0 for v in vars)
            min_pos_q = nothing
            for mask = 0:((1 << length(vars)) - 1)
                for i = 1:length(vars)
                    state[vars[i]] = (mask >> (i - 1)) & 1
                end
                pv = _eval_pbf_rational(p_q, state)
                rv = _eval_pbf_rational(r_raw_q, state)
                (isnothing(pv) || isnothing(rv)) &&
                    return nothing, "Constraint $(id) gadget evaluation failed"
                if pv < 0 || (pv == 0) != (rv == 0)
                    return nothing,
                    "Constraint $(id) gadget penalty does not preserve the exact constraint zero set"
                end
                if pv > 0 && (isnothing(min_pos_q) || pv < min_pos_q)
                    min_pos_q = pv
                end
            end
            isnothing(min_pos_q) &&
                return nothing, "Constraint $(id) gadget penalty has no positive violation gap"
            return min_pos_q, nothing
        elseif _is_nonnegative(g_disc)
            if p_q != r_disc_q
                return nothing,
                "Constraint $(id) penalty polynomial was rounded in floating-point arithmetic"
            end
            l_q, _ = PBO.bounds(r_disc_q)
            if l_q < 0
                return nothing,
                "Constraint $(id) linear equality penalty is not nonnegative over the encoded domain"
            end
            g_r = _pbf_all_coeff_gcd(r_disc_q)
            min_pos_q = _certify_nonnegative_linear_or_square_gap(r_disc_q, g_r)
            isnothing(min_pos_q) &&
                return nothing, "Constraint $(id) positive gap could not be certified"
            return min_pos_q, nothing
        else
            g_exact_q = r_disc_q^2
            if p_q != g_exact_q
                return nothing,
                "Constraint $(id) squared penalty polynomial was rounded in floating-point arithmetic and does not preserve the exact constraint zero set"
            end
            g_r = _pbf_all_coeff_gcd(r_disc_q)
            min_pos_q = _certify_nonnegative_linear_or_square_gap(g_exact_q, g_r^2)
            isnothing(min_pos_q) &&
                return nothing, "Constraint $(id) positive gap could not be certified"
            return min_pos_q, nothing
        end
    elseif f isa Union{SAF{T},SQF{T}} && s isa Union{LT{T},GT{T}}
        slack_vars = [v for v in model.variables if Virtual.source(v) == ci]
        length(slack_vars) <= 1 ||
            return nothing, "Unexpected slack variable count on constraint $(id)"
        slack_var = isempty(slack_vars) ? nothing : only(slack_vars)
        g_piece_q, min_pos_q, reason =
            _certify_scalar_inequality_piece_rational(model, f, s, slack_var, arch, id)
        isnothing(g_piece_q) && return nothing, reason
        if p_q != g_piece_q
            return nothing,
            "Constraint $(id) inequality penalty polynomial was rounded in floating-point arithmetic"
        end
        return min_pos_q, nothing
    elseif f isa Union{SAF{T},SQF{T}} && s isa MOI.Interval{T}
        slack_vars = [v for v in model.variables if Virtual.source(v) == ci]
        idx = 1
        g_total_q = PBO.PBF{VI,Rational{BigInt}}()
        min_piece_gap_q = nothing

        s_lt = LT{T}(s.upper)
        g_lt = _parse(model, f, s_lt, arch)
        Attributes.discretize(model) && _discretize!(g_lt)
        _, u_lt = PBO.bounds(g_lt)
        if !(u_lt <= zero(T) && Attributes.ignore_feasible_constraints(model))
            slack_lt = if !_is_nonnegative(g_lt)
                idx <= length(slack_vars) ||
                    return nothing, "Missing LessThan slack variable on interval constraint $(id)"
                sv = slack_vars[idx]
                idx += 1
                sv
            else
                nothing
            end
            g_lt_q, gap_lt_q, reason_lt =
                _certify_scalar_inequality_piece_rational(model, f, s_lt, slack_lt, arch, id)
            isnothing(g_lt_q) && return nothing, reason_lt
            for (ω, c) in g_lt_q
                g_total_q[ω] += c
            end
            min_piece_gap_q = gap_lt_q
        else
            r_lt_raw_q = _parse_set_exact_rational(model, f, s_lt)
            bounds_lt_q = isnothing(r_lt_raw_q) ? nothing : _pbf_bounds_rational(r_lt_raw_q)
            if isnothing(bounds_lt_q) || bounds_lt_q[2] > 0
                return nothing,
                "Constraint $(id) upper interval bound was omitted but is not unconditionally satisfied in exact arithmetic"
            end
        end

        s_gt = GT{T}(s.lower)
        g_gt = _parse(model, f, s_gt, arch)
        Attributes.discretize(model) && _discretize!(g_gt)
        l_gt, _ = PBO.bounds(g_gt)
        if !(l_gt >= zero(T) && Attributes.ignore_feasible_constraints(model))
            slack_gt = if !_is_nonpositive(g_gt)
                idx <= length(slack_vars) ||
                    return nothing, "Missing GreaterThan slack variable on interval constraint $(id)"
                sv = slack_vars[idx]
                idx += 1
                sv
            else
                nothing
            end
            g_gt_q, gap_gt_q, reason_gt =
                _certify_scalar_inequality_piece_rational(model, f, s_gt, slack_gt, arch, id)
            isnothing(g_gt_q) && return nothing, reason_gt
            for (ω, c) in g_gt_q
                g_total_q[ω] += c
            end
            min_piece_gap_q =
                isnothing(min_piece_gap_q) ? gap_gt_q : min(min_piece_gap_q, gap_gt_q)
        else
            r_gt_raw_q = _parse_set_exact_rational(model, f, s_gt)
            bounds_gt_q = isnothing(r_gt_raw_q) ? nothing : _pbf_bounds_rational(r_gt_raw_q)
            if isnothing(bounds_gt_q) || bounds_gt_q[1] < 0
                return nothing,
                "Constraint $(id) lower interval bound was omitted but is not unconditionally satisfied in exact arithmetic"
            end
        end

        if p_q != g_total_q
            return nothing,
            "Constraint $(id) interval penalty polynomial was rounded in floating-point arithmetic"
        end
        isnothing(min_piece_gap_q) &&
            return nothing, "Constraint $(id) interval penalty has no positive violation gap"
        min_pos_q = _certify_nonnegative_linear_or_square_gap(g_total_q, min_piece_gap_q)
        isnothing(min_pos_q) &&
            return nothing, "Constraint $(id) interval positive gap could not be certified"
        return min_pos_q, nothing
    elseif f isa MOI.VectorOfVariables && s isa MOI.SOS1{T}
        slack_vars = [v for v in model.variables if Virtual.source(v) == ci]
        length(slack_vars) == 1 ||
            return nothing, "Unexpected SOS1 slack variable count on constraint $(id)"
        sv = only(slack_vars)
        if Virtual.encoding(sv) isa Encoding.DomainWall
            min_pos_q, cert_reason =
                _certify_encoding_penalty_rational(sv, p, "constraint", id)
            !isnothing(cert_reason) && return nothing, cert_reason
            sos_targets = Virtual.target(sv)
            expansions_q = PBO.PBF{VI,Rational{BigInt}}[]
            for xi in f.variables
                haskey(model.source, xi) ||
                    return nothing, "SOS1 variable $(xi.value) has not been encoded"
                ξ_q = _pbf_to_rational(Virtual.expansion(model.source[xi]))
                isnothing(ξ_q) && return nothing, "SOS1 variable expansion is not exact"
                issubset(PBO.variables(ξ_q), sos_targets) ||
                    return nothing,
                    "SOS1 variable $(xi.value) expansion is not governed by SOS1 DomainWall targets"
                push!(expansions_q, ξ_q)
            end
            for k = 0:length(sos_targets)
                state = Dict{VI,Int}(
                    sos_targets[j] => (j <= k ? 1 : 0) for j in eachindex(sos_targets)
                )
                vals = Rational{BigInt}[]
                for ξ_q in expansions_q
                    vq = _eval_pbf_rational(ξ_q, state)
                    isnothing(vq) && return nothing, "SOS1 variable evaluation failed"
                    push!(vals, vq)
                end
                _in_source_set_rational(vals, s) ||
                    return nothing,
                    "Constraint $(id) SOS1 DomainWall encoding does not enforce SOS1 across all zero-penalty states"
            end
            return min_pos_q, nothing
        elseif Virtual.encoding(sv) isa Encoding.Mirror && length(Virtual.target(sv)) == 1
            r_sos = PBO.PBF{VI,Rational{BigInt}}(-one(Rational{BigInt}))
            for xi in f.variables
                vi = model.source[xi]
                Virtual.encoding(vi) isa Encoding.Mirror ||
                    return nothing, "Unsupported non-Mirror variable in SOS1 constraint $(id)"
                ξ_q = _pbf_to_rational(Virtual.expansion(vi))
                isnothing(ξ_q) && return nothing, "SOS1 variable expansion is not exact"
                for (ω, c) in ξ_q
                    r_sos[ω] += c
                end
            end
            ξ_z_q = _pbf_to_rational(Virtual.expansion(sv))
            isnothing(ξ_z_q) && return nothing, "SOS1 slack expansion is not exact"
            for (ω, c) in ξ_z_q
                r_sos[ω] += c
            end
            g_exact_q = r_sos^2
            if p_q != g_exact_q
                return nothing,
                "Constraint $(id) SOS1 penalty polynomial was rounded in floating-point arithmetic"
            end
            return one(Rational{BigInt}), nothing
        else
            return nothing, "Unsupported SOS1 slack encoding on constraint $(id)"
        end
    else
        return nothing, "Unsupported constraint type on constraint $(id) for exact certification"
    end
end

function _certify_penalty_function_rational(
    model::Virtual.Model{T},
    kind::String,
    ref::Union{CI,VI},
    p::PBO.PBF{VI,T},
    ϵ::T,
    arch::AbstractArchitecture = GenericArchitecture(),
)::Tuple{Union{Rational{BigInt},Nothing},Union{String,Nothing}} where {T}
    id = ref.value
    if PBO.degree(p) > 2
        return nothing, "Penalty function on $(kind) $(id) has degree > 2 and requires quadratization"
    end

    if !(isfinite(ϵ) && ϵ > zero(T))
        return nothing, "Penalty function positive gap on $(kind) $(id) is not finite and positive"
    end

    ϵ_q = _exact_rational(ϵ)
    isnothing(ϵ_q) && return nothing, "Penalty function positive gap on $(kind) $(id) is not exact"

    min_pos_q, cert_reason = if kind == "constraint"
        ref isa CI || return nothing, "Expected constraint index for constraint $(id)"
        _certify_constraint_penalty_rational(model, ref, p, arch)
    elseif kind == "variable"
        ref isa VI || return nothing, "Expected variable index for variable $(id)"
        haskey(model.source, ref) || return nothing, "Unknown variable $(id)"
        _certify_encoding_penalty_rational(model.source[ref], p, kind, id)
    elseif kind == "slack_variable"
        ref isa CI || return nothing, "Expected constraint index for slack variable $(id)"
        slack_match = get(model.slack, ref, nothing)
        if isnothing(slack_match) || isnothing(Virtual.penaltyfn(slack_match))
            slack_match = nothing
            for v in model.variables
                if Virtual.source(v) == ref && !isnothing(Virtual.penaltyfn(v))
                    slack_match = v
                    break
                end
            end
        end
        isnothing(slack_match) && return nothing, "Unknown slack variable on constraint $(id)"
        _certify_encoding_penalty_rational(slack_match, p, kind, id)
    else
        return nothing, "Unknown penalty kind $(kind)"
    end

    !isnothing(cert_reason) && return nothing, cert_reason
    if isnothing(min_pos_q) || min_pos_q <= 0 || ϵ_q > min_pos_q
        return nothing,
        "Penalty function positive gap on $(kind) $(id) exceeds certified minimum positive value"
    end

    return ϵ_q, nothing
end

function _verify_penalty_scaling_exact(
    p::PBO.PBF{VI,T},
    coeff,
    kind::String,
    id::Integer,
)::Tuple{Bool,Union{String,Nothing}} where {T}
    coeff_q = _exact_rational(coeff)
    (isnothing(coeff) || !isfinite(coeff) || isnothing(coeff_q)) &&
        return false, "Applied penalty on $(kind) $(id) is not finite in exact arithmetic"

    for (_, c) in p
        cq = _exact_rational(c)
        isnothing(cq) &&
            return false, "Penalty polynomial coefficient on $(kind) $(id) is not finite"
        prod_t = T(coeff) * c
        if !isfinite(prod_t) || _exact_rational(prod_t) != coeff_q * cq
            return false,
            "Scaled penalty term on $(kind) $(id) lost precision or overflowed in floating-point arithmetic"
        end
    end

    return true, nothing
end

function _verify_hamiltonian_assembly_exact(
    model::Virtual.Model{T},
    ρ_map::AbstractDict{<:CI,T},
    θ_map::AbstractDict{VI,T},
    η_map::AbstractDict{<:CI,T},
)::Tuple{Bool,Union{String,Nothing}} where {T}
    obj_ok, obj_reason = _verify_objective_exact_rational(model)
    obj_ok || return false, obj_reason

    H_float = PBO.PBF{VI,T}()
    H_exact = PBO.PBF{VI,Rational{BigInt}}()

    for (ω, c) in model.f
        cq = _exact_rational(c)
        isnothing(cq) && return false, "Objective coefficient is not finite in exact arithmetic"
        H_float[ω] += c
        H_exact[ω] += cq
    end

    for (ci, g) in model.g
        haskey(ρ_map, ci) || continue
        ρ = ρ_map[ci]
        ok_scale, scale_reason = _verify_penalty_scaling_exact(g, ρ, "constraint", ci.value)
        ok_scale || return false, scale_reason
        ρ_q = _exact_rational(ρ)::Rational{BigInt}

        for (ω, c) in g
            cq = _exact_rational(c)::Rational{BigInt}
            H_float[ω] += ρ * c
            H_exact[ω] += ρ_q * cq
        end
    end

    for (vi, h) in model.h
        haskey(θ_map, vi) || continue
        θ = θ_map[vi]
        ok_scale, scale_reason = _verify_penalty_scaling_exact(h, θ, "variable", vi.value)
        ok_scale || return false, scale_reason
        θ_q = _exact_rational(θ)::Rational{BigInt}

        for (ω, c) in h
            cq = _exact_rational(c)::Rational{BigInt}
            H_float[ω] += θ * c
            H_exact[ω] += θ_q * cq
        end
    end

    for (ci, s) in model.s
        haskey(η_map, ci) || continue
        η = η_map[ci]
        ok_scale, scale_reason = _verify_penalty_scaling_exact(s, η, "slack_variable", ci.value)
        ok_scale || return false, scale_reason
        η_q = _exact_rational(η)::Rational{BigInt}

        for (ω, c) in s
            cq = _exact_rational(c)::Rational{BigInt}
            H_float[ω] += η * c
            H_exact[ω] += η_q * cq
        end
    end

    if !_pbf_matches_exact_rational(H_float, H_exact)
        return false,
        "Assembled Hamiltonian coefficients lost precision in floating-point arithmetic"
    end

    return true, nothing
end

function _verify_variable_constraint_enforced_rational(
    model::Virtual.Model{T},
    ci::Union{CI,Nothing},
    vi::VI,
    s::Union{MOI.AbstractSet,Nothing},
)::Tuple{Bool,Union{String,Nothing}} where {T}
    cid = isnothing(ci) ? vi.value : ci.value
    haskey(model.source, vi) ||
        return false, "Source variable $(vi.value) has not been encoded"
    v = model.source[vi]
    e = Virtual.encoding(v)
    targets = Virtual.target(v)
    ξ_q = _pbf_to_rational(Virtual.expansion(v))
    isnothing(ξ_q) && return false, "Variable $(vi.value) expansion is not exact"

    γ = Attributes.variable_encoding_set(model, vi)
    γ_q = if !isnothing(γ)
        vals = Rational{BigInt}[]
        for g_val in γ
            gq = _exact_rational(g_val)
            isnothing(gq) &&
                return false, "Variable $(vi.value) value set entry is not exact"
            push!(vals, gq)
        end
        vals
    else
        nothing
    end

    if e isa Encoding.OneHot
        if haskey(model.h, vi)
            ϵ_q, cert_reason =
                _certify_encoding_penalty_rational(v, model.h[vi], "variable", vi.value)
            isnothing(ϵ_q) && return false, cert_reason
            for k in eachindex(targets)
                state = Dict{VI,Int}(targets[j] => (j == k ? 1 : 0) for j in eachindex(targets))
                val_q = _eval_pbf_rational(ξ_q, state)
                if isnothing(val_q) ||
                   (!isnothing(s) && !_in_source_set_rational(val_q, s)) ||
                   (!isnothing(γ_q) && !(val_q in γ_q))
                    return false,
                    "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all zero-penalty encoded states of variable $(vi.value)"
                end
            end
            return true, nothing
        else
            vars = PBO.variables(ξ_q)
            length(vars) <= 10 ||
                return false,
                "Variable $(vi.value) OneHot encoding has no penalty and exceeds variable bound"
            state = Dict{VI,Int}(y => 0 for y in vars)
            for mask = 0:((1 << length(vars)) - 1)
                for i in eachindex(vars)
                    state[vars[i]] = (mask >> (i - 1)) & 1
                end
                val_q = _eval_pbf_rational(ξ_q, state)
                if isnothing(val_q) ||
                   (!isnothing(s) && !_in_source_set_rational(val_q, s)) ||
                   (!isnothing(γ_q) && !(val_q in γ_q))
                    return false,
                    "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all encoded states of variable $(vi.value)"
                end
            end
            return true, nothing
        end
    elseif e isa Encoding.DomainWall
        if !isempty(targets) || isempty(PBO.variables(ξ_q))
            if haskey(model.h, vi)
                ϵ_q, cert_reason =
                    _certify_encoding_penalty_rational(v, model.h[vi], "variable", vi.value)
                isnothing(ϵ_q) && return false, cert_reason
                for k = 0:length(targets)
                    state =
                        Dict{VI,Int}(targets[j] => (j <= k ? 1 : 0) for j in eachindex(targets))
                    val_q = _eval_pbf_rational(ξ_q, state)
                    if isnothing(val_q) ||
                       (!isnothing(s) && !_in_source_set_rational(val_q, s)) ||
                       (!isnothing(γ_q) && !(val_q in γ_q))
                        return false,
                        "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all zero-penalty encoded states of variable $(vi.value)"
                    end
                end
                return true, nothing
            else
                vars = PBO.variables(ξ_q)
                length(vars) <= 10 ||
                    return false,
                    "Variable $(vi.value) DomainWall encoding has no penalty and exceeds variable bound"
                state = Dict{VI,Int}(y => 0 for y in vars)
                for mask = 0:((1 << length(vars)) - 1)
                    for i in eachindex(vars)
                        state[vars[i]] = (mask >> (i - 1)) & 1
                    end
                    val_q = _eval_pbf_rational(ξ_q, state)
                    if isnothing(val_q) ||
                       (!isnothing(s) && !_in_source_set_rational(val_q, s)) ||
                       (!isnothing(γ_q) && !(val_q in γ_q))
                        return false,
                        "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all encoded states of variable $(vi.value)"
                    end
                end
                return true, nothing
            end
        else
            sos_sv = nothing
            sos_ci = nothing
            for (ci_cand, _) in model.g
                sv_cand = get(model.slack, ci_cand, nothing)
                if !isnothing(sv_cand) &&
                   Virtual.encoding(sv_cand) isa Encoding.DomainWall &&
                   issubset(PBO.variables(ξ_q), Virtual.target(sv_cand))
                    sos_sv = sv_cand
                    sos_ci = ci_cand
                    break
                end
            end
            (isnothing(sos_sv) || isnothing(sos_ci)) &&
                return false,
                "SOS1 DomainWall variable $(vi.value) has no certified SOS1 constraint penalty"
            ϵ_q, cert_reason = _certify_encoding_penalty_rational(
                sos_sv,
                model.g[sos_ci],
                "constraint",
                sos_ci.value,
            )
            isnothing(ϵ_q) && return false, cert_reason
            sos_targets = Virtual.target(sos_sv)
            for k = 0:length(sos_targets)
                state = Dict{VI,Int}(
                    sos_targets[j] => (j <= k ? 1 : 0) for j in eachindex(sos_targets)
                )
                val_q = _eval_pbf_rational(ξ_q, state)
                if isnothing(val_q) ||
                   (!isnothing(s) && !_in_source_set_rational(val_q, s)) ||
                   (!isnothing(γ_q) && !(val_q in γ_q))
                    return false,
                    "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all zero-penalty SOS1 states of variable $(vi.value)"
                end
            end
            return true, nothing
        end
    elseif e isa Union{
        Encoding.Mirror,
        Encoding.Binary,
        Encoding.Unary,
        Encoding.Arithmetic,
        Encoding.Bounded,
    }
        if haskey(model.h, vi) || PBO.degree(ξ_q) > 1 || !isnothing(γ_q)
            return false,
            "Unexpected penalty, value set, or nonlinear expansion on variable $(vi.value)"
        end
        isnothing(s) && return true, nothing
        bounds_q = _pbf_bounds_rational(ξ_q)
        isnothing(bounds_q) &&
            return false,
            "Variable $(vi.value) expansion bounds are not finite in exact arithmetic"
        l_q, u_q = bounds_q

        if s isa LT{T}
            upper = _exact_rational(s.upper)
            (!isnothing(upper) && u_q <= upper) ||
                return false,
                "Source variable upper bound on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
            return true, nothing
        elseif s isa GT{T}
            lower = _exact_rational(s.lower)
            (!isnothing(lower) && l_q >= lower) ||
                return false,
                "Source variable lower bound on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
            return true, nothing
        elseif s isa MOI.Interval{T}
            lower = _exact_rational(s.lower)
            upper = _exact_rational(s.upper)
            (!isnothing(lower) && !isnothing(upper) && l_q >= lower && u_q <= upper) ||
                return false,
                "Source variable interval bound on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
            return true, nothing
        elseif s isa EQ{T}
            rhs = _exact_rational(s.value)
            (!isnothing(rhs) && l_q == rhs && u_q == rhs) ||
                return false,
                "Source variable equality constraint on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
            return true, nothing
        elseif s isa MOI.Integer
            all(kv -> denominator(kv[2]) == 1, ξ_q) ||
                return false,
                "Source variable integrality on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
            return true, nothing
        elseif s isa MOI.ZeroOne
            vars = PBO.variables(ξ_q)
            if length(vars) <= 2
                state = Dict{VI,Int}(y => 0 for y in vars)
                for mask = 0:((1 << length(vars)) - 1)
                    for i in eachindex(vars)
                        state[vars[i]] = (mask >> (i - 1)) & 1
                    end
                    val_q = _eval_pbf_rational(ξ_q, state)
                    if isnothing(val_q) || !_in_source_set_rational(val_q, s)
                        return false,
                        "Source variable binary constraint on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
                    end
                end
                return true, nothing
            end
            return false,
            "Source variable binary constraint on variable $(vi.value) (constraint $(cid)) is not enforced across all zero-penalty encoded states"
        else
            return false,
            "Source variable constraint $(cid) ($(VI) in $(typeof(s))) is not enforced across all zero-penalty encoded states"
        end
    else
        return false,
        "Unsupported variable encoding $(nameof(typeof(e))) on variable $(vi.value) for exact certification"
    end
end

function _verify_omitted_constraint_satisfied_rational(
    model::Virtual.Model{T},
    ci::CI,
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
)::Tuple{Bool,Union{String,Nothing}} where {T}
    if f isa Union{SAF{T},SQF{T}} && s isa EQ{T}
        r_raw_q = _parse_set_exact_rational(model, f, s)
        bounds_q = isnothing(r_raw_q) ? nothing : _pbf_bounds_rational(r_raw_q)
        if !isnothing(bounds_q) && bounds_q == (0 // 1, 0 // 1)
            return true, nothing
        end
    elseif f isa Union{SAF{T},SQF{T}} && s isa LT{T}
        r_raw_q = _parse_set_exact_rational(model, f, s)
        bounds_q = isnothing(r_raw_q) ? nothing : _pbf_bounds_rational(r_raw_q)
        if !isnothing(bounds_q) && bounds_q[2] <= 0
            return true, nothing
        end
    elseif f isa Union{SAF{T},SQF{T}} && s isa GT{T}
        r_raw_q = _parse_set_exact_rational(model, f, s)
        bounds_q = isnothing(r_raw_q) ? nothing : _pbf_bounds_rational(r_raw_q)
        if !isnothing(bounds_q) && bounds_q[1] >= 0
            return true, nothing
        end
    elseif f isa Union{SAF{T},SQF{T}} && s isa MOI.Interval{T}
        r_lt_q = _parse_set_exact_rational(model, f, LT{T}(s.upper))
        b_lt_q = isnothing(r_lt_q) ? nothing : _pbf_bounds_rational(r_lt_q)
        r_gt_q = _parse_set_exact_rational(model, f, GT{T}(s.lower))
        b_gt_q = isnothing(r_gt_q) ? nothing : _pbf_bounds_rational(r_gt_q)
        if !isnothing(b_lt_q) && !isnothing(b_gt_q) && b_lt_q[2] <= 0 && b_gt_q[1] >= 0
            return true, nothing
        end
    elseif f isa MOI.VectorOfVariables && s isa MOI.SOS1{T}
        if length(f.variables) <= 1
            return true, nothing
        end
    end

    return false,
    "Source constraint $(ci.value) ($(typeof(f)) in $(typeof(s))) has no generated penalty and is not unconditionally satisfied across all encoded states"
end

function _verify_all_source_constraints_enforced(
    model::Virtual.Model{T},
    ::AbstractArchitecture = GenericArchitecture(),
)::Tuple{Bool,Union{String,Nothing}} where {T}
    for vi in _source_variables_in_order(model)
        haskey(model.source, vi) ||
            return false, "Source variable $(vi.value) has not been encoded"
        γ = Attributes.variable_encoding_set(model, vi)
        if !isnothing(γ)
            ok, reason = _verify_variable_constraint_enforced_rational(
                model,
                nothing,
                vi,
                nothing,
            )
            ok || return false, reason
        end
    end

    for (F, S) in MOI.get(model.source_model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model.source_model, MOI.ListOfConstraintIndices{F,S}())
            f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)
            if F === VI
                ok, reason = _verify_variable_constraint_enforced_rational(model, ci, f, s)
                ok || return false, reason
            elseif !haskey(model.g, ci)
                ok, reason =
                    _verify_omitted_constraint_satisfied_rational(model, ci, f, s)
                ok || return false, reason
            end
        end
    end

    return true, nothing
end

function _verify_stored_coefficients_can_establish_bound(
    model::Virtual.Model{T},
    σ::Int,
    range_t::T,
    range_q::Rational{BigInt},
    arch::AbstractArchitecture = GenericArchitecture(),
)::Tuple{Bool,Union{String,Nothing}} where {T}
    if !isfinite(range_t) || range_t < zero(T)
        return false, "Tightened objective range is not finite in target precision"
    end

    obj_ok, obj_reason = _verify_objective_exact_rational(model)
    obj_ok || return false, obj_reason

    src_ok, src_reason = _verify_all_source_constraints_enforced(model, arch)
    src_ok || return false, src_reason

    ρ_cand_map = Dict{CI,T}()
    θ_cand_map = Dict{VI,T}()
    η_cand_map = Dict{CI,T}()
    check_assembly_in_precheck = true

    for (ci, g) in model.g
        ϵ, _ = _positive_penalty_gap(g)
        ϵ_q, reason = _certify_penalty_function_rational(model, "constraint", ci, g, ϵ, arch)
        isnothing(ϵ_q) && return false, reason

        hint = Attributes.constraint_encoding_penalty_hint(model, ci)
        if isnothing(hint)
            scale = Attributes.constraint_penalty_scale(model, ci)
            offset = Attributes.constraint_penalty_offset(model, ci)
            scale_q = _exact_rational(scale)
            offset_q = _exact_rational(offset)
            (isnothing(scale_q) || isnothing(offset_q)) &&
                return false, "Constraint $(ci.value) penalty scale or offset is not finite"

            ρ_cand = _objective_range_penalty_factor(σ, range_t, ϵ, scale, offset)
            ρ_q = _exact_rational(ρ_cand)
            isnothing(ρ_q) &&
                return false, "Stored coefficient for constraint $(ci.value) is not finite in target precision"

            if scale_q > 0 && scale_q * (range_q + offset_q) > range_q
                if (σ * ρ_q) * ϵ_q <= range_q
                    return false,
                    "Stored coefficient for constraint $(ci.value) cannot establish strict sufficient inequality in target precision"
                end
                ρ_cand_map[ci] = T(ρ_cand)
            else
                check_assembly_in_precheck = false
            end
        else
            check_assembly_in_precheck = false
        end
    end

    for (vi, h) in model.h
        ϵ, _ = _positive_penalty_gap(h)
        ϵ_q, reason = _certify_penalty_function_rational(model, "variable", vi, h, ϵ, arch)
        isnothing(ϵ_q) && return false, reason

        hint = Attributes.variable_encoding_penalty_hint(model, vi)
        if isnothing(hint)
            scale = Attributes.penalty_scale(model)
            offset = Attributes.penalty_offset(model)
            scale_q = _exact_rational(scale)
            offset_q = _exact_rational(offset)
            (isnothing(scale_q) || isnothing(offset_q)) &&
                return false, "Global penalty scale or offset is not finite"

            θ_cand = _objective_range_penalty_factor(σ, range_t, ϵ, scale, offset)
            θ_q = _exact_rational(θ_cand)
            isnothing(θ_q) &&
                return false, "Stored coefficient for variable $(vi.value) is not finite in target precision"

            if scale_q > 0 && scale_q * (range_q + offset_q) > range_q
                if (σ * θ_q) * ϵ_q <= range_q
                    return false,
                    "Stored coefficient for variable $(vi.value) cannot establish strict sufficient inequality in target precision"
                end
                θ_cand_map[vi] = T(θ_cand)
            else
                check_assembly_in_precheck = false
            end
        else
            check_assembly_in_precheck = false
        end
    end

    for (ci, s) in model.s
        ϵ, _ = _positive_penalty_gap(s)
        ϵ_q, reason =
            _certify_penalty_function_rational(model, "slack_variable", ci, s, ϵ, arch)
        isnothing(ϵ_q) && return false, reason

        hint = Attributes.slack_variable_encoding_penalty_hint(model, ci)
        if isnothing(hint)
            scale = Attributes.constraint_penalty_scale(model, ci)
            offset = Attributes.constraint_penalty_offset(model, ci)
            scale_q = _exact_rational(scale)
            offset_q = _exact_rational(offset)
            (isnothing(scale_q) || isnothing(offset_q)) &&
                return false, "Constraint $(ci.value) penalty scale or offset is not finite"

            η_cand = _objective_range_penalty_factor(σ, range_t, ϵ, scale, offset)
            η_q = _exact_rational(η_cand)
            isnothing(η_q) &&
                return false, "Stored slack coefficient for constraint $(ci.value) is not finite in target precision"

            if scale_q > 0 && scale_q * (range_q + offset_q) > range_q
                if (σ * η_q) * ϵ_q <= range_q
                    return false,
                    "Stored slack coefficient for constraint $(ci.value) cannot establish strict sufficient inequality in target precision"
                end
                η_cand_map[ci] = T(η_cand)
            else
                check_assembly_in_precheck = false
            end
        else
            check_assembly_in_precheck = false
        end
    end

    if check_assembly_in_precheck
        asm_ok, asm_reason =
            _verify_hamiltonian_assembly_exact(model, ρ_cand_map, θ_cand_map, η_cand_map)
        asm_ok || return false, asm_reason
    end

    return true, nothing
end

function _sense_label(sense::MOI.OptimizationSense)::String
    if sense === MOI.MAX_SENSE
        return "max"
    elseif sense === MOI.FEASIBILITY_SENSE
        return "feasibility"
    else
        return "min"
    end
end

function _objective_range_and_incumbent_metadata(
    model::Virtual.Model{T},
    arch::AbstractArchitecture,
) where {T}
    sense = MOI.get(model, MOI.ObjectiveSense())
    σ = sense === MOI.MAX_SENSE ? -1 : 1
    sense_str = _sense_label(sense)

    raw_lower, raw_upper = PBO.bounds(model.f)
    raw_range = raw_upper - raw_lower
    raw_finite =
        isfinite(raw_lower) &&
        isfinite(raw_upper) &&
        isfinite(raw_range) &&
        raw_range >= zero(raw_range)
    bounds_q = _pbf_bounds_rational(model.f)

    whole_lower_t, whole_upper_t, whole_range_t, exact_finite = if !isnothing(bounds_q)
        lq, uq = bounds_q
        rq = uq - lq
        lt = _round_down(T, lq)
        ut = _round_up(T, uq)
        rt = _round_up(T, rq)
        fin = isfinite(lt) && isfinite(ut) && isfinite(rt) && rq >= 0 && rt >= zero(T)
        lt, ut, rt, fin
    else
        raw_lower, raw_upper, raw_range, false
    end

    objective_bounds = Dict{String,Any}(
        "source" => "compiled_pbf_bounds",
        "lower" => raw_lower,
        "upper" => raw_upper,
        "range" => raw_range,
        "finite" => raw_finite,
        "sense" => sense_str,
        "whole_domain_lower" => raw_lower,
        "whole_domain_upper" => raw_upper,
        "whole_domain_range" => raw_range,
        "lower_source" => "compiled_pbf_bounds",
        "upper_source" => "compiled_pbf_bounds",
        "incumbent_objective" => nothing,
        "tightened" => false,
        "arithmetic" => !isnothing(bounds_q) ? "exact_rational" : "floating_point",
    )

    incumbent_meta = Dict{String,Any}(
        "provided" => false,
        "status" => "none",
        "valid" => false,
        "source_feasible" => false,
        "representable" => false,
        "zero_penalty" => false,
        "used" => false,
        "tightened" => false,
        "objective" => nothing,
        "selected_bound" => nothing,
        "selected_range" => raw_finite ? raw_range : nothing,
        "whole_domain_range" => raw_finite ? raw_range : nothing,
        "reason" => nothing,
        "fallback_source" => nothing,
    )

    selected_range_q = isnothing(bounds_q) ? nothing : (bounds_q[2] - bounds_q[1])
    provided, _cand_t, cand_q, norm_reason = _resolve_candidate_assignment(model)
    !provided && return objective_bounds, incumbent_meta, selected_range_q

    incumbent_meta["provided"] = true
    incumbent_meta["status"] = "rejected"
    incumbent_meta["fallback_source"] = "compiled_pbf_bounds"

    policy = Attributes.penalty_policy(model)
    if !(policy isa Attributes.ObjectiveRangePenalty)
        incumbent_meta["reason"] = "PenaltyIncumbent requires ObjectiveRangePenalty policy"
        return objective_bounds, incumbent_meta, selected_range_q
    elseif !raw_finite || !exact_finite || isnothing(bounds_q)
        incumbent_meta["reason"] = "Objective bounds are not finite in exact arithmetic"
        return objective_bounds, incumbent_meta, selected_range_q
    elseif !isnothing(norm_reason)
        incumbent_meta["reason"] = norm_reason
        return objective_bounds, incumbent_meta, selected_range_q
    end

    obj_exact_ok, obj_exact_reason = _verify_objective_exact_rational(model)
    if !obj_exact_ok
        incumbent_meta["reason"] = obj_exact_reason
        return objective_bounds, incumbent_meta, selected_range_q
    end

    source_feasible, feas_reason = _validate_source_feasibility_rational(model, cand_q)
    if !source_feasible
        incumbent_meta["reason"] = feas_reason
        return objective_bounds, incumbent_meta, selected_range_q
    end
    incumbent_meta["source_feasible"] = true

    y_inc, representable, zero_penalty, lift_reason =
        _lift_candidate_assignment(model, cand_q, arch)
    incumbent_meta["representable"] = representable
    incumbent_meta["zero_penalty"] = zero_penalty
    if isnothing(y_inc)
        incumbent_meta["reason"] = lift_reason
        return objective_bounds, incumbent_meta, selected_range_q
    end

    F_obj = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
    f_obj = MOI.get(model.source_model, MOI.ObjectiveFunction{F_obj}())
    v_source_q = _eval_source_objective_rational(model, f_obj, cand_q)
    v_compiled_q = _eval_pbf_rational(model.f, y_inc)

    if isnothing(v_source_q) || isnothing(v_compiled_q) || v_source_q != v_compiled_q
        incumbent_meta["reason"] =
            "Compiled objective evaluation does not match exact source objective at candidate"
        return objective_bounds, incumbent_meta, selected_range_q
    end

    lq, uq = bounds_q
    if v_compiled_q < lq || v_compiled_q > uq
        incumbent_meta["reason"] = "Evaluated incumbent objective lies outside whole-domain bounds"
        return objective_bounds, incumbent_meta, selected_range_q
    end

    v_inc_t = σ == 1 ? _round_up(T, v_compiled_q) : _round_down(T, v_compiled_q)
    if !isfinite(v_inc_t)
        incumbent_meta["reason"] = "Evaluated incumbent objective is not finite in target precision"
        return objective_bounds, incumbent_meta, selected_range_q
    end

    incumbent_meta["valid"] = true
    incumbent_meta["objective"] = v_inc_t
    objective_bounds["incumbent_objective"] = v_inc_t

    if σ == 1
        if v_compiled_q >= uq
            incumbent_meta["status"] = "unchanged"
            incumbent_meta["selected_bound"] = raw_upper
            incumbent_meta["selected_range"] = raw_range
            incumbent_meta["reason"] =
                "Incumbent objective does not improve on whole-domain upper bound"
            return objective_bounds, incumbent_meta, selected_range_q
        end

        tight_range_q = v_compiled_q - lq
        tight_range_t = _round_up(T, tight_range_q)
        ok_coeff, coeff_reason = _verify_stored_coefficients_can_establish_bound(
            model,
            σ,
            tight_range_t,
            tight_range_q,
            arch,
        )
        if !ok_coeff
            incumbent_meta["status"] = "rejected"
            incumbent_meta["reason"] = coeff_reason
            return objective_bounds, incumbent_meta, selected_range_q
        end

        objective_bounds["source"] = "verified_incumbent_bounds"
        objective_bounds["lower"] = whole_lower_t
        objective_bounds["upper"] = v_inc_t
        objective_bounds["whole_domain_lower"] = whole_lower_t
        objective_bounds["whole_domain_upper"] = whole_upper_t
        objective_bounds["whole_domain_range"] = whole_range_t
        objective_bounds["upper_source"] = "verified_incumbent"
        objective_bounds["range"] = tight_range_t
        objective_bounds["tightened"] = true

        incumbent_meta["status"] = "accepted"
        incumbent_meta["used"] = true
        incumbent_meta["tightened"] = true
        incumbent_meta["selected_bound"] = v_inc_t
        incumbent_meta["selected_range"] = tight_range_t
        incumbent_meta["whole_domain_range"] = whole_range_t
        incumbent_meta["reason"] = nothing
        incumbent_meta["fallback_source"] = nothing

        return objective_bounds, incumbent_meta, tight_range_q
    else
        if v_compiled_q <= lq
            incumbent_meta["status"] = "unchanged"
            incumbent_meta["selected_bound"] = raw_lower
            incumbent_meta["selected_range"] = raw_range
            incumbent_meta["reason"] =
                "Incumbent objective does not improve on whole-domain lower bound"
            return objective_bounds, incumbent_meta, selected_range_q
        end

        tight_range_q = uq - v_compiled_q
        tight_range_t = _round_up(T, tight_range_q)
        ok_coeff, coeff_reason = _verify_stored_coefficients_can_establish_bound(
            model,
            σ,
            tight_range_t,
            tight_range_q,
            arch,
        )
        if !ok_coeff
            incumbent_meta["status"] = "rejected"
            incumbent_meta["reason"] = coeff_reason
            return objective_bounds, incumbent_meta, selected_range_q
        end

        objective_bounds["source"] = "verified_incumbent_bounds"
        objective_bounds["lower"] = v_inc_t
        objective_bounds["upper"] = whole_upper_t
        objective_bounds["whole_domain_lower"] = whole_lower_t
        objective_bounds["whole_domain_upper"] = whole_upper_t
        objective_bounds["whole_domain_range"] = whole_range_t
        objective_bounds["lower_source"] = "verified_incumbent"
        objective_bounds["range"] = tight_range_t
        objective_bounds["tightened"] = true

        incumbent_meta["status"] = "accepted"
        incumbent_meta["used"] = true
        incumbent_meta["tightened"] = true
        incumbent_meta["selected_bound"] = v_inc_t
        incumbent_meta["selected_range"] = tight_range_t
        incumbent_meta["whole_domain_range"] = whole_range_t
        incumbent_meta["reason"] = nothing
        incumbent_meta["fallback_source"] = nothing

        return objective_bounds, incumbent_meta, tight_range_q
    end
end

function _objective_range_metadata(
    model::Virtual.Model,
    arch::AbstractArchitecture = GenericArchitecture(),
)
    objective_bounds, _, _ = _objective_range_and_incumbent_metadata(model, arch)
    return objective_bounds
end

function _penalty_context(
    model::Virtual.Model,
    arch::AbstractArchitecture = GenericArchitecture(),
)
    policy = Attributes.penalty_policy(model)
    objective_bounds, incumbent_meta, selected_range_q =
        _objective_range_and_incumbent_metadata(model, arch)

    return Dict{String,Any}(
        "policy" => string(nameof(typeof(policy))),
        "objective_bounds" => objective_bounds,
        "incumbent" => incumbent_meta,
        "inferred_penalties" => Dict{String,Any}(
            "constraints" => Dict{String,Any}[],
            "variables" => Dict{String,Any}[],
            "slack_variables" => Dict{String,Any}[],
        ),
        "fallbacks" => Dict{String,Any}[],
        "_selected_range_q" => selected_range_q,
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

function _evaluate_applied_penalty_sufficiency(
    model::Virtual.Model{T},
    context::AbstractDict,
    kind::String,
    ref::Union{CI,VI},
    p::PBO.PBF{VI,T},
    applied_coeff,
    selected_range_q::Union{Rational{BigInt},Nothing},
    σ::Int,
    has_hint::Bool,
    scale,
    offset,
    arch::AbstractArchitecture = GenericArchitecture();
    method_name::Union{String,Nothing} = nothing,
    is_exact_method::Bool = true,
) where {T}
    id = ref.value
    policy = Attributes.penalty_policy(model)
    objective_bounds = context["objective_bounds"]
    ϵ, gap_source = _positive_penalty_gap(p)
    ϵ_json = isfinite(ϵ) ? ϵ : nothing
    coeff_json = (!isnothing(applied_coeff) && isfinite(applied_coeff)) ? applied_coeff : nothing
    scale_json = (!isnothing(scale) && isfinite(scale)) ? scale : nothing
    offset_json = (!isnothing(offset) && isfinite(offset)) ? offset : nothing

    sufficient = false
    reason = nothing

    if !(policy isa Attributes.ObjectiveRangePenalty)
        reason =
            "Policy $(context["policy"]) does not provide an ObjectiveRangePenalty sufficient-bound guarantee"
    elseif !is_exact_method
        reason = "Constraint $(id) uses non-exact penalty method $(method_name)"
    elseif !objective_bounds["finite"] || isnothing(selected_range_q)
        reason = "Objective range is not finite in exact arithmetic"
    else
        ϵ_q, cert_reason = _certify_penalty_function_rational(model, kind, ref, p, ϵ, arch)
        coeff_q = _exact_rational(applied_coeff)
        scale_ok, scale_reason = _verify_penalty_scaling_exact(p, applied_coeff, kind, id)

        if !isnothing(cert_reason)
            reason = cert_reason
        elseif isnothing(coeff_q)
            reason = "Applied penalty on $(kind) $(id) is not finite in exact arithmetic"
        elseif !scale_ok
            reason = scale_reason
        elseif (σ * coeff_q) <= 0
            reason =
                "Applied penalty on $(kind) $(id) does not have the required sign for $(objective_bounds["sense"])imization"
        elseif (σ * coeff_q) * ϵ_q == selected_range_q
            reason =
                "Applied penalty on $(kind) $(id) is at the tied threshold and does not satisfy the strict sufficient inequality"
        elseif (σ * coeff_q) * ϵ_q < selected_range_q
            reason =
                "Applied penalty on $(kind) $(id) does not satisfy the strict sufficient inequality"
        else
            sufficient = true
        end
    end

    entry = Dict{String,Any}(
        "kind" => kind,
        "id" => id,
        "penalty" => coeff_json,
        "epsilon" => ϵ_json,
        "epsilon_source" => gap_source,
        "source" => has_hint ? "explicit_hint" : "inferred",
        "scale" => has_hint ? nothing : scale_json,
        "offset" => has_hint ? nothing : offset_json,
        "sufficient_bound" => sufficient,
        "reason" => reason,
    )

    if !isnothing(method_name)
        entry["method"] = method_name
    end

    return entry, sufficient, reason
end

function _finalize_sufficient_bound_metadata!(
    model::Virtual.Model{T},
    context::AbstractDict,
    σ::Int,
    arch::AbstractArchitecture = GenericArchitecture(),
) where {T}
    selected_range_q = pop!(context, "_selected_range_q", nothing)
    policy = Attributes.penalty_policy(model)
    objective_bounds = context["objective_bounds"]
    incumbent_meta = context["incumbent"]

    applied_constraints = Dict{String,Any}[]
    applied_variables = Dict{String,Any}[]
    applied_slacks = Dict{String,Any}[]

    certified = true
    first_reason = nothing

    if !(policy isa Attributes.ObjectiveRangePenalty)
        certified = false
        first_reason =
            "Policy $(context["policy"]) does not provide an ObjectiveRangePenalty sufficient-bound guarantee"
    elseif !objective_bounds["finite"] || isnothing(selected_range_q)
        certified = false
        first_reason = "Objective range is not finite in exact arithmetic"
    elseif MOI.get(model, Attributes.Quadratize()) ||
           PBO.degree(model.f) > 2 ||
           any(p -> PBO.degree(p) > 2, values(model.g)) ||
           any(p -> PBO.degree(p) > 2, values(model.h)) ||
           any(p -> PBO.degree(p) > 2, values(model.s))
        certified = false
        first_reason =
            "Higher-order quadratization is not supported for certified sufficient-bound guarantees"
    elseif !isempty(context["fallbacks"])
        certified = false
        first_reason = first(context["fallbacks"])["reason"]
    else
        obj_ok, obj_reason = _verify_objective_exact_rational(model)
        if !obj_ok
            certified = false
            first_reason = obj_reason
        else
            src_ok, src_reason = _verify_all_source_constraints_enforced(model, arch)
            if !src_ok
                certified = false
                first_reason = src_reason
            end
        end
    end

    for (ci, g) in sort!(collect(model.g); by = kv -> kv[1].value)
        ρ = MOI.get(model, Attributes.ConstraintEncodingPenalty(), ci)
        has_hint = !isnothing(Attributes.constraint_encoding_penalty_hint(model, ci))
        scale = Attributes.constraint_penalty_scale(model, ci)
        offset = Attributes.constraint_penalty_offset(model, ci)
        method = Attributes.constraint_encoding_method(model, ci)
        method_name = string(nameof(typeof(method)))
        is_exact_method = method isa Attributes.QuadraticPenalty

        entry, ok, reason = _evaluate_applied_penalty_sufficiency(
            model,
            context,
            "constraint",
            ci,
            g,
            ρ,
            selected_range_q,
            σ,
            has_hint,
            scale,
            offset,
            arch;
            method_name = method_name,
            is_exact_method = is_exact_method,
        )
        push!(applied_constraints, entry)

        if !ok && certified
            certified = false
            first_reason = reason
        end
    end

    for (vi, h) in sort!(collect(model.h); by = kv -> kv[1].value)
        θ = MOI.get(model, Attributes.VariableEncodingPenalty(), vi)
        has_hint = !isnothing(Attributes.variable_encoding_penalty_hint(model, vi))
        scale = Attributes.penalty_scale(model)
        offset = Attributes.penalty_offset(model)

        entry, ok, reason = _evaluate_applied_penalty_sufficiency(
            model,
            context,
            "variable",
            vi,
            h,
            θ,
            selected_range_q,
            σ,
            has_hint,
            scale,
            offset,
            arch,
        )
        push!(applied_variables, entry)

        if !ok && certified
            certified = false
            first_reason = reason
        end
    end

    for (ci, s) in sort!(collect(model.s); by = kv -> kv[1].value)
        η = MOI.get(model, Attributes.SlackVariableEncodingPenalty(), ci)
        has_hint = !isnothing(Attributes.slack_variable_encoding_penalty_hint(model, ci))
        scale = Attributes.constraint_penalty_scale(model, ci)
        offset = Attributes.constraint_penalty_offset(model, ci)

        entry, ok, reason = _evaluate_applied_penalty_sufficiency(
            model,
            context,
            "slack_variable",
            ci,
            s,
            η,
            selected_range_q,
            σ,
            has_hint,
            scale,
            offset,
            arch,
        )
        push!(applied_slacks, entry)

        if !ok && certified
            certified = false
            first_reason = reason
        end
    end

    if policy isa Attributes.ObjectiveRangePenalty
        asm_ok, asm_reason =
            _verify_hamiltonian_assembly_exact(model, model.ρ, model.θ, model.η)
        if !asm_ok
            if certified
                certified = false
                first_reason = asm_reason
            end
            for entries in (applied_constraints, applied_variables, applied_slacks)
                for entry in entries
                    if entry["sufficient_bound"] === true
                        entry["sufficient_bound"] = false
                        entry["reason"] = asm_reason
                    end
                end
            end
        end
    end

    context["applied_penalties"] = Dict{String,Any}(
        "constraints" => applied_constraints,
        "variables" => applied_variables,
        "slack_variables" => applied_slacks,
    )

    selected_range_json = objective_bounds["finite"] ? objective_bounds["range"] : nothing
    tightened_certified = certified && (incumbent_meta["tightened"] === true)

    context["sufficient_bound"] = Dict{String,Any}(
        "certified" => certified,
        "tightened" => tightened_certified,
        "bound_source" => objective_bounds["source"],
        "selected_range" => selected_range_json,
        "whole_domain_range" =>
            objective_bounds["finite"] ? objective_bounds["whole_domain_range"] : nothing,
        "reason" => certified ? nothing : first_reason,
    )

    incumbent_meta["sufficient_bound_certified"] = certified
    incumbent_meta["sufficient_bound_reason"] = certified ? nothing : first_reason

    return nothing
end

function penalties!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    # Adjust Sign
    σ = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1

    δ = PBO.maxgap(model.f)
    scan = _objective_penalty_scan(model.f)
    context = _penalty_context(model, arch)

    for (ci, g) in model.g
        ρ = Attributes.constraint_encoding_penalty_hint(model, ci)

        if isnothing(ρ)
            if _uses_augmented_lagrangian(model, ci)
                # The augmented-Lagrangian coefficients (λ, ρ) live inside the
                # method and are already baked into the penalty function; the
                # applied coefficient carries only the sense sign. Record the
                # constraint so the metadata inventory stays complete.
                MOI.set(model, Attributes.ConstraintEncodingPenalty(), ci, T(σ))

                push!(
                    context["inferred_penalties"]["constraints"],
                    Dict{String,Any}(
                        "kind" => "constraint",
                        "id" => ci.value,
                        "penalty" => T(σ),
                        "automatic_policy" => context["policy"],
                        "selected_policy" => "AugmentedLagrangianPenalty",
                    ),
                )

                continue
            elseif _uses_linear_equality_penalty(model, ci)
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
    _finalize_sufficient_bound_metadata!(model, context, σ, arch)
    model.compiler_settings[:penalty_policy_metadata] = context

    return nothing
end
