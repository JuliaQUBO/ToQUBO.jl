"""
    CompilationError(msg::Union{Nothing, String})

This error indicates any failure during QUBO formulation
"""
struct CompilationError <: Exception
    msg::Union{String,Nothing}

    function CompilationError(msg::Union{Nothing,String} = nothing)
        return new(msg)
    end
end

function Base.showerror(io::IO, e::CompilationError)
    if isnothing(e.msg)
        print(io, "The current model can't be converted to QUBO")
    else
        print(io, e.msg)
    end
end

function compilation_error(msg::Union{Nothing,String} = nothing)
    throw(CompilationError(msg))

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
