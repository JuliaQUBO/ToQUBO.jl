#  :: Quadratization ::  #
abstract type QuadratizationMethod end

struct Quadratization{Q<:QuadratizationMethod}
    stable::Bool

    function Quadratization{Q}(stable::Bool = false) where {Q<:QuadratizationMethod}
        return new{Q}(stable)
    end
end

@doc raw"""
    quadratize!(aux::Function, f::PBF{S, T}, ::Quadratization{Q}) where {S,T,Q}

Quadratizes a given PBF in-place, i.e. applies a mapping ``\mathcal{Q} : \mathscr{F}^{k} \to \mathscr{F}^{2}``, where ``\mathcal{Q}`` is the quadratization method.

```julia
aux(::Nothing)::S
aux(::Integer)::Vector{S}
```
""" function quadratize! end

@doc raw"""
    Quadratization{NTR_KZFD}(stable::Bool = false)

Negative Term Reduction NTR-KZFD (Kolmogorov & Zabih, 2004; Freedman & Drineas, 2005)

Let ``f(\mathbf{x}) = x_{1} x_{2} \dots x_{k}``.

```math
\mathcal{Q}\left\lbrace{f}\right\rbrace(\mathbf{x}; z) = (k - 1) z - \sum_{i = 1}^{k} x_{i} z
```

where ``\mathbf{x} \in \mathbb{B}^k``

!!! info
    Introduces a new variable ``z`` and no non-submodular terms.
""" struct NTR_KZFD <: QuadratizationMethod end

function quadratize!(
    aux::Function,
    f::PBF{S,T},
    ω::Set{S},
    c::T,
    ::Quadratization{NTR_KZFD},
) where {S,T}
    # Degree
    k = length(ω)

    # Fast-track
    k < 3 && return nothing

    # Variables
    s = aux()::S

    # Stabilize
    # NOTE: This method is stable by construction

    # Quadratization
    delete!(f, ω)

    f[s] += -c * (k - 1)

    for i ∈ ω
        f[i×s] += c
    end

    return nothing
end

@doc raw"""
    Quadratization{PTR_BG}(stable::Bool = false)

Positive Term Reduction PTR-BG (Boros & Gruber, 2014)

Let ``f(\mathbf{x}) = x_{1} x_{2} \dots x_{k}``.

```math
\mathcal{Q}\left\lbrace{f}\right\rbrace(\mathbf{x}; \mathbf{z}) = \left[{
    \sum_{i = 1}^{k-2} z_{i} \left({ k - i - 1 + x_{i} + \sum_{j = i+1}^{k} x_{j} }\right)
}\right] + x_{k-1} x_{k}
```
where ``\mathbf{x} \in \mathbb{B}^k`` and ``\mathbf{z} \in \mathbb{B}^{k-2}``

!!! info
    Introduces ``k - 2`` new variables ``z_{1}, \dots, z_{k-2}`` and ``k - 1`` non-submodular terms.
""" struct PTR_BG <: QuadratizationMethod end

function quadratize!(
    aux::Function,
    f::PBF{S,T},
    ω::Set{S},
    c::T,
    quad::Quadratization{PTR_BG},
) where {S,T}
    # Degree
    k = length(ω)

    # Fast-track
    k < 3 && return nothing

    # Variables
    s = aux(k - 2)::Vector{S}
    b = collect(ω)::Vector{S}

    # Stabilize
    quad.stable && sort!(b; lt = varlt)

    # Quadratization
    delete!(f, ω)

    f[b[k]×b[k-1]] += c

    for i = 1:(k-2)
        f[s[i]] += c * (k - i - 1)

        f[s[i]×b[i]] += c

        for j = (i+1):k
            f[s[i]×b[j]] -= c
        end
    end

    return nothing
end

@doc raw"""
    Quadratization{TERM_BY_TERM}(stable::Bool = false)

Term-by-term quadratization. Employs other inner methods, specially [`NTR_KZFD`](@ref) and [`PTR_BG`](@ref).
""" struct TERM_BY_TERM <: QuadratizationMethod end

function quadratize!(
    aux::Function,
    f::PBF{S,T},
    ω::Set{S},
    c::T,
    quad::Quadratization{TERM_BY_TERM},
) where {S,T}
    if c < zero(T)
        quadratize!(aux, f, ω, c, Quadratization{NTR_KZFD}(quad.stable))
    else
        quadratize!(aux, f, ω, c, Quadratization{PTR_BG}(quad.stable))
    end

    return nothing
end

@doc raw"""
    quadratize!(aux::Function, f::PBF{S,T}, quad::Quadratization{TERM_BY_TERM}) where {S,T}

    Receives a higher-degree pseudo-Boolean function 
"""
function quadratize!(
    aux::Function,
    f::PBF{S,T},
    quad::Quadratization{TERM_BY_TERM},
) where {S,T}
    # Collect Terms
    Ω = collect(f)

    # Stable Quadratization
    quad.stable && sort!(Ω; by = first, lt = varlt)

    for (ω, c) in Ω
        quadratize!(aux, f, ω, c, Quadratization{PTR_BG}(quad.stable))
    end

    return nothing
end


@doc raw"""
    Quadratization{INFER}(stable::Bool = false)
""" struct INFER <: QuadratizationMethod end

@doc raw"""
    infer_quadratization(f::PBF)

For a given PBF, returns whether it should be quadratized or not, based on its degree.
"""
function infer_quadratization(f::PBF, stable::Bool = false)
    k = degree(f)

    if k <= 2
        return nothing
    else
        # Without any extra knowledge, it is better to
        # quadratize term-by-term
        return Quadratization{TERM_BY_TERM}(stable)
    end
end

function quadratize!(aux::Function, f::PBF, quad::Quadratization{INFER})
    quadratize!(aux, f, infer_quadratization(f, quad.stable))

    return nothing
end

function quadratize!(::Function, ::PBF, ::Nothing)
    return nothing
end
