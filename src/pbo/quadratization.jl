# -*- :: Quadratization :: -*-

abstract type QuadratizationType end

nsv(::Type{<:QuadratizationType}, ::Int) = 0
nst(::Type{<:QuadratizationType}, ::Int) = 0

struct Quadratization{T<:QuadratizationType}
    deg::Int # Initial Degree
    nsv::Int # New Slack Variables
    nst::Int # Non-Submodular Terms

    function Quadratization{T}(deg::Int) where {T<:QuadratizationType}
        return new{T}(
            deg,
            nsv(T, deg),
            nst(T, deg),
        )
    end
end

@doc raw"""
    @quadratization(name, nsv, nst)

Defines a new quadratization technique.
"""
macro quadratization(name, nsv, nst)
    quote
        struct $(esc(name)) <: QuadratizationType end;

        function nsv(::Type{$(esc(name))}, k::Int)
            return $(esc(nsv))
        end;

        function nst(::Type{$(esc(name))}, k::Int)
            return $(esc(nst))
        end;
    end
end

@doc raw"""
    TBT_QUAD(::Int)

Term-by-term quadratization
"""

@quadratization TBT_QUAD 0 0

@doc raw"""
    NTR_KZFD(::Int)

NTR-KZFD (Kolmogorov & Zabih, 2004; Freedman & Drineas, 2005)
"""

@quadratization NTR_KZFD 1 0

function quadratize(::Quadratization{NTR_KZFD}, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    s = slack()::S

    return PBF{S, T}(Set{S}([s]) => -c * convert(T, k - 1), (i × s => c for i ∈ ω)...)
end

@doc raw"""
    PTR_BG(::Int)

PTR-BG (Boros & Gruber, 2014)
"""

@quadratization PTR_BG k - 2 k - 1

function quadratize(::Quadratization{PTR_BG}, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    # -* Variables *-
    s = slack(k - 2)::Vector{S}
    b = sort(collect(ω); lt = varcmp)::Vector{S}

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

function quadratize(ω::Set{S}, c::T; slack::Any) where {S, T}
    if c < zero(T)
        return quadratize(
            Quadratization{NTR_KZFD}(length(ω)),
            ω,
            c;
            slack=slack,
        )
    else
        return quadratize(
            Quadratization{PTR_BG}(length(ω)),    
            ω,
            c;
            slack=slack,
        )
    end
end

function quadratize(::Quadratization{TBT_QUAD}, f::PBF{S, T}; slack::Any) where {S, T}
    g = PBF{S, T}()

    for (ω, c) ∈ f.Ω
        if length(ω) <= 2
            g[ω] += c
        else
            for (η, a) ∈ quadratize(
                    Quadratization{PTR_BG}(length(ω)),
                    ω,
                    c;
                    slack=slack,
                )
                g[η] += a
            end
        end
    end

    return g
end

@doc raw"""
    quadratize(f::PBF{S, T}; slack::Any) where {S, T}

Quadratizes a given PBF, i.e. creates a function ``g \in \mathscr{F}^{2}`` from ``f \in \mathscr{F}^{k}, k \ge 3``.

A function ``f : 2^{S} \to \mathbb{R}`` is said to be submodular if
```math
f(X \cup Y) + f(X \cap Y) \le f(X) + f(Y) \forall X, Y \subset S
```
"""
function quadratize end

function quadratize(f::PBF{S, T}; slack::Any) where {S, T}
    quadratize(
        Quadratization{TBT_QUAD}(degree(f)),
        f;
        slack=slack,
    )
end