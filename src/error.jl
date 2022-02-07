"""
    QUBOError(msg::Union{Nothing, String})

This error indicates any failure during QUBO formulation
"""
struct QUBOError <: Exception
    msg::Union{Nothing, String}

    function QUBOError(msg::Union{Nothing, String} = nothing)
        return new(msg)
    end
end

function Base.showerror(io::IO, e::QUBOError)
    if e.msg === nothing
        print(io, "The current model could not be converted to QUBO")
    else
        print(io, e.msg)
    end
end