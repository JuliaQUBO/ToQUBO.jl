# Normalize an integral constraint residual by its exact positive coefficient GCD,
# preserving its zeros and sign independently of term iteration order. Use
# arbitrary-precision integers for the GCD so large integral floating-point
# coefficients cannot overflow a machine integer. Fractional residuals retain
# PBO's approximate discretization.
function _discretize!(g::PBO.PBF{VI,T}) where {T}
    if !_is_integer_valued(g)
        return PBO.discretize!(g)
    end

    divisor = BigInt(0)

    for coefficient in values(g)
        divisor = gcd(divisor, BigInt(coefficient))
    end

    if !iszero(divisor)
        scale = T(divisor)
        map!(coefficient -> coefficient / scale, g)
    end

    return g
end

function constraints!(model::Virtual.Model, arch::AbstractArchitecture)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        constraints!(model, F, S, arch)
    end

    return nothing
end

function constraints!(
    model::Virtual.Model,
    ::Type{F},
    ::Type{S},
    arch::AbstractArchitecture,
) where {F,S}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        g = constraint(model, ci, f, s, arch)

        if !isnothing(g)
            model.g[ci] = g
        end
    end

    return nothing
end

function _is_quadratic_penalty(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa Attributes.QuadraticPenalty
end

function _is_unbalanced_penalty(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa Attributes.UnbalancedPenalty
end

function _is_augmented_lagrangian(model::Virtual.Model, ci::CI)::Bool
    return Attributes.constraint_encoding_method(model, ci) isa
           Attributes.AugmentedLagrangianPenalty
end

function _is_nonnegative(g::PBO.PBF{VI,T})::Bool where {T}
    l, _ = PBO.bounds(g)

    return l >= zero(T)
end

function _is_nonpositive(g::PBO.PBF{VI,T})::Bool where {T}
    _, u = PBO.bounds(g)

    return u <= zero(T)
end

# Coefficients carried by a constraint encoding method are converted to the
# model's coefficient type before entering the pseudo-Boolean function: a
# method parameterized on a wider type (for example `BigFloat` coefficients on
# a `Float64` model) would otherwise build a malformed PBF. The conversion can
# overflow or underflow, so the converted value is validated here.
function _method_coefficient(
    model::Virtual.Model{T},
    ci::CI,
    value,
    name::AbstractString;
    positive::Bool = false,
) where {T}
    c = convert(T, value)

    if !isfinite(c) || (positive && !(c > zero(T)))
        compilation_error!(
            model,
            "The $(name) coefficient of constraint '$(ci)' is not representable as a " *
            "finite $(positive ? "positive " : "")$(T) value; got $(value)";
            status = "Non-representable penalty coefficient",
        )
    end

    return c
end

function _equality_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF)
    method = Attributes.constraint_encoding_method(model, ci)

    if method isa Attributes.UnbalancedPenalty
        compilation_error("UnbalancedPenalty only supports inequality constraints")
    elseif method isa Attributes.AugmentedLagrangianPenalty
        # λ·ℓ + ρ·ℓ² — the multiplier term is signed, matching the signed
        # equality residual the subgradient update measures.
        λ = _method_coefficient(model, ci, method.multiplier, "multiplier")
        ρ = _method_coefficient(model, ci, method.rho, "rho"; positive = true)

        return λ * g + ρ * g^2
    elseif method isa Attributes.QuadraticPenalty && !_is_nonnegative(g)
        return g^2
    else
        return g
    end
end

function _augmented_lagrangian_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF, ::LT)
    method =
        Attributes.constraint_encoding_method(model, ci)::Attributes.AugmentedLagrangianPenalty
    λ = _method_coefficient(model, ci, method.multiplier, "multiplier")
    ρ = _method_coefficient(model, ci, method.rho, "rho"; positive = true)

    return λ * g + ρ * g^2
end

function _augmented_lagrangian_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF, ::GT)
    method =
        Attributes.constraint_encoding_method(model, ci)::Attributes.AugmentedLagrangianPenalty
    λ = _method_coefficient(model, ci, method.multiplier, "multiplier")
    ρ = _method_coefficient(model, ci, method.rho, "rho"; positive = true)

    return -λ * g + ρ * g^2
end

