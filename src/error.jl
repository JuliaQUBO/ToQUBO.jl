"""
    QUBOError(msg::String)

This error indicates any failure during QUBO formulation
"""
struct QUBOError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::QUBOError)
    print(io, e.msg)
end