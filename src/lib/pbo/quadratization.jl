# -*- :: Quadratization :: -*-

abstract type QuadratizationType end

_aux(::Type{<:QuadratizationType}, ::Int) = 0
_nst(::Type{<:QuadratizationType}, ::Int) = 0

struct Quadratization{T<:QuadratizationType}
    deg::Int # Initial Degree
    aux::Int # Auxiliary variables
    nst::Int # Non-Submodular Terms

    function Quadratization{T}(deg::Int) where {T<:QuadratizationType}
        return new{T}(
            deg,
            _aux(T, deg),
            _nst(T, deg),
        )
    end
end

@doc raw"""
    @quadratization(name, aux, nst)

Defines a new quadratization technique.
"""
macro quadratization(name, aux, nst)
    aux_func = if aux isa Integer
        quote _aux(::Type{$(esc(name))}, ::Int) = $(aux) end
    else
        quote _aux(::Type{$(esc(name))}, deg::Int) = $(aux)(deg) end
    end

    nst_func = if nst isa Integer
        quote _nst(::Type{$(esc(name))}, ::Int) = $(nst) end
    else
        quote _nst(::Type{$(esc(name))}, deg::Int) = $(nst)(deg) end
    end

    quote
        struct $(esc(name)) <: QuadratizationType end;

        # Ancillary Variables
        $(aux_func)

        # Non-Submodular Terms
        $(nst_func)
    end
end

@doc raw"""
    infer_quadratization(f::PBF)
"""
function infer_quadratization(f::PBF)
    k = degree(f)

    if k <= 2
        return nothing
    else
        return Quadratization{TBT}(k)
    end
end

@doc raw"""
    quadratize(aux::Function, f::PBF{S, T}, ::Quadratization) where {S, T}

Quadratizes a given PBF, i.e. creates a function ``g \in \mathscr{F}^{2}`` from ``f \in \mathscr{F}^{k}, k \ge 3``.

A function ``f : 2^{S} \to \mathbb{R}`` is said to be submodular if
```math
f(X \cup Y) + f(X \cap Y) \le f(X) + f(Y) \forall X, Y \subset S
```
""" function quadratize end

@doc raw"""
    Quadratization{TBT}(::Int)

Term-by-term quadratization. Employs other inner methods.
"""

@quadratization(TBT, 0, 0)

@doc raw"""
    Quadratization{NTR_KZFD}(::Int)

NTR-KZFD (Kolmogorov & Zabih, 2004; Freedman & Drineas, 2005)
"""

@quadratization(NTR_KZFD, 1, 0)

function quadratize(aux::Function, ω::Set{S}, c::T, ::Quadratization{NTR_KZFD}) where {S, T}
    # -* Degree *-
    k = length(ω)

    s = aux()::S

    PBF{S, T}(Set{S}([s]) => -c * convert(T, k - 1), (i × s => c for i ∈ ω)...)
end

@doc raw"""
    Quadratization{PTR_BG}(::Int)

PTR-BG (Boros & Gruber, 2014)
"""

@quadratization(
    PTR_BG,
    k -> k - 2,
    k -> k - 1,
)

function quadratize(aux::Function, ω::Set{S}, c::T, ::Quadratization{PTR_BG}) where {S, T}
    # -* Degree *-
    k = length(ω)

    # -* Variables *-
    s = aux(k - 2)::Vector{S}
    b = sort(collect(ω); lt = varcmp)::Vector{S}

    # -*- Quadratization -*-
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

function quadratize(aux::Function, ω::Set{S}, c::T) where {S, T}
    if c < zero(T)
        quadratize(
            aux,
            ω,
            c,
            Quadratization{NTR_KZFD}(length(ω)),
        )
    else
        quadratize(
            aux,
            ω,
            c,
            Quadratization{PTR_BG}(length(ω)),    
        )
    end
end

function quadratize(aux::Function, f::PBF{S, T}, ::Quadratization{TBT}) where {S, T}
    g = PBF{S, T}()

    for (ω, c) ∈ f.Ω
        if length(ω) <= 2
            g[ω] += c
        else
            for (η, a) ∈ quadratize(
                    aux,
                    ω,
                    c,
                    Quadratization{PTR_BG}(length(ω)),
                )
                g[η] += a
            end
        end
    end

    return g
end

function quadratize(aux::Function, f::PBF)
    Q = infer_quadratization(f)

    if isnothing(Q)
        return f
    else
        return quadratize(aux, f, Q)
    end
end