function _unbalanced_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF, ::LT)
    method = Attributes.constraint_encoding_method(model, ci)::Attributes.UnbalancedPenalty
    λ₁ = _method_coefficient(model, ci, method.linear, "linear"; positive = true)
    λ₂ = _method_coefficient(model, ci, method.quadratic, "quadratic"; positive = true)

    return λ₁ * g + λ₂ * g^2
end

function _unbalanced_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF, ::GT)
    method = Attributes.constraint_encoding_method(model, ci)::Attributes.UnbalancedPenalty
    λ₁ = _method_coefficient(model, ci, method.linear, "linear"; positive = true)
    λ₂ = _method_coefficient(model, ci, method.quadratic, "quadratic"; positive = true)

    return -λ₁ * g + λ₂ * g^2
end

function _combine_penalties(lhs, rhs)
    if isnothing(lhs)
        return rhs
    elseif isnothing(rhs)
        return lhs
    else
        return lhs + rhs
    end
end

abstract type _ConstraintFeasibilityContext end

struct _DirectConstraintContext <: _ConstraintFeasibilityContext end
struct _IndicatorConstraintContext <: _ConstraintFeasibilityContext end

const _DIRECT_CONSTRAINT = _DirectConstraintContext()
const _INDICATOR_CONSTRAINT = _IndicatorConstraintContext()

function _constraint_message(kind::AbstractString, f, op::AbstractString, rhs)
    return """
    $(kind) constraint detected:
    $(f) $(op) $(rhs)
    """
end

function _constraint_warning(model::Virtual.Model, message::AbstractString)
    if Attributes.warnings(model)
        @warn message
    end

    return nothing
end

function _infeasible_constraint_error!(model::Virtual.Model, message::AbstractString)
    MOI.set(model, Attributes.CompilationStatus(), MOI.INFEASIBLE)
    MOI.set(model, MOI.RawStatusString(), message)

    compilation_error(message)

    return nothing
end

function _handle_feasible_constraint(model::Virtual.Model, message::AbstractString)::Bool
    _constraint_warning(model, message)

    return Attributes.ignore_feasible_constraints(model)
end

function _handle_infeasible_constraint(
    model::Virtual.Model,
    context::_ConstraintFeasibilityContext,
    message::AbstractString,
)
    _constraint_warning(model, message)

    if context isa _DirectConstraintContext && Attributes.error_infeasible_constraints(model)
        _infeasible_constraint_error!(model, message)
    end

    return nothing
end

@doc raw"""
    constraint(
        ::Virtual.Model{T},
        ::VI,
        ::Union{
            MOI.ZeroOne,
            MOI.Integer,
            MOI.Interval{T},
            MOI.LessThan{T},
            MOI.GreaterThan{T}
        },
        ::AbstractArchitecture
    ) where {T}

This method skips bound constraints over variables.
"""
function constraint(
    ::Virtual.Model{T},
    ::CI,
    ::VI,
    ::Union{
        MOI.ZeroOne,
        MOI.Integer,
        MOI.Interval{T},
        MOI.Semicontinuous{T},
        MOI.Semiinteger{T},
        LT{T},
        GT{T},
    },
    ::AbstractArchitecture,
) where {T}
    return nothing
end

@doc raw"""
    constraint(
        model::Virtual.Model{T}, 
        f::SAF{T}, 
        s::EQ{T}, 
        ::AbstractArchitecture
    ) where {T}

Turns constraints of the form

```math

\begin{array}{rl}
\text{s.t} & \mathbf{a}'\mathbf{x} - b = 0
\end{array}

```

into 

```math

\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = \left(\mathbf{a}'\mathbf{x} - b\right)^{2}

```

If the residual is nonnegative over the encoded domain, the compiler uses the
residual directly instead of squaring it.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Affine Equality Constraint: g(x) = a'x - b = 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l == zero(T) && u == zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, "=", s.value),
        )
            return nothing
        end
    elseif u < zero(T) || l > zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, "=", s.value),
        )
    end

    return _equality_penalty(model, ci, g)
end

@doc raw"""
    constraint(
        model::Virtual.Model{T}, 
        f::SAF{T}, 
        s::LT{T}, 
        ::AbstractArchitecture
    ) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{a}'\mathbf{x} - b \le 0
