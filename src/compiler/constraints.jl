function toqubo_constraints!(model::VirtualQUBOModel, arch::AbstractArchitecture)
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

function toqubo_constraint(
    ::VirtualQUBOModel{T},
    ::VI,
    ::Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},LT{T},GT{T}},
    ::AbstractArchitecture,
) where {T} end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # -*- Scalar Affine Function: g(x) = a'x - b = 0 ~ 😄 -*-
    g = PBF{VI,T}()
    
    toqubo_parse!(model, g, f, s, arch)
    
    PBO.discretize!(g)

    # -*- Bounds & Slack Variable -*-
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    return g^2
end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # -*- Scalar Affine Function: g(x) = a'x - b ≤ 0 🤔 -*-
    g = PBF{VI,T}()
    
    toqubo_parse!(model, g, f, s, arch)

    PBO.discretize!(g)

    # -*- Bounds & Slack Variable -*-
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    # Slack Variable
    z = encode!(Binary(), model, nothing, zero(T), abs(l))

    for (ω, c) in expansion(z)
        g[ω] += c
    end

    return g^2
end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    # -*- Scalar Quadratic Function: g(x) = x Q x + a x - b = 0 😢 -*-
    g = PBF{VI,T}()
    
    toqubo_parse!(model, g, f, s, arch)

    # -*- Bounds & Slack Variable -*-
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
    model::VirtualQUBOModel{T},
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    # -*- Scalar Quadratic Function: g(x) = x Q x + a x - b ≤ 0 😢 -*-
    g = PBF{VI,T}()
    
    toqubo_parse!(model, g, f, s, arch)
    
    PBO.discretize!(g)

    # -*- Bounds & Slack Variable -*-
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    z = encode!(Binary(), model, nothing, zero(T), abs(l))

    for (ω, c) in expansion(z)
        g[ω] += c
    end

    # Tell the compiler that quadratization is necessary
    MOI.set(model, QUADRATIZE(), true)

    return g^2
end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    v::MOI.VectorOfVariables,
    ::MOI.SOS1{T},
    ::AbstractArchitecture,
) where {T}
    # -*- Special Ordered Set of Type 1: ∑ x ≤ min x 😄 -*-
    g = PBO.PBF{VI,T}()

    for vi in v.variables
        for (ωi, _) in expansion(MOI.get(model, Source(), vi))
            g[ωi] = one(T)
        end
    end

    z = expansion(encode!(Mirror(), model, nothing))

    # NOTE: Using one-hot approach. Not great, but it works.
    return (g + z - one(T))^2
end

function toqubo_encoding_constraints!(
    model::VirtualQUBOModel{T},
    ::AbstractArchitecture,
) where {T}
    for v in MOI.get(model, Variables())
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