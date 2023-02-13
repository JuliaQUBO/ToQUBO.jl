function toqubo_constraints!(model::VirtualModel, arch::AbstractArchitecture)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            g = toqubo_constraint(model, f, s, arch)

            if !isnothing(g)
                model.g[ci] = g
            end
        end
    end

    return nothing
end

@doc raw"""
    toqubo_constraint(
        ::VirtualModel{T},
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
function toqubo_constraint(
    ::VirtualModel{T},
    ::VI,
    ::Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},LT{T},GT{T}},
    ::AbstractArchitecture,
) where {T}
    return nothing
end

@doc raw"""
    toqubo_constraint(model::VirtualModel{T}, f::SAF{T}, s::EQ{T}, ::AbstractArchitecture) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{a}'\mathbf{x} - b = 0
\end{array}
```

into 

```math
\left\Vertg(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = \left(\mathbf{a}'\mathbf{x} - b\right)^{2}
```
"""
function toqubo_constraint(
    model::VirtualModel{T},
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Affine Equality Constraint: g(x) = a'x - b = 0
    g = toqubo_parse(model, f, s, arch)

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
    toqubo_constraint(model::VirtualModel{T}, f::SAF{T}, s::LT{T}, ::AbstractArchitecture) where {T}

Turns constraints of the form

```math
\begin{array}{rl}
\text{s.t} & \mathbf{a}'\mathbf{x} - b \le 0
\end{array}
```

into 

```math
\left\Vertg(\mathbf{x})\right\Vert_{\left\lbrace{0}\right\rbrace} = \left(\mathbf{a}'\mathbf{x} - b\right + z)^{2}
```

by adding a slack variable ``z``.
"""
function toqubo_constraint(
    model::VirtualModel{T},
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Affine Inequality Constraint: g(x) = a'x - b ≤ 0 
    g = toqubo_parse(model, f, s, arch)

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
    z = encode!(model, Binary(), nothing, zero(T), abs(l))

    for (ω, c) in expansion(z)
        g[ω] += c
    end

    return g^2
end

function toqubo_constraint(
    model::VirtualModel{T},
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Quadratic Equality Constraint: g(x) = x Q x + a x - b = 0
    g = toqubo_parse(model, f, s, arch)

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
    MOI.set(model, QUADRATIZE(), true)

    return g^2
end

function toqubo_constraint(
    model::VirtualModel{T},
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # Scalar Quadratic Inequality Constraint: g(x) = x Q x + a x - b ≤ 0
    g = toqubo_parse(model, f, s, arch)
    
    PBO.discretize!(g)

    # Bounds & Slack Variable 
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    z = encode!(model, Binary(), nothing, zero(T), abs(l))

    for (ω, c) in expansion(z)
        g[ω] += c
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, QUADRATIZE(), true)

    return g^2
end

function toqubo_constraint(
    model::VirtualModel{T},
    x::MOI.VectorOfVariables,
    ::MOI.SOS1{T},
    ::AbstractArchitecture,
) where {T}
    # Special Ordered Set of Type 1: ∑ x ≤ min x
    g = PBO.PBF{VI,T}()

    for xi in x.variables
        vi = model.source[xi]
        
        # Currently, SOS1 only supports binary variables
        @assert encoding(vi) isa Mirror

        for (ωi, _) in expansion(vi)
            g[ωi] = one(T)
        end
    end

    # Slack variable
    z = expansion(encode!(model, Mirror(), nothing))

    return (g + z - one(T))^2
end

function toqubo_encoding_constraints!(
    model::VirtualModel{T},
    ::AbstractArchitecture,
) where {T}
    for v in model.variables
        if is_aux(v)
            continue
        end
        
        h = penaltyfn(v)

        if !isnothing(h)
            model.h[source(v)] = h
        end
    end

    return nothing
end