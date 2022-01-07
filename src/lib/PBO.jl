module PBO

using Random

export PseudoBooleanFunction, PBF
export copy, isempty, length, iterate, getindex, setindex!
export +, -, *, /, ^, ==, !=, ===, !==
export convert, zero, one, print
export qubo, ising


"""
    [1] Endre Boros, Peter L. Hammer Pseudo-Boolean optimization, Discrete Applied Mathematics, 2002
        @ https://doi.org/10.1016/S0166-218X(01)00341-9
"""
# -*- Pseudo-boolean Functions -*-
struct PseudoBooleanFunction{S <: Any, T <: Number} <: AbstractDict{Set{S}, T}
    layers::Dict{Int, Dict{Set{S}, T}}
    degvec::Vector{Int}
    varmap::Dict{S, Int}

    function PseudoBooleanFunction{S, T}(
        layers::Dict{Int, Dict{Set{S}, T}},
        degvec::Vector{Int},
        varmap::Dict{S, Int}) where {S, T}

        return new{S, T}(layers, degvec, varmap)
    end

    # -*- Empty -*-
    function PseudoBooleanFunction{S, T}() where {S, T}
        return new{S, T}(
            Dict{Int, Dict{Set{S}, T}}(),
            Vector{Int}(),
            Dict{S, T}()
        )
    end

    # -*- Constant -*-
    function PseudoBooleanFunction{S, T}(c::T) where {S, T}
        if c === zero(T)
            return PseudoBooleanFunction{S, T}()
        else
            return new{S, T}(
                Dict{Int, Dict{Set{S}, T}}(0 => Dict{Set{S}, T}(Set{S}() => c)),
                Vector{Int}([0]),
                Dict{S, Int}()
            )
        end
        return
    end

    # -*- Pairs (Vectors) -*-
    function PseudoBooleanFunction{S, T}(ps::Pair{Vector{S}, T}...) where {S, T}
        return PseudoBooleanFunction{S, T}((Set{S}(ω) => c for (ω, c) in ps)...)
    end

    # -*- Pairs (Sets) -*-
    function PseudoBooleanFunction{S, T}(ps::Pair{Set{S}, T}...) where {S, T}
        layers = Dict{Int, Dict{Set{S}, T}}()
        varset = Set{S}()

        for (ω, c) in ps
            if c === zero(T)
                continue
            end
            
            n = length(ω)
            union!(varset, ω)

            if haskey(layers, n)
                layer = layers[n]
                if haskey(layer, ω)
                    d = layer[ω] + c
                    if d !== zero(T)
                        layer[ω] = d
                    else
                        delete!(layer, ω)
                        if isempty(layer)
                            delete!(layers, n)
                        end
                    end
                else
                    layer[ω] = c
                end
            else
                layers[n] = Dict{Set{S}, T}(ω => c)
            end
        end
        
        degvec = Vector{Int}(sort(collect(keys(layers))))
        varmap = Dict{S, Int}(v => i for (i, v) in enumerate(sort(collect(varset))))
        return new{S, T}(layers, degvec, varmap)
    end

    # -*- Dictionary -*-
    function PseudoBooleanFunction{S, T}(D::Dict{Set{S}, T}) where {S, T}
        layers = Dict{Int, Dict{Set{S}, T}}()
        varset = Set{S}()

        for (ω, c) in D
            if c === zero(T)
                continue
            end

            n = length(ω)
            union!(varset, ω)

            if haskey(layers, n)
                layers[n][ω] = c
            else
                layers[n] = Dict{Set{S}, T}(ω => c)
            end
        end
        
        degvec = Vector{Int}(sort(collect(keys(layers))))
        varmap = Dict{S, Int}(v => i for (i, v) in enumerate(sort(collect(varset))))
        return new{S, T}(layers, degvec, varmap)
    end
end

# -*- Alias -*-
const PBF{S, T} = PseudoBooleanFunction{S, T}

# -*- Default -*-
function PBF()::PBF{Int, Float64}
    return PBF{Int, Float64}()
end

function PBF(c::Float64)::PBF{Int, Float64}
    return PBF{Int, Float64}(c)
end

# -*- Copy -*-
function Base.copy(p::PBF{S, T})::PBF{S, T} where {S, T}
    layers = Dict{Int, Dict{Set{S}, T}}(i => copy(layer) for (i, layer) in p.layers)
    degvec = copy(p.degvec)
    varmap = copy(p.varmap)
    return PBF{S, T}(layers, degvec, varmap)
end

# -*- Iterator & Length -*-
function Base.length(p::PBF)::Int
    return sum(length.(values(p.layers)))
end

function Base.isempty(p::PBF)::Bool
    return isempty(p.degvec)
end

function Base.iterate(p::PBF)
    if isempty(p)
        return nothing
    else
        item, s = iterate(p.layers[p.degvec[1]])
        return (item, (1, s))
    end
end

function Base.iterate(p::PBF, state::Tuple{Int, Int})
    i, s = state
    if i > length(p.degvec)
        return nothing
    else
        next = iterate(p.layers[p.degvec[i]], s)
        if next === nothing
            if i === length(p.degvec)
                return nothing
            else
                item, s = iterate(p.layers[p.degvec[i + 1]])
                return (item, (i + 1, s))
            end
        else
            item, s = next
            return (item, (i, s))
        end
    end
