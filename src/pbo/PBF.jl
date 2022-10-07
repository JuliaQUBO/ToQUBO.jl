import Base: isiterable

@doc raw"""
"""
function parseterm end

parseterm(::Type{S}, ::Type{T}, x::Any) where {S, T} = error("Invalid term '$(x)'") # fallback
parseterm(::Type{S}, ::Type{T}, ::Nothing) where {S, T} = (Set{S}(), one(T))
parseterm(::Type{S}, ::Type{T}, x::T) where {S, T} = (Set{S}(), x)
parseterm(::Type{S}, ::Type{T}, x::S) where {S, T} = (Set{S}([x]), one(T))
parseterm(::Type{S}, ::Type{T}, x::Union{Vector{S}, Set{S}}) where {S, T} = (Set{S}(x), one(T))
parseterm(::Type{S}, ::Type{T}, x::Pair{Nothing, T}) where {S, T} = (Set{S}(), last(x))
parseterm(::Type{S}, ::Type{T}, x::Tuple{Nothing, T}) where {S, T} = (Set{S}(), last(x))
parseterm(::Type{S}, ::Type{T}, x::Union{Pair{S, T}, Tuple{S, T}}) where {S, T} = (Set{S}([first(x)]), last(x))
parseterm(::Type{S}, ::Type{T}, x::Pair{<:Union{Vector{S}, Set{S}}, T}) where {S, T} = (Set{S}(first(x)), last(x))
parseterm(::Type{S}, ::Type{T}, x::Tuple{<:Union{Vector{S}, Set{S}}, T}) where {S, T} = (Set{S}(first(x)), last(x))

@doc raw"""
A Pseudo-Boolean Function ``f \in \mathscr{F}`` over some field ``\mathbb{T}`` takes the form

```math
f(\mathbf{x}) = \sum_{\omega \in \Omega\left[f\right]} c_\omega \prod_{j \in \omega} \mathbb{x}_j
```

where each ``\Omega\left[{f}\right]`` is the multi-linear representation of ``f`` as a set of terms. Each term is given by a unique set of indices ``\omega \subseteq \mathbb{S}`` related to some coefficient ``c_\omega \in \mathbb{T}``. We say that ``\omega \in \Omega\left[{f}\right] \iff c_\omega \neq 0``.
Variables ``\mathbf{x}_i`` are indeed boolean, thus ``f : \mathbb{B}^{n} \to \mathbb{T}``.

## References
 * [1] Endre Boros, Peter L. Hammer, Pseudo-Boolean optimization, Discrete Applied Mathematics, 2002 [{doi}](https://doi.org/10.1016/S0166-218X(01)00341-9)
"""
struct PseudoBooleanFunction{S, T}
    Ω::Dict{Set{S}, T}

    function PseudoBooleanFunction{S, T}(Ω::Dict{<:Union{Set{S}, Nothing}, T}) where {S, T}
        new{S, T}(Dict{Set{S}, T}(isnothing(ω) ? Set{S}() : ω => c for (ω, c) in Ω if !iszero(c)))
    end

    function PseudoBooleanFunction{S, T}(v::Vector) where {S, T}
        Ω = Dict{Set{S}, T}()

        for x in v  
            ω, a = parseterm(S, T, x)
            Ω[ω] = get(Ω, ω, zero(T)) + a
        end
        
        PseudoBooleanFunction{S, T}(Ω)
    end

    function PseudoBooleanFunction{S, T}(x::Base.Generator) where {S, T}
        PseudoBooleanFunction{S, T}(collect(x))
    end

    function PseudoBooleanFunction{S, T}(x::Vararg{Any}) where {S, T}
        PseudoBooleanFunction{S, T}(collect(x))
    end
end

# -*- Alias -*-
const PBF{S, T} = PseudoBooleanFunction{S, T}

#-*- Copy -*-
Base.copy(f::PBF{S, T}) where {S, T} = PBF{S, T}(copy(f.Ω))

