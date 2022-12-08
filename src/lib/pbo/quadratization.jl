# -*- :: Quadratization :: -*-

abstract type QuadratizationMethod end

_aux(::Type{<:QuadratizationMethod}, ::Int) = 0
_nst(::Type{<:QuadratizationMethod}, ::Int) = 0

struct Quadratization{T<:QuadratizationMethod}
    deg::Int # Initial Degree
    aux::Int # Auxiliary variables
    nst::Int # Non-Submodular Terms

    function Quadratization{T}(deg::Int) where {T<:QuadratizationMethod}
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

    return quote
        struct $(esc(name)) <: QuadratizationMethod end

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
        # Without any extra knowledge, it is better to
        # quadratize term-by-term
        return Quadratization{TBT}(k)
    end
end

@doc raw"""
    quadratize(aux::Function, f::PBF{S, T}, ::Quadratization) where {S, T}

Quadratizes a given PBF, i.e. creates a function ``g \in \mathscr{F}^{2}`` from ``f \in \mathscr{F}^{k}, k \ge 3``.

```julia
aux(::Nothing)::S
aux(::Integer)::Vector{S}
```

## Submodularity

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

    g = PBF{S,T}(s => -c * (k - 1))

    for i ∈ ω
        η = Set{S}([s, i])

        g[η] += c
    end

    return g
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
        f[s[i]] += c * (k - i - 1)

        f[s[i] × b[i]] += c

        for j = (i + 1):k
            f[s[i] × b[j]] -= c
        end
    end    

    return f
end

function quadratize(aux::Function, ω::Set{S}, c::T) where {S, T}
    if c < zero(T)
        return quadratize(
            aux,
            ω,
            c,
            Quadratization{NTR_KZFD}(length(ω)),
        )
    else
        return quadratize(
            aux,
            ω,
            c,
            Quadratization{PTR_BG}(length(ω)),    
        )
    end
end

function quadratize(aux::Function, f::PBF{S, T}, ::Quadratization{TBT}) where {S, T}
    g = PBF{S, T}()

    sizehint!(g, length(f))

    for (ω, c) in f
        k = length(ω)

        if k <= 2
            g[ω] += c
        else
            h = quadratize(
                aux,
                ω,
                c,
                Quadratization{PTR_BG}(k),
            )

            for (η, a) in h
                g[η] += a
            end
        end
    end

    return g
end

function quadratize(aux::Function, f::PBF)
    quad = infer_quadratization(f)

    if isnothing(quad)
        return f
    else
        return quadratize(aux, f, quad)
    end
end