end

# -*- Indexing: Get -*-
function Base.getindex(p::PBF{S, T}, i::Set{S})::T where {S, T}
    n = length(i)
    if haskey(p.layers, n)
        layer = p.layers[n]
        if haskey(layer, i)
            return layer[i]
        else
            return zero(T)
        end
    else
        return zero(T)
    end
end

function Base.getindex(p::PBF{S, T}, i::Vector{S})::T where {S, T}
    return getindex(p, Set{S}(i))
end

function Base.getindex(p::PBF{S, T}, i::S)::T where {S, T}
    return getindex(p, Set{S}([i]))
end

# -*- Indexing: Set -*-
function Base.setindex!(p::PBF{S, T}, c::T, i::Set{S}) where {S, T}
    n = length(i)
    if haskey(p.layers, n)
        layer = p.layers[n]
        if haskey(layer, i) && c === zero(T)
            delete!(layer, i)
            if isempty(layer)
                delete!(p.layers, n)
                deleteat!(p.degvec, searchsorted(p.degvec, n))
            end
        elseif c !== zero(T)
            layer[i] = c
        end
    elseif c !== zero(T)
        p.layers[n] = Dict{Set{S}, T}(i => c)
        i = searchsorted(p.degvec, n)
        if length(i) === 0
            push!(p.degvec, n)
        else
            insert!(p.degvec, i..., n)
        end
    end
end

function Base.setindex!(p::PBF{S, T}, c::T, i::Vector{S}) where {S, T}
    setindex!(p, Set{S}(i), c)
end

function Base.setindex!(p::PBF{S, T}, c::T, i::S) where {S, T}
    setindex!(p, Set{S}([i]), c)
end

# -*- Properties: Degree & Varmap -*-
function degree(p::PBF)::Int
    if isempty(p)
        return 0
    else
        return last(p.degvec)
    end
end

function varmap(p::PBF)
    return p.varmap
end

# -*- Comparison: (==, !=, ===, !==)
function Base.:(==)(p::PBF{S, T}, q::PBF{S, T})::Bool where {S, T}
    return p.layers == q.layers
end

function Base.:(!=)(p::PBF{S, T}, q::PBF{S, T})::Bool where {S, T}
    return p.layers != q.layers
end

