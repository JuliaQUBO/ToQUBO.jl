struct QUBOError <: Exception end

function Base.show(io::IO, ::QUBOError)
    print(io, "QUBOError")
end