\end{array}
```

into 

```math
\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = (\mathbf{a}'\mathbf{x} - b + z)^{2}

```

when the residual is not already nonnegative. If it is nonnegative over the
encoded domain, the compiler uses the residual directly instead of adding a
slack variable.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≤ 0 
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u <= zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, "<=", s.upper),
        )
            return nothing
        end
    elseif l > zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, "<=", s.upper),
        )
    end

    if _is_unbalanced_penalty(model, ci)
        return _unbalanced_penalty(model, ci, g, s)
    end

    if _is_augmented_lagrangian(model, ci)
        return _augmented_lagrangian_penalty(model, ci, g, s)
    end

    if _is_nonnegative(g)
        return g
    end

    # Slack Variable
    S = (zero(T), abs(l))
    z = if Attributes.discretize(model)
        variable_ℤ!(model, ci, S)
    else
        variable_ℝ!(model, ci, S)
    end

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
    end

    return g^2
end

@doc raw"""

"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::MOI.Interval{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::MOI.Interval{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    return _combine_penalties(
        constraint(model, ci, f, LT{T}(s.upper), arch, context),
        constraint(model, ci, f, GT{T}(s.lower), arch, context),
    )
end

@doc raw"""
    constraint(
        model::Virtual.Model{T}, 
        f::SAF{T}, 
        s::GT{T}, 
        ::AbstractArchitecture
    ) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{a}'\mathbf{x} - b \ge 0
\end{array}
```

into 

```math
\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = (\mathbf{a}'\mathbf{x} - b - z)^{2}

```

when the residual is not already nonpositive. If it is nonpositive over the
encoded domain, the compiler uses the negated residual directly instead of
adding a slack variable.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::GT{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SAF{T},
    s::GT{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≥ 0 
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l >= zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, ">=", s.lower),
        )
            return nothing
        end
    elseif u < zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, ">=", s.lower),
        )
    end

    if _is_unbalanced_penalty(model, ci)
        return _unbalanced_penalty(model, ci, g, s)
    end

    if _is_augmented_lagrangian(model, ci)
        return _augmented_lagrangian_penalty(model, ci, g, s)
    end

    if _is_nonpositive(g)
        return -g
    end

    # Slack Variable
    S = (zero(T), abs(u))
    z = if Attributes.discretize(model)
        variable_ℤ!(model, ci, S)
    else
        variable_ℝ!(model, ci, S)
    end

    for (ω, c) in Virtual.expansion(z)
        g[ω] -= c
    end

    return g^2
end


function _is_binary_source_variable(model::Virtual.Model, xi::VI)::Bool
    haskey(model.source, xi) || return false
    v = model.source[xi]
    return Virtual.encoding(v) isa Encoding.Mirror && length(Virtual.target(v)) == 1
end

function _is_binary_target_variable(model::Virtual.Model, yi::VI)::Bool
    haskey(model.target, yi) || return false
    v = model.target[yi]
    return Virtual.encoding(v) isa Encoding.Mirror && length(Virtual.target(v)) == 1
end

function _has_only_binary_variables(
    model::Virtual.Model{T},
    f::SQF{T},
    g::PBO.PBF{VI,T},
)::Bool where {T}
    for q in f.quadratic_terms
        (_is_binary_source_variable(model, q.variable_1) &&
         _is_binary_source_variable(model, q.variable_2)) || return false
    end

    for a in f.affine_terms
        _is_binary_source_variable(model, a.variable) || return false
    end

    for (ω, _) in g
        for y in ω
            _is_binary_target_variable(model, y) || return false
        end
    end

    return true
end

