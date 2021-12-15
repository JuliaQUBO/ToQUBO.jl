"""
"""

@doc raw"""
$\sum_{\omega \in \Omega} c_\omega \sum_{i \in \omega} x_i$

There are some assumptions about this structure:
    - Variables are all binary $x \in \{0, 1\}$. This allows straightforward idempotency rule application $x = x^{2}$.
    - If the leading constant is zero, the term is removed i.e. sparsity is built upon zeros.
    - ...

[1] Endre Boros, Peter L. Hammer, Pseudo-boolean optimization, 2002
    https://doi.org/10.1016/S0166-218X(01)00341-9
"""
mutable struct Posiform{S <: Any, T <: Number}
    name::String
    pairs::Dict{Set{S}, T}
    degree::Int

    function Posiform{S, T}(; name::String="x") where {S, T}
        return new{S, T}(name, Dict{Set{S}, T}(), 0)
    end

    function Posiform{S, T}(x::Dict{Set{S}, T}; name::String="x") where {S, T}
        p = Dict{Set{S}, T}(k => v for (k, v) in x if v != 0)
        d = maximum(length.(keys(p)))
        return new{S, T}(name, p, d)
    end

    function Posiform{S, T}(x::T; name::String="x") where {S, T}
        if x == 0
            return new{S, T}(name, Dict{Set{S}, T}(), 0)
        else
            return new{S, T}(name, Dict{Set{S}, T}(Set{S}() => x), 0)
        end
    end

    function Posiform{S, T}(x::Pair{Set{S}, T}...; name::String="x") where {S, T}
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
        return new{S, T}(name, p, d)
    end

    function Posiform{S, T}(x::Pair{Vector{S}, T}...; name::String="x") where {S, T}
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
        return new{S, T}(name, p, d)
    end
end

function Base.keys(p::Posiform)
    return keys(p.pairs)
end

function Base.values(p::Posiform)
    return values(p.pairs)
end

function Base.iterate(p::Posiform{S, T}) where {S, T}
    return iterate(p.pairs)
end

function Base.iterate(p::Posiform{S, T}, n::Int) where {S, T}
    return iterate(p.pairs, n)
end

function Base.getindex(p::Posiform{S, T}, k::Set{S}) where {S, T}
    return get(p.pairs, k, T(0))
end

function Base.getindex(p::Posiform{S, T}, k::S) where {S, T}
    return get(p.pairs, Set{S}([k]), T(0))
end

function Base.get(p::Posiform{S, T}, k::Set{S}, d::T) where {S, T}
    return get(p.pairs, k, d)
end

function Base.setindex!(p::Posiform{S, T}, value::T, key::Set{S}) where {S, T}
    setindex!(p.pairs, value, key)
end

function Base.setindex!(p::Posiform{S, T}, value::T, key::S) where {S, T}
    setindex!(p.pairs, value, Set{S}([key]))
end

function vars(p::Posiform{S, T}) where {S, T}
    if isempty(p)
        return Set{S}()
    else
        return union(keys(p)...)
    end
end

function toqubo(p::Posiform{S, T}) where {S, T}
    v = vars(p)
    n = length(v)
    Q = zeros(T, n, n)
    return Q
end

function Base.copy(p::Posiform{S, T}) where {S, T}
    if isempty(p)
        return Posiform{S, T}()
    else
        return Posiform{S, T}(copy(p.pairs))
    end
end

function Base.isempty(p::Posiform)
    return isempty(p.pairs)
end

function Base.:+(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    pairs = Dict{Set{S}, T}()
    for k in union(keys(p), keys(q))
        pairs[k] = get(p, k, T(0)) + get(q, k, T(0)) 
    end
    return Posiform{S, T}(pairs)
end

function Base.:+(p::Posiform{S, T}, c::T) where {S, T}
    if c == T(0)
        return copy(p)
    end

    q = copy(p)
    ∅ = Set{S}()
    q.pairs[∅] = get(q.pairs, ∅, T(0)) + c
    return q
end

Base.:+(c::T, p::Posiform{S, T}) where {S, T} = (p + c)

function Base.:-(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    pairs = Dict{Set{S}, T}()
    for k in union(keys(p), keys(q))
        pairs[k] = get(p, k, T(0)) - get(q, k, T(0)) 
    end
    return Posiform{S, T}(pairs)
end

function Base.:-(p::Posiform{S, T}, c::T) where {S, T}
    q = copy(p)
    ∅ = Set{S}()
    q.pairs[∅] = get(q.pairs, ∅, T(0)) - c
    return q
end

function Base.:*(p::Posiform{S, T}, q::Posiform{S, T}) where {S, T}
    if isempty(p) || isempty(q)
        return Posiform{S, T}()
    end

    r = Posiform{S, T}()

    for (pₖ, pᵥ) in p.pairs, (qₖ, qᵥ) in q.pairs
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
        q.pairs[k] *= c
    end

    return q
end

function Base.:/(p::Posiform{S, T}, c::T) where {S, T}
    if c == 0
       error(DivideError, ": division by zero") 
    end

    q = copy(p)

    for k in keys(q)
        q.pairs[k] /= c
    end

    return q
end

Base.:*(c::T, p::Posiform{S, T}) where {S, T} = (p * c)

function Base.:^(p::Posiform{S, T}, n::Int) where {S, T}
    q = Posiform{S, T}(1.0)

    for i=1:n
        q = q * p
    end

    return q
end

function subscript(i::Int)
    return join([(i < 0) ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]])
end

function Base.print(io::IO, p::Posiform{T}) where {T}

    if isempty(p)
        print(io, "0")
        return
    end
    
    terms = Vector{String}()

    for (i, (k, v)) in enumerate(p.pairs)
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

Base.show(io::IO, p::Posiform) = print(io, p)