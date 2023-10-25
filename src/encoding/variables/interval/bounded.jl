@doc raw"""
    Bounded{E,T}(μ::T) where {E<:Encoding,T}

The bounded-coefficient encoding method[^Karimi2019] consists in limiting the magnitude of the coefficients in the encoding expansion to a parameter ``\mu``.

[^Karimi2019]:
    Karimi, S. & Ronagh, P. **Practical integer-to-binary mapping for quantum annealers**. *Quantum Inf Process 18, 94* (2019). [{doi}](https://doi.org/10.1007/s11128-019-2213-x)

This can be applied to the [`Unary`](@ref), [`Binary`](@ref) and [`Arithmetic`](@ref) encoding schemas.

    Bounded{Binary,T}(μ::T) where {T}
```

"""
struct Bounded{E<:IntervalVariableEncodingMethod,T} <: IntervalVariableEncodingMethod
    e::E
    μ::T

    function Bounded(e::E, μ::T) where {E<:IntervalVariableEncodingMethod,T}
        @assert μ > zero(T)

        return new{E,T}(e, μ)
    end
end

# Integer
function encode(
    var::Function,
    e::Bounded{E,T},
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {E<:IntervalVariableEncodingMethod,T}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    m = floor(Int, e.μ)
    n = trunc(Int, b - a)
    r = n ÷ m
    d = n - r * m

    Δ::Tuple{T,T} = (0, d + r)

    y0, ξ0, χ0 = encode(var, e.e, Δ)

    @assert isnothing(χ0)

    y1 = var(r - 1)::Vector{VI}
    ξ1 = PBO.PBF{VI,T}(y1[i] => m for i = 1:(r - 1))

    y = [y0; y1]
    ξ = a + ξ0 + ξ1

    return (y, ξ, nothing) # No penalty function
end

# Real
function encode(
    var::Function,
    e::Bounded{E,T},
    S::Tuple{T,T},
    n::Union{Integer,Nothing};
    tol::Union{T,Nothing} = nothing,
) where {E<:IntervalVariableEncodingMethod,T}
    @assert !(isnothing(tol) && isnothing(n))

    a, b = S

    r = ceil(Int, (b - a) / e.μ - 1)
    δ = b - a - r * e.μ

    Δ::Tuple{T,T} = (0, δ + r)
    
    y0, ξ0, χ0 = if isnothing(n)
        encode(var, e.e, Δ, nothing; tol)
    else
        encode(var, e.e, Δ, n - (r - 1); tol)
    end

    @assert isnothing(χ0)

    y1 = var(r - 1)::Vector{VI}
    ξ1 = PBO.PBF{VI,T}(y1[i] => e.μ for i = 1:(r - 1))

    y = [y0; y1]
    ξ = a + ξ0 + ξ1

    return (y, ξ, nothing) # No penalty function    
end
