"""
    QUBOCompilationError(msg::Union{Nothing, String})

This error indicates any failure during QUBO formulation
"""
struct QUBOCompilationError <: Exception
    msg::Union{String,Nothing}

    function QUBOCompilationError(msg::Union{Nothing,String} = nothing)
        return new(msg)
    end
end

function Base.showerror(io::IO, e::QUBOCompilationError)
    if isnothing(e.msg)
        print(io, "The current model can't be converted to QUBO")
    else
        print(io, e.msg)
    end
end

function compilation_error(msg::Union{Nothing,String} = nothing)
    throw(QUBOCompilationError(msg))

    return nothing
end

function compilation_error!(model::Virtual.Model, msg::Union{Nothing,String} = nothing; status::AbstractString = "")
    # Update model status
    MOI.set(model, Attributes.CompilationStatus(), MOI.OTHER_ERROR)
    MOI.set(model, MOI.RawStatusString(), status)

    # Throw error
    compilation_error(msg)

    return nothing
end
