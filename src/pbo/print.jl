function showvar end

showvar(x::Any) = print(x)
showvar(x::Integer, v::Symbol = :x) = join([v; Char(0x2080) .+ reverse(digits(x))])

function showterm(ω::Set{S}, c::T, isfirst::Bool) where {S, T}
    if isfirst
        "$(c)$(join(showvar.(ω), "*"))"
    else
        if c < zero(T)
            " - $(abs(c))$(join(showvar.(ω), "*"))" 
        else 
            " + $(abs(c))$(join(showvar.(ω), "*"))"
        end
    end
end

Base.show(io::IO, f::PBF) = print(io, join((showterm(ω, c, i == 1) for (i, (ω, c)) in enumerate(f))))