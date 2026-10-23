function _parse(
    model::Virtual.Model{T},
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
    arch::AbstractArchitecture,
) where {T}
    g = PBO.PBF{VI,T}()

    parse!(model, g, f, s, arch)

    return g
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    vi::VI,
    ::AbstractArchitecture,
) where {T}
    Base.empty!(g)

    for (ω, c) in Virtual.expansion(model.source[vi])
        g[ω] += c
    end

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    ::AbstractArchitecture,
) where {T}
    Base.empty!(g)

    sizehint!(g, length(f.terms) + 1)

    for a in f.terms
        c = a.coefficient
        x = a.variable
        v = model.source[x]

        for (ω, d) in Virtual.expansion(v)
            g[ω] += c * d
        end
    end

    g[nothing] += f.constant

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.value

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.upper

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SAF{T},
    s::GT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.lower

    return nothing
end


function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    ::AbstractArchitecture,
) where {T}
    Base.empty!(g)

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

        for (ωi, di) in Virtual.expansion(vi)
            for (ωj, dj) in Virtual.expansion(vj)
                ωij = PBO.varmul(ωi, ωj)::PBO.Term{VI}

                g[ωij] += c * di * dj
            end
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable
        v = model.source[x]

        for (ω, d) in Virtual.expansion(v)
            g[ω] += c * d
        end
    end

    g[nothing] += f.constant

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.value

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.upper

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SQF{T},
    s::GT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.lower

    return nothing
end

function _polynomial_function(model::Virtual.Model{T}, f::SNF) where {T}
    try
        return QUBODrivers.polynomial_function(f, T)
    catch err
        if err isa QUBODrivers.InvalidNLExpression
            compilation_error!(
                model,
                err.message;
                status = "Unsupported nonlinear expression",
            )
        end

        rethrow(err)
    end
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    spf::QUBODrivers.ScalarPolynomialFunction{T},
    ::AbstractArchitecture,
) where {T}
    Base.empty!(g)

    terms = MP.terms(spf.polynomial)
    sizehint!(g, length(terms))

    for term in terms
        c = MP.coefficient(term)
        iszero(c) && continue

        term_pbf = PBO.PBF{VI,T}(c)

        for (vi, exp) in zip(spf.variables, MP.exponents(term))
            exp == 0 && continue
            v = model.source[vi]
            ξ = Virtual.expansion(v)
            factor = exp == 1 ? ξ : ξ^exp
            term_pbf = term_pbf * factor
        end

        for (ω, d) in term_pbf
            g[ω] += d
        end
    end

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::SNF,
    arch::AbstractArchitecture,
) where {T}
    spf = _polynomial_function(model, f)
    parse!(model, g, spf, arch)

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::Union{SNF,QUBODrivers.ScalarPolynomialFunction{T}},
    s::EQ{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.value

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::Union{SNF,QUBODrivers.ScalarPolynomialFunction{T}},
    s::LT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.upper

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    g::PBO.PBF{VI,T},
    f::Union{SNF,QUBODrivers.ScalarPolynomialFunction{T}},
    s::GT{T},
    arch::AbstractArchitecture,
) where {T}
    parse!(model, g, f, arch)

    g[nothing] -= s.lower

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    fs::Vector{PBO.PBF{VI,T}},
    f::Union{VI,SAF{T},SQF{T},SNF,QUBODrivers.ScalarPolynomialFunction{T}},
    arch::AbstractArchitecture,
) where {T}
    resize!(fs, 1)
    fs[1] = PBO.PBF{VI,T}()

    parse!(model, fs[1], f, arch)

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    fs::Vector{PBO.PBF{VI,T}},
    f::VOV,
    arch::AbstractArchitecture,
) where {T}
    n = length(f.variables)
    resize!(fs, n)

    for (i, vi) in enumerate(f.variables)
        fs[i] = PBO.PBF{VI,T}()
        parse!(model, fs[i], vi, arch)
    end

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    fs::Vector{PBO.PBF{VI,T}},
    f::VAF{T},
    ::AbstractArchitecture,
) where {T}
    n = length(f.constants)
    resize!(fs, n)

    for i = 1:n
        g = PBO.PBF{VI,T}()
        g[nothing] += f.constants[i]
        fs[i] = g
    end

    for term in f.terms
        i = term.output_index
        a = term.scalar_term
        c = a.coefficient
        v = model.source[a.variable]
        g = fs[i]

        for (ω, d) in Virtual.expansion(v)
            g[ω] += c * d
        end
    end

    return nothing
end

function parse!(
    model::Virtual.Model{T},
    fs::Vector{PBO.PBF{VI,T}},
    f::VQF{T},
    ::AbstractArchitecture,
) where {T}
    n = length(f.constants)
    resize!(fs, n)

    for i = 1:n
        g = PBO.PBF{VI,T}()
        g[nothing] += f.constants[i]
        fs[i] = g
    end

    for term in f.quadratic_terms
        i = term.output_index
        q = term.scalar_term
        c = q.coefficient
        xi = q.variable_1
        xj = q.variable_2
        vi = model.source[xi]
        vj = model.source[xj]
        g = fs[i]

        if xi === xj
            c /= 2
        end

        for (ωi, di) in Virtual.expansion(vi)
            for (ωj, dj) in Virtual.expansion(vj)
                ωij = PBO.varmul(ωi, ωj)::PBO.Term{VI}

                g[ωij] += c * di * dj
            end
        end
    end

    for term in f.affine_terms
        i = term.output_index
        a = term.scalar_term
        c = a.coefficient
        v = model.source[a.variable]
        g = fs[i]

        for (ω, d) in Virtual.expansion(v)
            g[ω] += c * d
        end
    end

    return nothing
end
