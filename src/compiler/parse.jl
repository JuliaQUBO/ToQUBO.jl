function toqubo_parse(
    model::VirtualModel{T},
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
    arch::AbstractArchitecture,
) where {T}
    g = PBO.PBF{VI,T}()

    toqubo_parse!(model, g, f, s, arch)

    return g
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    vi::VI,
    ::AbstractArchitecture,
) where {T}
    empty!(g)

    for (ω, c) in expansion(model.source[vi])
        g[ω] += c
    end

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    ::AbstractArchitecture,
) where {T}
    empty!(g)

    sizehint!(g, length(f.terms) + 1)

    for a in f.terms
        c = a.coefficient
        x = a.variable
        v = model.source[x]

        for (ω, d) in expansion(v)
            g[ω] += c * d
        end
    end

    g[nothing] += f.constant

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    toqubo_parse!(model, g, f, arch)

    g[nothing] -= s.value

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    toqubo_parse!(model, g, f, arch)

    g[nothing] -= s.upper

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    ::AbstractArchitecture,
) where {T}
    empty!(g)

    sizehint!(g, length(f.quadratic_terms) + length(f.affine_terms) + 1)

    for q in f.quadratic_terms
        c  = q.coefficient
        xi = q.variable_1
        xj = q.variable_2
        vi = model.source[xi]
        vj = model.source[xj]

        # MOI convetion is to write ScalarQuadraticFunction as
        #     ½ x' Q x + a x + b
        # ∴ every coefficient in the main diagonal is doubled
        if xi === xj
            c /= 2
        end

        for (ωi, di) in expansion(vi)
            for (ωj, dj) in expansion(vj)
                g[union(ωi, ωj)] += c * di * dj
            end
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable
        v = model.source[x]

        for (ω, d) in expansion(v)
            g[ω] += c * d
        end
    end

    g[nothing] += f.constant

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    toqubo_parse!(model, g, f, arch)

    g[nothing] -= s.value

    return nothing
end

function toqubo_parse!(
    model::VirtualModel{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    toqubo_parse!(model, g, f, arch)

    g[nothing] -= s.upper

    return nothing
end