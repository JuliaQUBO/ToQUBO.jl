module Posiforms

using Documenter

export Posiform
export convert, isempty, copy, print, subscript
export keys, values, get, getindex, setindex!, iterate

@doc raw"""
$P(x) = \sum_{\omega \in \Omega} c_\omega \sum_{i \in \omega} x_i$

There are some assumptions about this structure:
    - Variables are all binary $x \in \{0, 1\}$. This allows straightforward idempotency rule application $x = x^{2}$, which leads to Set{S} keys
    - If the leading constant is zero, the term is removed i.e. sparsity is built upon zeros
    - If no variable terms are present, a posiform can be interpreted as a scalar via `convert(::Type{T}, ::Posiform{S, T})::T where T`

[1] Endre Boros, Peter L. Hammer, Pseudo-boolean optimization, 2002
    https://doi.org/10.1016/S0166-218X(01)00341-9
"""
struct Posiform{S <: Any, T <: Number} <: AbstractDict{Set{S}, T}
    terms::Dict{Set{S}, T}
    degree::Int

    function Posiform{S, T}() where {S, T}
        return new{S, T}(Dict{Set{S}, T}(), 0)
    end

    function Posiform{S, T}(c::T) where {S, T}
        if c == 0
            return new{S, T}(Dict{Set{S}, T}(), 0)
        else
            return new{S, T}(Dict{Set{S}, T}(Set{S}() => c), 0)
        end
    end

    function Posiform{S, T}(x::Dict{Set{S}, T}) where {S, T}
        p = Dict{Set{S}, T}(k => v for (k, v) in x if v != 0)
        d = maximum(length.(keys(p)))
        return new{S, T}(p, d)
    end

    function Posiform{S, T}(x::Pair{Set{S}, T}...) where {S, T}
        p = Dict{Set{S}, T}()
        for (k, v) in x
            w = get(p, k, T(0)) + v
            if w == 0
                delete!(p, k)
            else
                p[k] = w
            end
        end
        d = maximum(length.(keys(p)))
        return new{S, T}(p, d)
    end

    function Posiform{S, T}(x::Pair{Vector{S}, T}...) where {S, T}
        p = Dict{Set{S}, T}()
        for (k, v) in x
            k = Set{S}(k)
            w = get(p, k, T(0)) + v
            if w == 0
                delete!(p, k)
            else
                p[k] = w
            end
        end
        d = maximum(length.(keys(p)))
        return new{S, T}(p, d)
    end
end # struct

# -*- Default Constructor -*-
function Posiform()
    return Posiform{Int, Float64}()
end

function Posiform(c::Float64)
    return Posiform{Int, Float64}(c)
end


function (p::Posiform{S, T})(x::Dict{S, T})::Posiform{S, T} where {S, T}
    
    q = Posiform{S, T}()
    
    for (yᵢ, cᵢ) in p
        zᵢ = Set{S}()
        for yⱼ in yᵢ
            if haskey(x, yⱼ)
                cᵢ *= x[yⱼ]
            else
                push!(zᵢ, yⱼ)
            end
        end
        q[zᵢ] += cᵢ
    end

    return q
end

function Base.convert(::Type{T}, p::Posiform{S, T})::T where {S, T}
    if isempty(p)
        return convert(T, 0)
    elseif length(p) == 1 && haskey(p.terms, Set{S}())
        return p.terms[Set{S}()]
    else
        error("Posiform with variables can't be interpreted as $T")
    end
end

function Base.length(p::Posiform)
    return length(p.terms)
end

function Base.keys(p::Posiform)
    return keys(p.terms)
end

function Base.values(p::Posiform)
    return values(p.terms)
end

function Base.iterate(p::Posiform{S, T}) where {S, T}
    return iterate(p.terms)
end

function Base.iterate(p::Posiform{S, T}, n::Int) where {S, T}
    return iterate(p.terms, n)
end

function Base.getindex(p::Posiform{S, T}, k::Set{S}) where {S, T}
    return get(p.terms, k, T(0))
end

function Base.getindex(p::Posiform{S, T}, k::S) where {S, T}
    return get(p.terms, Set{S}([k]), T(0))
end

