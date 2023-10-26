function constraints!(model::Virtual.Model, ::Type{F}, ::Type{S}, arch::AbstractArchitecture) where {F,S}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)
        g = constraint(model, f, s, arch)

        if !isnothing(g)
            model.g[ci] = g
        end
    end

    return nothing
end

function constraints!(model::Virtual.Model, arch::AbstractArchitecture)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        constraints!(model, F, S, arch)
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
    ::VI,
    ::Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},LT{T},GT{T}},
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
"""
function constraint(
    model::Virtual.Model{T},
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Affine Equality Constraint: g(x) = a'x - b = 0
    g = _parse(model, f, s, arch)

    PBO.discretize!(g)

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    return g^2
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

by adding a slack variable ``z``.
"""
function constraint(
    model::Virtual.Model{T},
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≤ 0 
    g = _parse(model, f, s, arch)

    PBO.discretize!(g)

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    # Slack Variable
    x = nothing
    e = MOI.get(model, Attributes.DefaultVariableEncodingMethod())
    S = (zero(T), abs(l))
    z = Encoding.encode!(model, x, e, S)

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
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

"""
function constraint(
    model::Virtual.Model{T},
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Quadratic Equality Constraint: g(x) = x' Q x + a' x - b = 0
    g = _parse(model, f, s, arch)

    PBO.discretize!(g)

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, Attributes.Quadratize(), true)

    return g^2
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

by adding a slack variable ``z``.
"""
function constraint(
    model::Virtual.Model{T},
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Quadratic Inequality Constraint: g(x) = x' Q x + a' x - b ≤ 0
    g = _parse(model, f, s, arch)

    PBO.discretize!(g)

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    # Slack Variable
    x = nothing
    e = MOI.get(model, Attributes.DefaultVariableEncodingMethod())
    S = (zero(T), abs(l))
    z = Encoding.encode!(model, x, e, S)

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
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
    x::MOI.VectorOfVariables,
    ::MOI.SOS1{T},
    ::AbstractArchitecture,
) where {T}
    # Special Ordered Set of Type 1: ∑ x ≤ min x
    g = PBO.PBF{VI,T}()

    for xi in x.variables
        vi = model.source[xi]

        if !(encoding(vi) isa Mirror)
            error("Currently, ToQUBO only supports SOS1 on binary variables")
        end

        for (ωi, _) in Virtual.expansion(vi)
            g[ωi] = one(T)
        end
    end

    # Slack variable
    x = nothing
    e = Encoding.Mirror{T}()
    z = Encoding.encode!(model, x, e)

    for (ω, c) in Virtual.expansion(z)
        g[ω] += c
    end

    g[nothing] += -one(T)

    return g^2
end

function encoding_constraints!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    for v in model.variables
        x = Virtual.source(v)

        if isnothing(x)
            continue
        end

        χ = Virtual.penaltyfn(v)

        if !isnothing(χ)
            model.h[x] = χ
        end
    end

    return nothing
end
