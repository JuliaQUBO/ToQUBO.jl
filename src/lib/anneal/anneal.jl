module Anneal

# -*- Sample, SampleSet, AbstractSampler -*-
using MathOptInterface
const MOI = MathOptInterface

# -*- Exports -*-
export Sample, SampleSet
export AbstractAnnealer, SimulatedAnnealer, QuantumAnnealer, Optimizer

# -*- Samplers -*-
# -*- Sample & SampleSet -*-
mutable struct Sample{S <: Any, T <: Any}
    states::Vector{S}
    amount::Int
    energy::T
end

mutable struct SampleSet{S <: Any, T <: Any}
    samples::Vector{Sample{S, T}}
    mapping::Dict{Vector{S}, Int}

    function SampleSet{S, T}() where {S, T}
        return new{S, T}(
            Vector{Sample{S, T}}(),
            Dict{Vector{S}, Int}()
        )
    end

    """
    Guarantees duplicate removal and that samples are ordered by energy (<), amount (>) & states (<).
    """
    function SampleSet{S, T}(data::Vector{Sample{S, T}}) where {S, T}
        samples = Vector{Sample{S, T}}()
        mapping = Dict{Vector{S}, Int}()

        i = 1

        for sample in data
            if haskey(mapping, sample.states)
                samples[mapping[sample.states]].amount += sample.amount
            else
                push!(samples, sample)
                mapping[sample.states] = i
                i += 1
            end
        end
        
        I = sortperm(samples, by=(ξ) -> (ξ.energy, -ξ.amount, ξ.states))

        samples = samples[I]
        mapping = Dict{Vector{S}, Int}(s => I[i] for (s, i) in mapping)

        return new{S, T}(samples, mapping)
    end
end

Base.isempty(s::SampleSet) = isempty(s.samples)
Base.length(s::SampleSet) = length(s.samples)

function Base.iterate(s::SampleSet)
    return iterate(s.samples)
end

function Base.iterate(s::SampleSet, i::Int)
    return iterate(s.samples, i)
end

function merge(x::SampleSet{S, T}, y::SampleSet{S, T})::SampleSet{S, T} where {S, T}
    return SampleSet{S, T}(Vector{Sample{S, T}}([x.samples; y.samples]))
end

function merge!(x::SampleSet{S, T}, y::SampleSet{S, T})::Nothing where {S, T}
    i = length(x.samples)

    for sample in y.samples
        if haskey(x.mapping, sample.states)
            x.samples[x.mapping[sample.states]].amount += sample.amount
        else
            push!(x.samples, sample)
            i = x.mapping[sample.states] = i + 1
        end
    end

    I = sortperm(x.samples, by=(ξ) -> (ξ.energy, -ξ.amount, ξ.states))

    x.samples = x.samples[I]
    x.mapping = Dict{Vector{S}, Int}(s => I[i] for (s, i) in x.mapping)
    
    nothing
end

# -*- Annealers -*-
abstract type AbstractAnnealer{S <: Any, T <: Any} <: MOI.AbstractOptimizer end

function anneal!(annealer::AbstractAnnealer{S, T}; kws...) where {S, T}
    result, δt = anneal(annealer; kws...)

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
    time_limit_sec::Float64
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
            time_limit_sec::Float64=NaN,
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

# -*- Python Annealing Interface -*-
include("pyanneal.jl")

mutable struct SimulatedAnnealer{S, T} <: AbstractAnnealer{S, T}
    # QUBO Formulation
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    # Solution
    sample_set::SampleSet{Int, T}

    # MOI Stuff
    moi::AnnealerMOI{T}

    function SimulatedAnnealer{S, T}(x::Dict{S, Int}, Q::Dict{Tuple{Int, Int}, T}, c::T=zero(T)) where {S, T}
        return new{S, T}(
            x,
            Q,
            c,
            SampleSet{Int, T}(),
            AnnealerMOI{T}()
        )
    end

    function SimulatedAnnealer{T}(n::Int, Q::Dict{Tuple{Int, Int}, T}, c::T=zero(T)) where {T}
        return new{Int, T}(
            Dict{Int, Int}(i => i for i=1:n),
            Q,
            c,
            SampleSet{Int, T}(),
            AnnealerMOI{T}()
        )
    end

    function SimulatedAnnealer{S, T}() where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            SampleSet{Int, T}(),
            AnnealerMOI{T}()
        )
    end
end

function anneal(annealer::SimulatedAnnealer{S, T}; num_reads::Int=1_000, num_sweeps::Int=1_000, kws...) where {S, T}
    return py_simulated_annealing(
        annealer.Q,
        annealer.c;
        num_reads=num_reads,
        num_sweeps=num_sweeps
    )::Tuple{Vector{Tuple{Vector{Int}, Int, T}}, Float64}
end

mutable struct QuantumAnnealer{S, T} <: AbstractAnnealer{S, T}
    # QUBO Formulation
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    # Solution
    sample_set::SampleSet{Int, T}

    # MOI Stuff
    moi::AnnealerMOI{T}

    function QuantumAnnealer{S, T}() where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            SampleSet{Int, T}(),
            AnnealerMOI{T}()
        )
    end
end

function anneal(annealer::QuantumAnnealer{S, T}; num_reads::Int=1_000, num_sweeps::Int=1_000, kws...) where {S, T}
    return py_quantum_annealing(
        annealer.Q,
        annealer.c;
        num_reads=num_reads,
        num_sweeps=num_sweeps
    )::Tuple{Vector{Tuple{Vector{Int}, Int, T}}, Float64}
end

# -*- :: MathOptInterface :: -*-
include("moi.jl")

# -*- :: View :: -*-
include("view.jl")

end # module