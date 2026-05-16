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

function _is_nonnegative(g::PBO.PBF{VI,T})::Bool where {T}
    l, _ = PBO.bounds(g)

    return l >= zero(T)
end

function _is_nonpositive(g::PBO.PBF{VI,T})::Bool where {T}
    _, u = PBO.bounds(g)

    return u <= zero(T)
end

function _equality_penalty(model::Virtual.Model, ci::CI, g::PBO.PBF)
    if _is_quadratic_penalty(model, ci) && !_is_nonnegative(g)
        return g^2
    else
        return g
    end
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
    # Scalar Affine Equality Constraint: g(x) = a'x - b = 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≤ $(s.value)
        """
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
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
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≤ 0 
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≤ $(s.upper)
        """
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
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
    return _combine_penalties(
        constraint(model, ci, f, LT{T}(s.upper), arch),
        constraint(model, ci, f, GT{T}(s.lower), arch),
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
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≥ 0 
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l > zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≥ $(s.lower)
        """
        return nothing
    elseif u < zero(T) # Infeasible
        @warn "Infeasible constraint detected"
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
residual directly instead of squaring it.
"""
function constraint(
    model::Virtual.Model{T},
    ci::CI,
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Quadratic Equality Constraint: g(x) = x' Q x + a' x - b = 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≤ $(s.value)
        """
        return nothing
    elseif l > zero(T) # Infeasible
        @warn """
        Infeasible constraint detected:
        $(f) ≤ $(s.value)
        """
    end

    if _is_quadratic_penalty(model, ci) && !_is_nonnegative(g)
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
    # Scalar Quadratic Inequality Constraint: g(x) = x' Q x + a' x - b ≤ 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≤ $(s.upper)
        """
        return nothing
    elseif l > zero(T) # Infeasible
        @warn """
        Infeasible constraint detected:
        $(f) ≤ $(s.upper)
        """
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
    return _combine_penalties(
        constraint(model, ci, f, LT{T}(s.upper), arch),
        constraint(model, ci, f, GT{T}(s.lower), arch),
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
    # Scalar Quadratic Inequality Constraint: g(x) = x' Q x + a' x - b ≥ 0
    g = _parse(model, f, s, arch)

    if Attributes.discretize(model)
        PBO.discretize!(g)
    end

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if l > zero(T) # Always feasible
        @warn """
        Always-feasible constraint detected:
        $(f) ≥ $(s.lower)
        """
        return nothing
    elseif u < zero(T) # Infeasible
        @warn "Infeasible constraint detected"
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

    h = constraint(model, ci, g, s.set, arch)

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

    h = constraint(model, ci, g, s.set, arch)

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
