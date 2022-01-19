struct CustomError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::CustomError)
    print(io, e.msg)
end