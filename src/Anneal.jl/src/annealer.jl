# -*- Annealers -*-
abstract type AbstractAnnealer{S <: Any, T <: Any} <: MOI.AbstractOptimizer end

function anneal!(annealer::AbstractAnnealer{S, T}) where {S, T}
    result, δt = anneal(annealer)

    sample_set = SampleSet{Int, T}([Sample{Int, T}(sample...) for sample in result])
    
    merge!(annealer.sample_set, sample_set)

    if annealer.moi.solve_time_sec === NaN
        annealer.moi.solve_time_sec = δt
    else
        annealer.moi.solve_time_sec += δt
    end

    nothing
end

mutable struct AnnealerMOI{T <: Any}

    name::String
    silent::Bool
    time_limit_sec::Union{Nothing, Float64}
    raw_optimizer_attributes::Dict{String, Any}
    number_of_threads::Int

    objective_value::T
    solve_time_sec::Float64
    termination_status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    raw_status_string::String

    function AnnealerMOI{T}() where {T}
        return new{T}(
            "",
            false,
            nothing,
            Dict{String, Any}(),
            1,
            
            zero(T),
            NaN,
            MOI.OPTIMIZE_NOT_CALLED,
            MOI.NO_SOLUTION,
            "",
        )
    end
end

# -*- Python Annealing Interfaces -*-
include("pyannealer.jl")

abstract type AbstractAnnealerSettings end

struct NumberOfReads <: MOI.AbstractOptimizerAttribute end

include("./simulated/annealer.jl")
include("./quantum/annealer.jl")
include("./digital/annealer.jl")