# -*- Arithmetic: (+) -*-
function Base.:(+)(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for (tᵢ, cᵢ) in q
        r[tᵢ] += cᵢ
    end

    return r
end

function Base.:(+)(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    r = copy(p)

    r[Set{S}()] += c
    
    return r
end

function Base.:(+)(c::T, p::PBF{S, T})::PBF{S, T} where {S, T}
    return +(p, c)
end

# -*- Arithmetic: (-) -*-
function Base.:(-)(p::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for layer in values(r.layers), t in keys(layer)
        layer[t] = -layer[t]
    end

    return r
end

function Base.:(-)(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for (tᵢ, cᵢ) in q
        r[tᵢ] -= cᵢ
    end

    return r
end

function Base.:(-)(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    return +(p, -(c))
end

function Base.:(-)(c::T, p::PBF{S, T})::PBF{S, T} where {S, T}
    return +(-(p), c)
end

# -*- Arithmetic: (*) -*-
function Base.:(*)(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    if isempty(p) || isempty(q)
        return PBF{S, T}()
    end

    r = PBF{S, T}()

    for (tᵢ, cᵢ) in p, (tⱼ, cⱼ) in q
        r[union(tᵢ, tⱼ)] += cᵢ * cⱼ
    end

    return r
end

function Base.:(*)(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    if c === 0
        return PBF{S, T}()
    else
        r = copy(p)

        for layer in values(r.layers), t in keys(layer)
            layer[t] *= c
        end

        return r
    end
end

function Base.:(*)(c::T, p::PBF{S, T})::PBF{S, T} where {S, T}
    return *(p, c)
end

# -*- Arithmetic: (/) -*-
function Base.:(/)(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    if c == 0
        error(DivideError, ": division by zero") 
    else
        r = copy(p)

        for layer in values(r.layers), t in keys(layer)
            layer[t] /= c
        end

        return r
    end
end

# -*- Arithmetic: (^) -*-
function Base.:(^)(p::PBF{S, T}, n::Int)::PBF{S, T} where {S, T}
    if n < 0
        error(DivideError, ": Can't divide by Pseudo-boolean function.")
    elseif n == 0
        return one(PBF{S, T})
    elseif n == 1
        return copy(p)
    else 
        r = PBF{S, T}(one(T))

        for _ = 1:n
            r *= p
        end

        return r
    end
end

# -*- Arithmetic: Evaluation -*-
function (p::PBF{S, T})(x::Dict{S, T})::PBF{S, T} where {S, T}
    
    q = PBF{S, T}()
    
    for (t, c) in p
        z = Set{S}()
        for tⱼ in t
            if haskey(x, tⱼ)
                if !x[tⱼ]
                    c = zero(T)
                    break
                end
            else
                push!(z, tⱼ)
            end
        end
        
        q[z] += c
    end

    return q
end

function (p::PBF{S, T})(x::Pair{S, T}...)::PBF{S, T} where {S, T}
    return p(Dict{S, T}(x...))
end

# -*- Type conversion -*-
function Base.convert(::Type{<: T}, p::PBF{S, T})::T where {S, T}
    if isempty(p)
        return zero(T)
    elseif degree(p) === 0
        return p[Set{S}()]
    else
        error("Can't convert Pseudo-boolean Function with variables to scalar type $T")
    end
end

function Base.zero(::Type{PBF{S, T}})::PBF{S, T} where {S, T}
    return PBF{S, T}()
end

function Base.one(::Type{PBF{S, T}})::PBF{S, T} where {S, T}
    return PBF{S, T}(one(T))
end

# -*- Gap & Penalties -*-
function Δ(p::PBF{S, T}; bound::Symbol=:loose)::T where{S, T}
    if bound === :loose
        return sum(abs(c) for (t, c) in p if !isempty(t))
    elseif bound === :tight
        error("Not Implemented: See [1] sec 5.1.1 Majorization")
    else
        error(ArgumentError, ": Unknown bound thightness $bound")
    end
end

function δ(p::PBF{S, T}; bound::Symbol=:loose)::T where{S, T}
    if bound === :loose
        return one(T)
    elseif bound === :tight
        error("Not Implemented: See [1] sec 5.1.1 Majorization")
    else
        error(ArgumentError, ": Unknown bound thightness $bound")
    end
end

# -*- Output -*-
function qubo(::Type{<: AbstractDict}, p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Tuple{Int, Int}, T} ,T} where {S, T}
    if degree(p) >= 3
        error(DomainError, ": Can't convert Pseudo-boolean function with degree greater than 3 to QUBO format. Try using `reduce_degree` before conversion.")
    else
        ∅ = Set{S}()
        x = varmap(p)
        Q = Dict{Tuple{Int, Int}, T}()
        c = zero(T)

        if haskey(p.layers, 0)
            c += p[∅]
        end

        if haskey(p.layers, 1)
            for ((i,), d) in p.layers[1]
                Q[x[i], x[i]] = d
            end
        end

        if haskey(p.layers, 2)
            for ((i, j), d) in p.layers[2]  
                if x[i] < x[j]
                    Q[x[i], x[j]] = d
                else
                    Q[x[j], x[i]] = d
                end
            end
        end

        return (x, Q, c)
    end
end

function ising(::Type{<: AbstractDict}, p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Int, T}, Dict{Tuple{Int, Int}, T} ,T} where {S, T}
    if degree(p) >= 3
        error(DomainError, ": Can't convert Pseudo-boolean function with degree greater than 3 to QUBO format. Try using `reduce_degree` before conversion.")
    end

    x = Dict{S, Int}()
    h = Dict{Int, T}()
    J = Dict{Tuple{Int, Int}, T}()
    c = zero(T)

    return (x, h, J, c)
end

# -*- Output: Default Behavior -*-
function qubo(p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Tuple{Int, Int}, T}, T} where {S, T}
    return qubo(Dict, p)
end

function ising(p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Int, T}, Dict{Tuple{Int, Int}, T}, T} where {S, T}
    return ising(Dict, p)
end

# -*- Degree Reduction -*-
function pick_term(t::Set{S}; tech::Symbol=:sort)::Tuple{S, S, Set{S}} where {S}
    if length(t) < 2
        error("")
    elseif tech === :sort
        x, y, u... = sort(collect(t))
        return (x, y, Set{S}(u))
    elseif tech === :none
        x, y, u... = t
        return (x, y, Set{S}(u))
    else
        shuffle
    end
end

function reduce_term(t::Set{S}; cache::Dict{Set{S}, PBF{S, T}}, slack::Any)::PBF{S, T} where {S, T}
    if length(t) <= 2
        return copy(t)
    else
        x, y, u = pick_term(t; tech=:none)
    end
end

function reduce_degree(p::PBF{S, T}; cache::Dict{Set{S}, PBF{S, T}}, slack::Any)::PBF{S, T} where {S, T}
    if degree(p) <= 2
        return copy(p)
    else
        q = PBF{S, T}()

        for (t, c) in p
            if length(t) >= 3
                q += c * reduce_term(t; cache=cache)
            else
                q[t] += c
            end
        end
    end
end

function reduce_degree(p::PBF{S, T}; cache::Dict{Set{S}, PBF{S, T}})::PBF{S, T} where {S, T}
    return reduce_degree(p, cache=cache, slack=(v -> v === nothing ? 1 : v + 1))
end

function reduce_degree(p::PBF{S, T}; slack::Any)::PBF{S, T} where {S, T}
    return reduce_degree(p, cache=Dict{Set{S}, PBF{S, T}}(), slack=slack)
end

function reduce_degree(p::PBF{S, T})::PBF{S, T} where {S, T}
    return reduce_degree(p, cache=Dict{Set{S}, PBF{S, T}}(), slack=(v -> v === nothing ? 1 : v + 1))
end

end # module