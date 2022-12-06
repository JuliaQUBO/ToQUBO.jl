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
    ::AbstractArchitecture,
) where {T}
    # -*- Scalar Affine Function: Ax = b ~ 😄 -*-
    b = s.value
    g = PBO.PBF{VI,T}(-b)

    for a in f.terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            g[ω] += c * d
        end
    end

    g = PBO.discretize(g)

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
    ::AbstractArchitecture,
) where {T}
    # -*- Scalar Affine Function: Ax <= b 🤔 -*-
    b = s.upper
    g = PBO.PBF{VI,T}(-b)

    for a in f.terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            g[ω] += c * d
        end
    end

    g = PBO.discretize(g)

    # -*- Bounds & Slack Variable -*-
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    z = expansion(encode!(Binary(), model, nothing, zero(T), abs(l)))

    return (g + z)^2
end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    f::SQF{T},
    s::EQ{T},
    ::AbstractArchitecture,
) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x = b 😢 -*-
    b = s.value
    g = PBO.PBF{VI,T}(-b)

    for q in f.quadratic_terms
        c  = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        if xi === xj
            c /= 2
        end

        for (ωi, di) in expansion(MOI.get(model, Source(), xi))
            for (ωj, dj) in expansion(MOI.get(model, Source(), xj))
                g[union(ωi, ωj)] += c * di * dj
            end
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            g[ω] += c * d
        end
    end

    g = PBO.discretize(g)

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
    f::SQF{T},
    s::LT{T},
    ::AbstractArchitecture,
) where {T}
    # -*- Scalar Quadratic Function: x Q x + a x <= b 😢 -*-
    b = s.upper
    g = PBO.PBF{VI,T}(-b)

    for q in f.quadratic_terms
        c  = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        if xi === xj
            c /= 2
        end

        for (ωi, di) in expansion(MOI.get(model, Source(), xi))
            for (ωj, dj) in expansion(MOI.get(model, Source(), xj))
                g[union(ωi, ωj)] += c * di * dj
            end
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            g[ω] += c * d
        end
    end

    g = PBO.discretize(g)

    # -*- Bounds & Slack Variable -*-
    l, u = PBO.bounds(g)

    if u < zero(T) # Always feasible
        @warn "Always-feasible constraint detected"
        return nothing
    elseif l > zero(T) # Infeasible
        @warn "Infeasible constraint detected"
    end

    z = expansion(encode!(Binary(), model, nothing, zero(T), abs(l)))

    return (g + z)^2
end

function toqubo_constraint(
    model::VirtualQUBOModel{T},
    v::MOI.VectorOfVariables,
    ::MOI.SOS1{T},
    ::AbstractArchitecture,
) where {T}
    # -*- Special Ordered Set of Type 1: ∑ x <= min x 😄 -*-
    g = PBO.PBF{VI,T}()

    for vi in v.variables
        for (ωi, _) in expansion(MOI.get(model, Source(), vi))
            g[ωi] = one(T)
        end
    end

    z = expansion(encode!(Mirror(), model, nothing))

    return (g + z - one(T))^2 # one-hot approach
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