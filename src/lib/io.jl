# -*- IO -*-

# -*- Subscript: Generic -*-
function subscript(i::Int; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return join([var === nothing ? "" : var; par ? "₍" : "" ; i < 0 ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]; par ? "₎" : ""])
end

function subscript(v::Vector; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return join(subscript.(v, var=var, par=par), " ")
end

function subscript(s::Set; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return subscript(sort(collect(s)), var=var, par=par)
end

function subscript(s::Symbol; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return s
end

# -*- Subscript: MOI Stuff -*-
function subscript(i::VI; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return subscript(i.value; var=var, par=par)
end

# -*- Show: PBF -*-
function Base.show(io::IO, p::PBO.PBF{S, T}) where {S, T}
    if isempty(p)
        print(io, zero(T))
    else
        print(io, join(join(["$((c < 0) ? (i == 1 ? "-" : " - ") : (i == 1 ? "" : " + "))$(abs(c)) $(subscript(t, var=:x))" for (i, (t, c)) in enumerate(p)])))
    end
end