"""
    [1] Endre Boros, Peter L. Hammer Pseudo-Boolean optimization, Discrete Applied Mathematics, 2002
        @ https://doi.org/10.1016/S0166-218X(01)00341-9
"""
include("./bidict.jl")

# -*- Pseudo-boolean Functions -*-
struct PseudoBooleanFunction{S <: Any, T <: Number} <: AbstractDict{Set{S}, T}
    layers::Dict{Int, Dict{Set{Int}, T}}
    levels::Vector{Int}
    varmap::BiDict{S, Int}

    # -*- Empty -*-
    function PseudoBooleanFunction{S, T}() where {S, T}
        layers = Dict{Int, Dict{Set{Int}, T}}()
        levels = Vector{Int}()
        varmap = BiDict{S, Int}()
        return new{S, T}(layers, levels, varmap)
    end

    # -*- Constant -*-
    function PseudoBooleanFunction{S, T}(c::T) where {S, T}
        if c === zero(T)
            layers = Dict{Int, Dict{Set{S}, T}}()
            levels = Vector{Int}([])
        else
            layers = Dict{Int, Dict{Set{S}, T}}(0 => Dict{Set{S}, T}(Set{S}() => c))
            levels = Vector{Int}([0])
        end
        varmap = BiDict{S, Int}()
        return new{S, T}(layers, levels, varmap)
    end

    # -*- Pairs (Vectors) -*-
    function PseudoBooleanFunction{S, T}(P::Pair{Vector{S}, T}...) where {S, T}
        layers = Dict{Int, Dict{Set{S}, T}}()
        
        for (t, c) in P
            if c === zero(T)
                continue
            end
            n = length(t)
            t = Set{S}(t)
            if haskey(layers, n)
                layer = layers[n]
                if haskey(layer, t)
                    w = layer[t] + c
                    if w !== zero(T)
                        layer[t] = w
                    else
                        delete!(layer, t)
                        if isempty(layer)
                            delete!(layers, n)
                        end
                    end
                else
                    layer[t] = c
                end
            else
                layers[n] = Dict{Set{S}, T}(t => c)
            end
        end
        
        levels = sort(collect(keys(layers)))

        return new{S, T}(layers, levels)
    end

    # -*- Pairs (Sets) -*-
    function PseudoBooleanFunction{S, T}(P::Pair{Set{S}, T}...) where {S, T}
        layers = Dict{Int, Dict{Set{S}, T}}()

        for (t, c) in P
            if c === zero(T)
                continue
            end

            n = length(t)
            if haskey(layers, n)
                layer = layers[n]
                if haskey(layer, t)
                    w = layer[t] + c
                    if w !== zero(T)
                        layer[t] = w
                    else
                        delete!(layer, t)
                        if isempty(layer)
                            delete!(layers, n)
                        end
                    end
                else
                    layer[t] = c
                end
            else
                layers[n] = Dict{Set{S}, T}(t => c)
            end
        end
        
        levels = sort(collect(keys(layers)))
        
        return new{S, T}(layers, levels)
    end

    # -*- Dictionary -*-
    function PseudoBooleanFunction{S, T}(D::Dict{Set{S}, T}) where {S, T}
        layers = Dict{Int, Dict{Set{S}, T}}()

        for (t, c) in D
            if c === zero(T)
                continue
            end

            n = length(t)

            if haskey(layers, n)
                layers[n][t] = c
            else
                layers[n] = Dict{Set{S}, T}(t => c)
            end
        end
        
        levels = sort(collect(keys(layers)))
        
        return new{S, T}(layers, levels)
    end

    # -*- I.K.E.W.I.D -*-
    function PseudoBooleanFunction{S, T}(layers::Dict{Int, Dict{Set{S}, T}}) where {S, T}
        return new{S, T}(layers, sort(collect(keys(layers))))
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
    return PBF{S, T}(Dict{Int, Dict{Set{S}, T}}(i => copy(layer) for (i, layer) in p.layers))
end

# -*- Iterator & Length -*-
function Base.length(p::PBF)::Int
    return sum(length.(values(p.layers)))
end

function Base.isempty(p::PBF)::Bool
    return isempty(p.levels)
end

