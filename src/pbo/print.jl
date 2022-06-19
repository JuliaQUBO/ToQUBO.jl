function show_term(ω::Set{S}, c::T, isfirst::Bool) where {S, T}
    if isfirst
        "$(c)$(join(ω, "*"))"
    else
        if c < zero(T)
            " - $(abs(c))$(join(ω, "*"))" 
        else 
            " + $(abs(c))$(join(ω, "*"))"
        end
    end
end

Base.show(io::IO, f::PBF) = print(io, join((show_term(ω, c, i == 1) for (i, (ω, c)) ∈ enumerate(f))))