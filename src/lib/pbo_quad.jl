# -*- Quadratization -*-
# https://github.com/dwavesystems/dimod/blob/66f8c06bb6dca2e75918f07f648b5f5d80d7a233/dimod/higherorder/utils.py#L101

abstract type AbstractQuadratization end

@doc raw"""
    @quadratization(name, var, nsv, nst, doc = "")

Creates new quadratization technique.
"""
macro quadratization(name, var, nsv, nst, doc = "")
    return :(
        struct $name <: AbstractQuadratization
            deg::Int    # Degree
            nsv::Int    # New Slack Variables
            nst::Int    # Non-Submodular Terms
            doc::String # Docstring

            function $name($var::Int = 0)
                return new(
                    $var,
                    $nsv,
                    $nst,
                    $doc
                )
            end
        end
    )
end

@quadratization(TBT_QUAD, k, 0, 0, "Term-by-term quadratization")

@quadratization(NTR_KZFD, k, 1, 0, "NTR-KZFD (Kolmogorov & Zabih, 2004; Freedman & Drineas, 2005)")
@quadratization(PTR_BG, k, k - 2, k - 1, "PTR-BG (Boros & Gruber, 2014)")

function quadratize(::NTR_KZFD, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    s = slack()::S

    f = PBF{S, T}(Set{S}([s]) => -c * convert(T, k - 1), (i × s => c for i ∈ ω)...)

    return f
end

function quadratize(::PTR_BG, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    # -* Variables *-
    s = slack(k - 2)::Vector{S}
    b = sort(collect(ω))::Vector{S}

    # -*- PBF & Quadratization -*-
    f = PBF{S, T}(b[k] × b[k - 1] => c)

    for i = 1:(k - 2)
        f[s[i]] += c * convert(T, k - i - 1)

        f[s[i] × b[i]] += c

        for j = (i + 1):k
            f[s[i] × b[j]] -= c
        end
    end    

    return f
end

function quadratize(::TBT_QUAD, f::PBF{S, T}; slack::Any) where {S, T}
    g = PBF{S, T}()

    for (ω, c) ∈ f.Ω
        if length(ω) <= 2
            g[ω] += c
        else
            for (η, a) ∈ quadratize(ω, c; slack=slack)
                g[η] += a
            end
        end
    end

    return g
end

function quadratize(ω::Set{S}, c::T; slack::Any) where {S, T}
    if c < zero(T)
        return quadratize(NTR_KZFD(length(ω)), ω, c; slack=slack)
    else
        return quadratize(PTR_BG(length(ω)), ω, c; slack=slack)
    end
end

@doc raw"""
    quadratize(f::PBF{S, T}; slack::Any) where {S, T}

Quadratizes a given PBF, i.e. creates a function ``g \in \mathscr{F}^{2}`` from ``f \in \mathscr{F}^{k}, k \ge 3``.
"""
function quadratize(f::PBF{S, T}; slack::Any) where {S, T}
    return quadratize(TBT_QUAD(degree(f)), f; slack=slack)
end