function Base.iterate(p::PBF)
    if isempty(p)
        return nothing
    else
        item, s = iterate(p.layers[p.levels[1]])
        return (item, (1, s))
    end
end

function Base.iterate(p::PBF, state::Tuple{Int, Any})
    i, s = state
    if i > length(p.levels)
        return nothing
    else
        next = iterate(p.layers[p.levels[i]], s)
        if next === nothing
            if i === length(p.levels)
                return nothing
            else
                item, s = iterate(p.layers[p.levels[i + 1]])
                return (item, (i + 1, s))
            end
        else
            item, s = next
            return (item, (i, s))
        end
    end
end

# -*- Indexing: Get -*-
function Base.getindex(P::PBF{S, T}, i::Set{S})::T where {S, T}
    n = length(i)
    if haskey(P.layers, n)
        layer = P.layers[n]
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
                deleteat!(p.levels, searchsorted(p.levels, n))
            end
        elseif c !== zero(T)
            layer[i] = c
        end
    elseif c !== zero(T)
        p.layers[n] = Dict{Set{S}, T}(i => c)
        i = searchsorted(p.levels, n)
        if length(i) === 0
            push!(p.levels, n)
        else
            insert!(p.levels, i..., n)
        end
    end
end

function Base.setindex!(p::PBF{S, T}, c::T, i::Vector{S}) where {S, T}
    setindex!(p, Set{S}(i), c)
end

function Base.setindex!(p::PBF{S, T}, c::T, i::S) where {S, T}
    setindex!(p, Set{S}([i]), c)
end

# -*- Properties -*-
function degree(p::PBF)::Int
    if isempty(p)
        return 0
    else
        return last(p.levels)
    end
end

function vars(p::PBF{S, T})::Vector{S} where {S, T}

end