function _boolean_logic_gadget_penalty(
    model::Virtual.Model{T},
    f::SQF{T},
    g::PBO.PBF{VI,T},
)::Union{Tuple{PBO.PBF{VI,T},Bool},Nothing} where {T}
    _has_only_binary_variables(model, f, g) || return nothing

    n_terms = length(g)
    (n_terms == 2 || n_terms == 3 || n_terms == 4) || return nothing

    const_coeff = zero(T)
    has_const = false
    linear = Pair{VI,T}[]
    quadratic = Pair{Tuple{VI,VI},T}[]

    for (ω, c) in g
        d = length(ω)
        if d == 0
            has_const = true
            const_coeff = c
        elseif d == 1
            push!(linear, only(ω) => c)
        elseif d == 2
            u, v = ω
            push!(quadratic, (u, v) => c)
        else
            return nothing
        end
    end

    one_t = one(T)
    two_t = T(2)
    three_t = T(3)
    four_t = T(4)

    # 1. NOT pattern: ±(a + b - 1) = 0 -> 1 - a - b + 2ab
    if n_terms == 3 && has_const && length(linear) == 2 && isempty(quadratic)
        (a, ca), (b, cb) = linear
        if a != b && (const_coeff == one_t || const_coeff == -one_t) &&
           ca == -const_coeff && cb == -const_coeff
            return (
                PBO.PBF{VI,T}(
                    one_t,
                    a => -one_t,
                    b => -one_t,
                    [a, b] => two_t,
                ),
                false,
            )
        end
        return nothing
    end

    # Remaining patterns (AND, OR, XOR) have no constant term and exactly one quadratic term
    (!has_const && length(quadratic) == 1) || return nothing
    (a, b), q_ab = only(quadratic)
    a != b || return nothing

    # 2. AND pattern: ±(c - a*b) = 0 -> 3c + ab - 2ac - 2bc
    if n_terms == 2 && length(linear) == 1
        c, cc = only(linear)
        if c != a && c != b && (cc == one_t || cc == -one_t) && q_ab == -cc
            return (
                PBO.PBF{VI,T}(
                    c => three_t,
                    [a, b] => one_t,
                    [a, c] => -two_t,
                    [b, c] => -two_t,
                ),
                false,
            )
        end
        return nothing
    end

    # 3. OR and XOR patterns have 3 linear terms over {a, b, c}
    if n_terms == 4 && length(linear) == 3
        ca = zero(T)
        cb = zero(T)
        c_out = nothing
        cc = zero(T)

        for (v, cv) in linear
            if v == a
                ca = cv
            elseif v == b
                cb = cv
            else
                c_out === nothing || return nothing
                c_out = v
                cc = cv
            end
        end

        c_out === nothing && return nothing
        c = c_out::VI
        (ca == one_t || ca == -one_t) || return nothing
        (cb == ca && cc == -ca) || return nothing

        if q_ab == -ca
            # OR pattern: ±(a + b - a*b - c) = 0 -> a + b + c + ab - 2ac - 2bc
            return (
                PBO.PBF{VI,T}(
                    a => one_t,
                    b => one_t,
                    c => one_t,
                    [a, b] => one_t,
                    [a, c] => -two_t,
                    [b, c] => -two_t,
                ),
                false,
            )
        elseif q_ab == -two_t * ca
            # XOR pattern: ±(a + b - 2*a*b - c) = 0 -> a + b + c - 2ab - 2ac - 2bc + 4abc
            return (
                PBO.PBF{VI,T}(
                    a => one_t,
                    b => one_t,
                    c => one_t,
                    [a, b] => -two_t,
                    [a, c] => -two_t,
                    [b, c] => -two_t,
                    [a, b, c] => four_t,
                ),
                true,
            )
        end
    end

    return nothing
end

@doc raw"""
    constraint(
        model::Virtual.Model{T},
        f::SQF{T},
        s::EQ{T},
        arch::AbstractArchitecture,
    ) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b = 0
\end{array}
```

into

```math
\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = (\mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b)^{2}

```

If the residual is nonnegative over the encoded domain, the compiler uses the
residual directly instead of squaring it. When every involved variable is
binary (`Encoding.Mirror`) and the constraint uses `QuadraticPenalty`, standard
Boolean logic residuals (`NOT`, `AND`, `OR`, and `XOR`) emit minimal penalty
gadgets directly.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Quadratic Equality Constraint: g(x) = x' Q x + a' x - b = 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l == zero(T) && u == zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, "=", s.value),
        )
            return nothing
        end
    elseif l > zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, "=", s.value),
        )
    elseif u < zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, "=", s.value),
        )
    end

    if _is_quadratic_penalty(model, ci) && !_is_nonnegative(g)
        gadget = _boolean_logic_gadget_penalty(model, f, g)

        if !isnothing(gadget)
            gadget_pbf, needs_quadratization = gadget

            if needs_quadratization
                MOI.set(model, Attributes.Quadratize(), true)
            end

            return gadget_pbf
        end

        # Tell the compiler that quadratization is necessary
        MOI.set(model, Attributes.Quadratize(), true)
    end

    return _equality_penalty(model, ci, g)
end


@doc raw"""
    constraint(
        model::Virtual.Model{T},
        f::SQF{T},
        s::LT{T},
        arch::AbstractArchitecture,
    ) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b \leq 0
\end{array}
```

into

```math
\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = (\mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b + z)^{2}

