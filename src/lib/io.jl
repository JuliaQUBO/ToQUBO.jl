# -*- IO -*-
# -*- Variable Ordering -*-
Base.isless(u::MOI.VariableIndex, v::MOI.VariableIndex) = isless(u.value, v.value)

# -*- Subscript: Generic -*-
function subscript(i::Int; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return join([var === nothing ? "" : var; par ? "₍" : "" ; i < 0 ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]; par ? "₎" : ""])
end

function subscript(v::Vector; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return join(subscript.(v, var=var, par=par), " ")
end

function subscript(s::Set; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return subscript(sort(collect(s)), var=var, par=par)
end

function subscript(s::Symbol; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return s
end

# -*- Subscript: MOI Stuff -*-
function subscript(i::VI; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return subscript(i.value; var=var, par=par)
end

# -*- Subscript: VirtualVar -*-
function subscript(v::VV; var::Union{Symbol, Nothing}=nothing, par::Bool=false)
    return subscript(v.source, var=v.var, par=isslack(v))
end

# -*- Show: VirtualVar -*-
function Base.show(io::IO, v::VV)
    if isslack(v)
        print(io, var(v))
    else
        print(io, subscript(source(v), var=var(v)))
    end
end

# -*- Show: PBF -*-
function Base.show(io::IO, p::PBO.PBF{S, T}) where {S, T}
    if isempty(p)
        print(io, zero(T))
    else
        print(io, join(join(["$((c < 0) ? (i == 1 ? "-" : " - ") : (i == 1 ? "" : " + "))$(abs(c)) $(subscript(t, var=:x))" for (i, (t, c)) in enumerate(p)])))
    end
end

# -*- JSON -*-
function tojson(model::QUBOModel{T}) where T

    terms = Dict{String, T}()

    for (t, c) in model.E
        if length(t) == 0
            term = ""
        elseif length(t) == 1
            i, = t
            term = "$(i.value) $(i.value)"
        elseif length(t) == 2
            i, j = t
            term = "$(i.value) $(j.value)"
        else
            error("Invalid QUBO Model (degree >= 3)") 
        end

        terms[term] = c
    end

    return JSON.json(terms)
end