# -*- Arithmetic: (+) -*-
function Base.:+(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for (tᵢ, cᵢ) in q
        r[tᵢ] += cᵢ
    end

    return r
end

function Base.:+(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    r = copy(p)

    p[Set{S}()] += c
    
    return r
end

function Base.:+(c::T, p::PBF{S, T})::PBF{S, T} where {S, T}
    return +(p, c)
end

# -*- Arithmetic: (-) -*-
function Base.:-(p::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for layer in values(r.layers), t in keys(layer)
        layer[t] = -layer[t]
    end

    return r
end

function Base.:-(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    r = copy(p)

    for (tᵢ, cᵢ) in q
        r[tᵢ] -= cᵢ
    end

    return r
end

function Base.:-(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    r = copy(p)

    p[Set{S}()] -= c
    
    return r
end

# -*- Arithmetic: (*) -*-
function Base.:*(p::PBF{S, T}, q::PBF{S, T})::PBF{S, T} where {S, T}
    if isempty(p) || isempty(q)
        return PBF{S, T}()
    end

    r = PBF{S, T}()

    for (tᵢ, cᵢ) in p, (tⱼ, cⱼ) in q
        r[union(tᵢ, tⱼ)] += cᵢ * cⱼ
    end

    return r
end

function Base.:*(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
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

function Base.:*(c::T, p::PBF{S, T})::PBF{S, T} where {S, T}
    return *(p, c)
end

# -*- Arithmetic: (/) -*-
function Base.:/(p::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
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
function Base.:^(p::PBF{S, T}, n::Int)::PBF{S, T} where {S, T}
    if n < 0
        error(DivideError, ": Can't divide by Pseudo-boolean function.")
    end

    r = PBF{S, T}(one(T))

    for _ = 1:n
        r *= p
    end

    return r
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
function Base.convert(::Type{T}, p::PBF{S, T})::T where {S, T}
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

function Base.print(io::IO, p::PBF{S, T}) where {S, T}
    if isempty(p)
        print(io, zero(T))
    else
        print(io, join(join(["$((c < 0) ? (i == 1 ? "-" : " - ") : (i == 1 ? "" : " + "))$(abs(c)) $(subscript(t, var=:x))" for (i, (t, c)) in enumerate(p)])))
    end
end

# -*- Output -*-
function qubo(::Type{<: AbstractDict}, p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Tuple{Int, Int}, T} ,T} where {S, T}
    if degree(p) >= 3
        error("Can't convert Pseudo-boolean function with degree greater than 3 to QUBO format. Try using `reduce_degree` before conversion.")
    else
        k = 1
        x = Dict{S, Int}()
        Q = Dict{Tuple{Int, Int}, T}()
        c = zero(T)

        if haskey(p.layers, 0)
            c += p[Set{S}()]
        end

        if haskey(p.layers, 1)
            for (t, d) in p.layers[1]
                (i,) = t

                if !haskey(x, i)
                    x[i] = k
                    k += 1
                end

                Q[x[i], x[i]] = d
            end
        end

        if haskey(p.layers, 2)
            for (t, d) in p.layers[2]
                (i, j) = t
                
                if !haskey(x, i)
                    x[i] = k
                    k += 1
                end

                if !haskey(x, j)
                    x[j] = k
                    k += 1
                end

                Q[x[i], x[j]] = d
            end
        end

        return (x, Q, c)
    end
end

# -*- Gap -*-
function Δ(p::PBF{S, T}; bound::Symbol=:loose)::T where{S, T}
    if bound === :loose
        return sum(abs(c) for (t, c) in p if !isempty(t))
    else
        error("Unknown bound thightness $bound")
    end
end

function δ(p::PBF{S, T}; bound::Symbol=:loose)::T where{S, T}
    if bound === :loose
        return minimum(abs(c) for (t, c) in p if !isempty(t))
    else
        error("Unknown bound thightness $bound")
    end
end

# -*- Output: Default Behavior -*-
function qubo(p::PBF{S, T})::Tuple{Dict{S, Int}, Dict{Tuple{Int, Int}, T}, T} where {S, T}
    return qubo(Dict, p)
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
    end
end

function reduce_term(t::Set{S}; cache::Dict{Set{S}, PBF{S, T}}, slack::Any)::PBF{S, T} where {S, T}
    if length(t) <= 2
        return copy(t)
    else

    end
end

function reduce_degree(p::PBF{S, T}; cache::Dict{Set{S}, PBF{S, T}}, slack::Any)::PBF{S, T} where {S, T}
    if degree(p) <= 2
        return copy(p)
    else
        q = PBF{S, T}()
        w = nothing

        M = 1.0 + 2.0 * Δ(f)

        for k in p.levels
            for (S, c) in p.layers[k]
                if k <= 2
                    q[tᵢ] += cᵢ
                elseif haskey(cache, tᵢ)
                    q += cᵢ * cache[tᵢ]
                else # reduce tᵢ
                    if tech === :sub
                        # -*- Reduction by Substitution -*-
                        w = slack(w)
            
                        # Here we take two variables out "at random", not good
                        # I suggest some function `pick_two(model, t, cache, ...)`
                        # choose based on cached reduction results
                        x, y, z... = t 
            
                        α = convert(T, 2) # TODO: How to compute α? (besides α > 1)
            
                        r = reduce_term(model, Set{S}([w, z...]), 1, tech=tech)
                        s = Posiform{S, T}([x, y] => 1, [x, w] => -2, [y, w] => -2, [w] => 3)
            
                        p = c * (r + M * s)
                    elseif tech === :min
                        # -*- Reduction by Minimum Selection -*-
                        w = addslack(model, 1, offset=0)
            
                        # TODO: Read comment above about this construct
                        x, y, z... = t
            
                        if c < 0
                            r = reduce_term(model, Set{S}([w, z...]), c, tech=tech)
                            s = Posiform{S, T}([x, w] => c, [y, w] => c, [w] => -2 * c)
                            
                            p = r + s
                        else
                            rˣ = reduce_term(model, Set{S}([x, z...]), c, tech=tech)
                            rʸ = reduce_term(model, Set{S}([y, z...]), c, tech=tech)
                            rᶻ = reduce_term(model, Set{S}([z...]), -c, tech=tech)
                            rʷ = reduce_term(model, Set{S}([w, z...]), c, tech=tech)
                            s = Posiform{S, T}([x, w] => c, [y, w] => c, [x, y] => c, [x] => -c, [y] => -c, [w] => -c, [] => c)
                            
                            p = rˣ + rʸ + rᶻ + rʷ + s
                        end
                    else
                        error("Unknown reduction technique '$tech'")
                    end
                end 
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