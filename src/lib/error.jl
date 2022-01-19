# How to build custom errros:
"""
struct CustomError <: Exception
    msg::String
    attr::String
end

function Base.showerror(io::IO, e::CustomError)
    print(io, e.msg, e.attr)
end
"""


struct QUBOError <: Exception
    msg::String
end
