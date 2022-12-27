function Base.rand(
    ::Type{PBF{S,T}},
    args...;
    kws...
) where {S,T}
    return rand(Random.GLOBAL_RNG, PBF{S,T}, args...; kws...)
end

function Base.rand(
    rng::Random.AbstractRNG,
    ::Type{PBF{S,T}},
    ω::Set{S},
    n::Integer,
    r::AbstractRange{T},
    d::Integer = 2, # degree
) where {S,T}
    a = first(r)
    b = last(r)
    f = sizehint!(PBF{S,T}(), n)

    for _ = 1:n
        η = Set{S}()

        for _ = 1:d
            if rand(rng) < 0.5
                push!(η, rand(ω))
            end
        end

        c = a + (b - a) * rand(rng)

        f[η] += c
    end

    return f
end