```

when the residual is not already nonnegative. If it is nonnegative over the
encoded domain, the compiler uses the residual directly instead of adding a
slack variable.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Quadratic Inequality Constraint: g(x) = x' Q x + a' x - b ≤ 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u <= zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, "<=", s.upper),
        )
            return nothing
        end
    elseif l > zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, "<=", s.upper),
        )
    end

    if _is_unbalanced_penalty(model, ci)
        MOI.set(model, Attributes.Quadratize(), true)

        return _unbalanced_penalty(model, ci, g, s)
    end

    if _is_nonnegative(g)
        return g
    end

    # Slack Variable
    S = (zero(T), abs(l))
    z = if Attributes.discretize(model)
        variable_ℤ!(model, ci, S)
    else
        variable_ℝ!(model, ci, S)
    end

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, Attributes.Quadratize(), true)

    return g^2
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::MOI.Interval{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::MOI.Interval{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    return _combine_penalties(
        constraint(model, ci, f, LT{T}(s.upper), arch, context),
        constraint(model, ci, f, GT{T}(s.lower), arch, context),
    )
end

@doc raw"""
    constraint(
        model::Virtual.Model{T},
        f::SQF{T},
        s::GT{T},
        arch::AbstractArchitecture,
    ) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b \geq 0
\end{array}
```

into

```math
\left\Vert(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = (\mathbf{x}'\mathbf{Q}\mathbf{x} + \mathbf{a}'\mathbf{x} - b - z)^{2}

```

when the residual is not already nonpositive. If it is nonpositive over the
encoded domain, the compiler uses the negated residual directly instead of
adding a slack variable.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::GT{T},
    arch::AbstractArchitecture,
) where {T}
    return constraint(model, ci, f, s, arch, _DIRECT_CONSTRAINT)
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::GT{T},
    arch::AbstractArchitecture,
    context::_ConstraintFeasibilityContext,
) where {T}
    # Scalar Quadratic Inequality Constraint: g(x) = x' Q x + a' x - b ≥ 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        _discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l >= zero(T) # Always feasible
        if _handle_feasible_constraint(
            model,
            _constraint_message("Always-feasible", f, ">=", s.lower),
        )
            return nothing
        end
    elseif u < zero(T) # Infeasible
        _handle_infeasible_constraint(
            model,
            context,
            _constraint_message("Infeasible", f, ">=", s.lower),
        )
    end

    if _is_unbalanced_penalty(model, ci)
        MOI.set(model, Attributes.Quadratize(), true)

        return _unbalanced_penalty(model, ci, g, s)
    end

    if _is_nonpositive(g)
        return -g
    end

    # Slack Variable
    S = (zero(T), abs(u))
    z = if Attributes.discretize(model)
        variable_ℤ!(model, ci, S)
    else
        variable_ℝ!(model, ci, S)
    end

    for (ω, c) in Virtual.expansion(z)
        g[ω] -= c
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, Attributes.Quadratize(), true)

    return g^2
end