function Base.copy!(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    copy!(f.Ω, g.Ω)

    return f
end

# -*- Iterator & Length -*-
Base.keys(f::PBF) = keys(f.Ω)
Base.length(f::PBF) = length(f.Ω)
Base.empty!(f::PBF) = empty!(f.Ω)
Base.isempty(f::PBF) = isempty(f.Ω)
Base.iterate(f::PBF) = iterate(f.Ω)
Base.iterate(f::PBF, i::Int) = iterate(f.Ω, i)
Base.haskey(f::PBF{S, <:Any}, k::Set{S}) where S = haskey(f.Ω, k)
Base.haskey(f::PBF{S, <:Any}, k::S) where S = haskey(f, Set{S}([k]))
Base.haskey(f::PBF{S, <:Any}, ::Nothing) where S = haskey(f, Set{S}())

# -*- Indexing: Get -*-
Base.getindex(f::PBF{S, T}, ω::Set{S}) where {S, T} = get(f.Ω, ω, zero(T))
Base.getindex(f::PBF{S, <:Any}, η::Vector{S}) where {S} = getindex(f, Set{S}(η))
Base.getindex(f::PBF{S, <:Any}, ξ::S...) where {S} = getindex(f, Set{S}(ξ))
Base.getindex(f::PBF{S, <:Any}, ::Nothing) where {S} = getindex(f, Set{S}())

# -*- Indexing: Set -*-
function Base.setindex!(f::PBF{S, T}, c::T, ω::Set{S}) where {S, T}
    if iszero(c) && haskey(f.Ω, ω)
        delete!(f.Ω, ω)
        c
    else
        setindex!(f.Ω, c, ω)
    end
end

Base.setindex!(f::PBF{S, T}, c::T, η::Vector{S}) where {S, T} = setindex!(f, c, Set{S}(η))
Base.setindex!(f::PBF{S, T}, c::T, ξ::S...) where {S, T} = setindex!(f, c, Set{S}(ξ))
Base.setindex!(f::PBF{S, T}, c::T, ::Nothing) where {S, T} = setindex!(f, c, Set{S}())

# -*- Properties -*-
Base.size(f::PBF{S, T}) where {S, T} = length(f) - haskey(f.Ω, Set{S}())

# -*- Comparison: (==, !=, ===, !==)
Base.:(==)(f::PBF{S, T}, g::PBF{S, T}) where {S, T} = f.Ω == g.Ω
Base.:(==)(f::PBF{<:Any, T}, a::T) where T = isscalar(f) && (f[nothing] == a)
Base.:(!=)(f::PBF{S, T}, g::PBF{S, T}) where {S, T} = f.Ω != g.Ω
Base.:(!=)(f::PBF{<:Any, T}, a::T) where T = !isscalar(f) || (f[nothing] != a)
function Base.isapprox(f::PBF{S, T}, g::PBF{S, T}; kw...) where {S, T}
    (length(f) == length(g)) && all(haskey(g, ω) && isapprox(g[ω], f[ω]; kw...) for ω in keys(f))
end
function Base.isapprox(f::PBF{<:Any, T}, a::T; kw...) where T
    isscalar(f) && isapprox(f[nothing], a; kw...)
end

function isscalar(f::PBF{S, <:Any}) where S
    isempty(f) || (length(f) == 1 && haskey(f, nothing))
end

Base.iszero(f::PBF) = isempty(f)
Base.isone(f::PBF) = isscalar(f) && isone(f[nothing])
Base.zero(::Type{<:PBF{S, T}}) where {S, T} = PBF{S, T}()
Base.one(::Type{<:PBF{S, T}}) where {S, T} = PBF{S, T}(one(T))
Base.round(f::PBF{S, T}; kw...) where {S, T} = PBF{S, T}(ω => round(c; kw...) for (ω, c) in f)

# -*- Arithmetic: (+) -*-
function Base.:(+)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    h = copy(f)
    for (ω, c) in g
        h[ω] += c
    end
    h
end

function Base.:(+)(f::PBF{<:Any, T}, c::T) where T
    if iszero(c)
        copy(f)
    else
        g = copy(f)
        g[nothing] += c
        g
    end
end

function Base.:(+)(c::T, f::PBF{<:Any, T}) where T
    +(f, c)
end

# -*- Arithmetic: (-) -*-
function Base.:(-)(f::PBF{S, T}) where {S, T}
    PBF{S, T}(Dict{Set{S}, T}(ω => -c for (ω, c) in f.Ω))
end

function Base.:(-)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    h = copy(f)
    for (ω, c) in g
        h[ω] -= c
    end
    h
end

function Base.:(-)(f::PBF{<:Any, T}, c::T) where T
    if iszero(c)
        copy(f)
    else
        g = copy(f)
        g[nothing] -= c
        g
    end
end

function Base.:(-)(c::T, f::PBF{<:Any, T}) where T
    if iszero(c)
        -(f)
    else
        g = -(f)
        g[nothing] += c
        g
    end
end

# -*- Arithmetic: (*) -*-
function Base.:(*)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    if isempty(f) || isempty(g)
        PBF{S, T}()
    else
        h = PBF{S, T}()
        for (ωᵢ, cᵢ) in f, (ωⱼ, cⱼ) in g
            h[union(ωᵢ, ωⱼ)] += cᵢ * cⱼ
        end
        h
    end
end

function Base.:(*)(f::PBF{S, T}, a::T) where {S, T}
    if iszero(a)
        PBF{S, T}()
    else
        PBF{S, T}(ω => c * a for (ω, c) ∈ f.Ω)
    end
end

function Base.:(*)(a::T, f::PBF{<:Any, T}) where T
    *(f, a)
end

# -*- Arithmetic: (/) -*-
function Base.:(/)(f::PBF{S, T}, a::T) where {S, T}
    if iszero(a)
        throw(DivideError()) 
    else
        PBF{S, T}(Dict(ω => c / a for (ω, c) in f))
    end
end

# -*- Arithmetic: (^) -*-
function Base.:(^)(f::PBF{S, T}, n::Integer) where {S, T}
    if n < 0
        error(DivideError, ": Can't raise Pseudo-boolean function to a negative power")
    elseif n == 0
        one(PBF{S, T})
    elseif n == 1
        copy(f)
    else 
        g = PBF{S, T}(one(T))
        for _ = 1:n
            g *= f
        end
        g
    end
end

# -*- Arithmetic: Evaluation -*-
function (f::PBF{S, T})(x::Dict{S, <:Integer}) where {S, T}
    g = PBF{S, T}()
    for (ω, c) in f
        η = Set{S}()
        for j in ω
            if haskey(x, j)
                if iszero(x[j])
                    c = zero(T)
                    break
                end
            else
                push!(η, j)
            end
        end
        g[η] += c
    end
    g
end

function (f::PBF{S, T})(η::Set{S}) where {S, T}
    sum(c for (ω, c) in f if ω ⊆ η; init=zero(T))
end

function (f::PBF{S, <:Any})(x::Pair{S, <:Integer}...) where {S}
    (f)(Dict{S, Int}(x...))
end

# -*- Type conversion -*-
function Base.convert(U::Type{<:T}, f::PBF{<:Any, T}) where {T}
    if isempty(f)
        zero(U)
    elseif degree(f) == 0
        convert(U, f[nothing])
    else
        error("Can't convert non-constant Pseudo-boolean Function to scalar type $U")
    end
end