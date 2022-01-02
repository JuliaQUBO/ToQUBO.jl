# -*- IO -*-

# -*- Subscript: Generic -*-
function subscript(i::Int; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return join([var === nothing ? "" : var; par ? "₍" : "" ; i < 0 ? Char(0x208B) : ""; [Char(0x2080 + j) for j in reverse(digits(abs(i)))]; par ? "₎" : ""])
end

function subscript(i::Vector; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return join(subscript.(i, var=var, par=par), " ")
end

function subscript(i::Set; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return subscript(sort(collect(i)), var=var, par=par)
end

# -*- Subscript: MOI Stuff -*-
function subscript(i::VI; var::Union{Symbol, Nothing}=nothing, par::Bool=false)::String
    return subscript(i.value; var=var, par=par)
end