@doc raw"""
    constraint(
        model::Virtual.Model{T},
        x::MOI.VectorOfVariables,
        ::MOI.SOS1{T},
        ::AbstractArchitecture,
    ) where {T}
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    x::MOI.VectorOfVariables,
    ::MOI.SOS1{T},
    ::AbstractArchitecture,
) where {T}
    if haskey(model.slack, ci)
        v = model.slack[ci]

        if Virtual.encoding(v) isa Encoding.DomainWall
            return _sos1_domain_wall_penalty(T, Virtual.target(v))
        end
    end

    # Special Ordered Set of Type 1: ∑ x ≤ min x
    g = PBO.PBF{VI,T}()
    h = PBO.PBF{VI,T}()

    for xi in x.variables
        vi = model.source[xi]

        if Virtual.encoding(vi) isa Encoding.Mirror
            for (ω, _) in Virtual.expansion(vi)
                g[ω] = one(T)
            end
        elseif Virtual.encoding(vi) isa Encoding.OneHot ||
               Virtual.encoding(vi) isa Encoding.DomainWall
            ξ = Virtual.expansion(vi)
            a = ξ[nothing]

            ω, c = argmin(p -> abs(last(p) + a), ξ)

            if !((c + a) ≈ zero(T))
                @warn "Variable $(xi) is always non-zero"
            end

            g[ω] = one(T)
        else
            ξ = Virtual.expansion(vi)

            # Slack variable
            e = Encoding.Mirror{T}()
            w = Encoding.encode!(model, ci, e)
            χ = w * ξ^2

            for (ω, c) in χ
                h[ω] += c
            end

            g[w] = one(T)

            # Tell the compiler that quadratization is necessary
            MOI.set(model, Attributes.Quadratize(), true)
        end
    end

    # Slack variable
    z = variable_𝔹!(model, ci)

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
    end

    g[nothing] += -one(T)

    return g^2 + h
end

function _domain_wall_indicator_activation(::Type{T}, ξ::PBO.PBF{VI,T}) where {T}
    if !(ξ[nothing] ≈ zero(T))
        return ξ
    end

    positive = VI[]
    negative = VI[]

    for (ω, c) in ξ
        if isempty(ω)
            continue
        elseif length(ω) != 1
            return ξ
        elseif c ≈ one(T)
            push!(positive, only(ω))
        elseif c ≈ -one(T)
            push!(negative, only(ω))
        else
            return ξ
        end
    end

    if length(positive) == 1 && isempty(negative)
        return PBO.PBF{VI,T}(only(positive))
    elseif length(positive) == 1 && length(negative) == 1
        yi = PBO.PBF{VI,T}(only(positive))
        yj = PBO.PBF{VI,T}(only(negative))

        return yi * (one(T) - yj)
    else
        return ξ
    end
end

function _indicator_activation(model::Virtual.Model{T}, xi::VI) where {T}
    vi = model.source[xi]
    ξ = Virtual.expansion(vi)

    if Virtual.encoding(vi) isa Encoding.DomainWall
        return _domain_wall_indicator_activation(T, ξ)
    else
        return ξ
    end
end

function _indicator_variable(f::MOI.VectorAffineFunction)
    for term in f.terms
        if term.output_index == 1
            return term.scalar_term.variable
        end
    end

    error("Indicator constraint missing activation variable")
end

function _indicator_variable(f::MOI.VectorQuadraticFunction)
    for term in f.affine_terms
        if term.output_index == 1
            return term.scalar_term.variable
        end
    end

    error("Indicator constraint missing activation variable")
end

function _indicator_scalar_constant(::Type{T}, constants::AbstractVector{T}) where {T}
    c = zero(T)

    for i in 2:length(constants)
        c += constants[i]
    end

    return c
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::MOI.VectorAffineFunction{T},
    s::MOI.Indicator{A,S},
    arch::AbstractArchitecture,
) where {T,A,S}
    # Indicator Constraint: y = 0|1 => {g(x)}

    xi = _indicator_variable(f)
    yi = _indicator_activation(model, xi)

    g = MOI.ScalarAffineFunction{T}(
        SAT{T}[term.scalar_term for term in f.terms if term.output_index != 1],
        _indicator_scalar_constant(T, f.constants),
    )

    h = constraint(model, ci, g, s.set, arch, _INDICATOR_CONSTRAINT)

    if isnothing(h)
        return nothing
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, Attributes.Quadratize(), true)

    if A === MOI.ACTIVATE_ON_ONE
        return yi * h
    elseif A === MOI.ACTIVATE_ON_ZERO
        return (one(T) - yi) * h
    else
        error("Indicator constraint activation type $(A) not supported")
    end

    return nothing
end

function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::MOI.VectorQuadraticFunction{T},
    s::MOI.Indicator{A,S},
    arch::AbstractArchitecture,
) where {T,A,S}
    # Indicator Constraint: y = 0|1 => {g(x)}

    xi = _indicator_variable(f)
    yi = _indicator_activation(model, xi)

    g = MOI.ScalarQuadraticFunction{T}(
        SQT{T}[
            term.scalar_term for term in f.quadratic_terms if term.output_index != 1
        ],
        SAT{T}[term.scalar_term for term in f.affine_terms if term.output_index != 1],
        _indicator_scalar_constant(T, f.constants),
    )

    h = constraint(model, ci, g, s.set, arch, _INDICATOR_CONSTRAINT)

    if isnothing(h)
        return nothing
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, Attributes.Quadratize(), true)

    if A === MOI.ACTIVATE_ON_ONE
        return yi * h
    elseif A === MOI.ACTIVATE_ON_ZERO
        return (one(T) - yi) * h
    else
        error("Indicator constraint activation type $(A) not supported")
    end

    return nothing
end
