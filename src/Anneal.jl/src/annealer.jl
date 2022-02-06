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
    raw_optimizer_attribute::Any
    number_of_threads::Int

    objective_value::T
    solve_time_sec::Float64
    termination_status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    raw_status_str::String

    function AnnealerMOI{T}(;
            name::String="",
            silent::Bool=false,
            time_limit_sec::Union{Nothing, Float64}=nothing,
            raw_optimizer_attribute::Any=nothing,
            number_of_threads::Int=1,

            objective_value::T=zero(T),
            solve_time_sec::Float64=NaN,
            termination_status::MOI.TerminationStatusCode=MOI.OPTIMIZE_NOT_CALLED,
            primal_status::Any=MOI.NO_SOLUTION,
            raw_status_str::String=""
        ) where {T}
        return new{T}(
            name,
            silent,
            time_limit_sec,
            raw_optimizer_attribute,
            number_of_threads,
            
            objective_value,
            solve_time_sec,
            termination_status,
            primal_status,
            raw_status_str,
        )
    end
end

# -*- Python Annealing Interfaces -*-
include("pyannealer.jl")

abstract type AbstractAnnealerSettings end

struct NumberOfReads <: MOI.AbstractOptimizerAttribute end
struct NumberOfSweeps <: MOI.AbstractOptimizerAttribute end

# -*- :: Simulated Annealer :: -*-

mutable struct SimulatedAnnealerSettings <: AbstractAnnealerSettings
    num_reads::Int
    num_sweeps::Int

    function SimulatedAnnealerSettings(;
        num_reads::Int=1_000,
        num_sweeps::Int=1_000,
        kws...
        )
        return new(num_reads, num_sweeps)
    end
end

mutable struct SimulatedAnnealer{S, T} <: AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::SampleSet{Int, T}
    moi::AnnealerMOI{T}
    settings::SimulatedAnnealerSettings

    function SimulatedAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            SampleSet{Int, T}(),
            AnnealerMOI{T}(),
            SimulatedAnnealerSettings(; kws...)
        )
    end
end

function anneal(annealer::SimulatedAnnealer{S, T}) where {S, T}
    return py_simulated_annealing(
        annealer.Q,
        annealer.c;
        num_reads=annealer.settings.num_reads,
        num_sweeps=annealer.settings.num_sweeps
    )
end

# -*- :: Quantum Annealer :: -*-
mutable struct QuantumAnnealerSettings <: AbstractAnnealerSettings
    num_reads::Int
    # beta schedule + tuning

    function QuantumAnnealerSettings(;
        num_reads::Int=1_000,
        kws...
        )
        return new(num_reads)
    end
end

mutable struct QuantumAnnealer{S, T} <: AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::SampleSet{Int, T}
    moi::AnnealerMOI{T}
    settings::QuantumAnnealerSettings

    function QuantumAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            SampleSet{Int, T}(),
            AnnealerMOI{T}(),
            QuantumAnnealerSettings(; kws...)
        )
    end
end

function anneal(annealer::QuantumAnnealer{S, T}) where {S, T}
    return py_quantum_annealing(
        annealer.Q,
        annealer.c;
        num_reads=annealer.settings.num_reads
    )
end

# -*- :: Digital Annealer :: -*-
mutable struct DigitalAnnealerSettings <: AbstractAnnealerSettings
    num_reads::Int

    function DigitalAnnealerSettings(;
        num_reads::Int=1_000,
        kws...
        )
        return new(num_reads)
    end
end

mutable struct DigitalAnnealer{S, T} <: AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::SampleSet{Int, T}
    moi::AnnealerMOI{T}
    settings::DigitalAnnealerSettings

    function DigitalAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            SampleSet{Int, T}(),
            AnnealerMOI{T}(),
            DigitalAnnealerSettings(; kws...)
        )
    end
end

function anneal(annealer::DigitalAnnealer{S, T}) where {S, T}
    return py_digital_annealing(
        annealer.Q,
        annealer.c;
        num_reads=annealer.settings.num_reads
    )
end