function Base.get(p::Posiform{S, T}, k::Set{S}, d::T) where {S, T}
    return get(p.terms, k, d)
end

function Base.setindex!(p::Posiform{S, T}, value::T, key::Set{S}) where {S, T}
    setindex!(p.terms, value, key)
end

function Base.setindex!(p::Posiform{S, T}, value::T, key::S) where {S, T}
    setindex!(p.terms, value, Set{S}([key]))
end

function vars(p::Posiform{S, T}) where {S, T}
    if isempty(p)
        return Set{S}()
    else
        return union(keys(p)...)
    end
end

function reduce_degree(p::Posiform{S, T})::Posiform{S, T} where {S, T}
    if p.degree == 2
        return copy(p)
    else
        # TODO: implement degree reduction
        return copy(p)
    end
end

function Base.copy(p::Posiform{S, T}) where {S, T}
    if isempty(p)
        return Posiform{S, T}()
    else
        return Posiform{S, T}(copy(p.terms))
    end
end

function Base.isempty(p::Posiform)
    return isempty(p.terms)
end

function Base.:+(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    terms = Dict{Set{S}, T}()
    for k in union(keys(p), keys(q))
        terms[k] = get(p, k, T(0)) + get(q, k, T(0)) 
    end
    return Posiform{S, T}(terms)
end

function Base.:+(p::Posiform{S, T}, c::T) where {S, T}
    if c == T(0)
        return copy(p)
    end

    q = copy(p)
    ∅ = Set{S}()
    q.terms[∅] = get(q.terms, ∅, T(0)) + c
    return q
end

Base.:+(c::T, p::Posiform{S, T}) where {S, T} = (p + c)

function Base.:-(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    terms = Dict{Set{S}, T}()
    for k in union(keys(p), keys(q))
        terms[k] = get(p, k, T(0)) - get(q, k, T(0)) 
    end
    return Posiform{S, T}(terms)
end

function Base.:-(p::Posiform{S, T}, c::T) where {S, T}
    q = copy(p)
    ∅ = Set{S}()
    q.terms[∅] = get(q.terms, ∅, T(0)) - c
    return q
end

function Base.:*(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    if isempty(p) || isempty(q)
        return Posiform{S, T}()
    end

    r = Posiform{S, T}()

    for (pₖ, pᵥ) in p.terms, (qₖ, qᵥ) in q.terms
        rₖ = union(pₖ, qₖ)
        rᵥ = pᵥ * qᵥ
        if rᵥ != T(0)
            r[rₖ] += rᵥ
        end
    end

    return r
end

function Base.:*(p::Posiform{S, T}, c::T) where {S, T}
    if c == 0
        return Posiform{S, T}()
    end

    q = copy(p)

    for k in keys(q)
        q.terms[k] *= c
    end

    return q
end

function Base.:/(p::Posiform{S, T}, c::T) where {S, T}
    if c == 0
       error(DivideError, ": division by zero") 
    end

    q = copy(p)

    for k in keys(q)
        q.terms[k] /= c
    end

    return q
end

Base.:*(c::T, p::Posiform{S, T}) where {S, T} = (p * c)

function Base.:^(p::Posiform{S, T}, n::Int) where {S, T}
    q = Posiform{S, T}(1.0)

    for _ = 1:n
        q = q * p
    end

    return q
end

# -*- IO & Display -*-

function subscript(::Any)::String
    return "ₓ"
end

function subscript(i::Int)::String
    return join([(i < 0) ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]])
end

function Base.print(io::IO, p::Posiform{T}) where {T}

    if isempty(p)
        print(io, "0")
        return
    end
    
    terms = Vector{String}()

    for (i, (k, v)) in enumerate(p.terms)
        if v < 0
            if i == 1
                s = "-"
            else
                s = " - "
            end
        else
            if i == 1
                s = ""
            else
                s = " + "
            end
        end

        c = abs(v)

        if isempty(k)
            term = "$s$c"
        else
            x = join(("x$(subscript(kᵢ))" for kᵢ in k), " ")
            term = "$s$c $x"
        end

        push!(terms, term)
    end
    
    print(io, join(terms))
    return
end

end # module