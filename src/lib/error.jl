"""
    QUBOError(msg::Union{Nothing, String})

This error indicates any failure during QUBO formulation
"""
struct QUBOError <: Exception
    msg::Union{String,Nothing}

    function QUBOError(msg::Union{Nothing,String} = nothing)
        new(msg)
    end
end

function Base.showerror(io::IO, e::QUBOError)
    if isnothing(e.msg)
        print(io, "The current model can't be converted to QUBO")
    else
        print(io, e.msg)
    end
end
