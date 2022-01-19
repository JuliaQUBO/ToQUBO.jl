module Anneal

# -*- Sample, SampleSet, AbstractSampler -*-
using MathOptInterface
const MOI = MathOptInterface

# -*- Exports -*-
export Sample, SampleSet, AbstractSampler
export AbstractAnnealer, SimulatedAnnealer, QuantumAnnealer

# -*- Samplers -*-
# -*- Sample & SampleSet -*-
mutable struct Sample{S <: Any, T <: Any}
    states::Vector{S}
    amount::Int
    energy::T
end

mutable struct SampleSet{S <: Any, T <: Any}
    samples::Vector{Sample{S, T}}
    mapping::Dict{S, Int}

    function SampleSet{S, T}() where {S, T}
        return new{S, T}(
            Vector{Sample{S, T}}(),
            Dict{S, Int}()
        )
    end

    """
    Guarantees duplicate removal and that samples are ordered by energy (<), amount (>) & states (<).
    """
    function SampleSet{S, T}(data::Vector{Sample{S, T}}) where {S, T}
        samples = Vector{Sample{S, T}}()
        mapping = Dict{S, Int}()

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
        mapping = Dict{S, Int}(s => I[i] for (s, i) in mapping)

        return new{S, T}(samples, mapping)
    end
end

isempty(x::SampleSet) = isempty(x.samples)

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
            x.mapping[sample.states] = i
            i += 1
        end
    end

    I = sortperm(x.samples, by=(ξ) -> (ξ.energy, -ξ.amount, ξ.states))

    x.samples = x.samples[I]
    x.mapping = Dict{S, Int}(s => I[i] for (s, i) in x.mapping)
    
    nothing
end

# -*- Samplers -*-
abstract type AbstractSampler{T <: Any} <: MOI.AbstractOptimizer end

function sample(::AbstractSampler; kws...)
    return ([], 0.0)
end

function sample!(sampler::AbstractSampler; num_reads::Int=1_000)
    t₀ = time()
    
    results, δt = sample(sampler; num_reads=num_reads)
    sample_set = SampleSet{Int8, T}([Sample{Int8, T}(states, amount, energy) for (states, amount, energy) in results])
    
    if clean
        sampler.sample_set = sample_set
    else
        merge!(sampler.sample_set, sample_set)
    end
    
    t₁ = time()
    Δt = t₁ - t₀

    if sampler.sample_time === NaN
        sampler.sample_time = δt
    else
        sampler.sample_time += δt
    end

    if sampler.total_time === NaN
        sampler.total_time = Δt
    else
        sampler.total_time += Δt
    end

    nothing
end

# -*- Python Annealing Interface -*-
include("./pyanneal.jl")

# -*- Annealers -*-
abstract type AbstractAnnealer{T <: Any} <: AbstractSampler{T} end

struct AnnealerMOIOptions
    name::String
    silent::Bool
    time_limit_sec::Float64
    raw_optimizer_attribute::Any
    number_of_threads::Int

    function AnnealerMOIOptions(;
            name::String="",
            silent::Bool=false,
            time_limit_sec::Float64=NaN,
            raw_optimizer_attribute::Any=nothing,
            number_of_threads::Int=1
        )
        return new(
            name,
            silent,
            time_limit_sec,
            raw_optimizer_attribute,
            number_of_threads
        )
    end
end

mutable struct SimulatedAnnealer{T} <: AbstractAnnealer{T}
    # Problem - QUBO Formulation
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    # Solution
    sample_set::SampleSet{Int8, T}
    total_time::Float64
    sample_time::Float64

    # Settings
    num_reads::Int
    num_sweeps::Int

    # MOI Stuff
    moi::AnnealerMOIOptions

    function SimulatedAnnealer{T}(Q::Dict{Tuple{Int, Int}, T}, c::T; num_reads::Int=1_000, num_sweeps::Int=1_000) where {T}
        return new{T}(
            Q,
            c,
            SampleSet{Int8, T}(),
            NaN,
            NaN,
            num_reads,
            num_sweeps,
            AnnealerMOIOptions()
        )
    end

    function SimulatedAnnealer{T}(; num_reads::Int=1_000, num_sweeps::Int=1_000) where {T}
        return SimulatedAnnealer{T}(
            Dict{Tuple{Int, Int}, T}(), zero(T);
            num_reads=num_reads, num_sweeps=num_sweeps
        )
    end
end

function anneal(annealer::SimulatedAnnealer{T}) where {T}
    return py"py_simulated_annealing"(
        annealer.Q,
        annealer.c,
        num_reads=annealer.num_reads,
        num_sweeps=annealer.num_sweeps
    )::Tuple{Vector{Tuple{Vector{Int8}, Int, T}}, Float64}
end

mutable struct QuantumAnnealer{T} <: AbstractAnnealer{T} end

function anneal(annealer::QuantumAnnealer{T}) where {T}
    return py"py_quantum_annealing"(
        annealer.Q,
        annealer.c,
        num_reads=annealer.num_reads
    )::Tuple{Vector{Tuple{Vector{Int8}, Int, T}}, Float64}
end

# -*- AbstractSampler Interface -*-
sample(annealer::AbstractAnnealer) = anneal(annealer)

include("./moi.jl")

end # module