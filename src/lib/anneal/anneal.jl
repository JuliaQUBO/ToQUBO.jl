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

Base.isempty(x::SampleSet) = isempty(x.samples)

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
abstract type AbstractAnnealer{T <: Any} <: MOI.AbstractOptimizer end

function anneal!(annealer::AbstractAnnealer{T}; kws...) where {T}
    t₀ = time()
    
    result, δt = anneal(annealer; kws...)

    sample_set = SampleSet{Int, T}([Sample{Int, T}(sample...) for sample in result])
    
    merge!(annealer.sample_set, sample_set)
    
    t₁ = time()

    Δt = t₁ - t₀

    if annealer.anneal_time === NaN
        annealer.anneal_time = δt
    else
        annealer.anneal_time += δt
    end

    if annealer.total_time === NaN
        annealer.total_time = Δt
    else
        annealer.total_time += Δt
    end

    nothing
end

mutable struct AnnealerMOI

    name::String
    silent::Bool
    time_limit_sec::Float64
    raw_optimizer_attribute::Any
    number_of_threads::Int

    function AnnealerMOI(;
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

# -*- Python Annealing Interface -*-
include("pyanneal.jl")

mutable struct SimulatedAnnealer{T} <: AbstractAnnealer{T}
    # QUBO Formulation
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    # Solution
    sample_set::SampleSet{Int, T}

    # Timing
    total_time::Float64
    anneal_time::Float64

    # MOI Stuff
    moi::AnnealerMOI

    function SimulatedAnnealer{T}(Q::Dict{Tuple{Int, Int}, T}, c::T = zero(T)) where {T}
        return new{T}(
            Q,
            c,
            SampleSet{Int, T}(),
            NaN,
            NaN,
            AnnealerMOI()
        )
    end

    function SimulatedAnnealer{T}() where {T}
        return SimulatedAnnealer{T}(Dict{Tuple{Int, Int}, T}(), zero(T))
    end
end

# -*- Aliases -*-
function SimulatedAnnealer(Q::Dict{Tuple{Int, Int}, Float64}, c::Float64 = 0.0)
    return SimulatedAnnealer{Float64}(Q, c)
end

function SimulatedAnnealer()
    return SimulatedAnnealer{Float64}()
end

function anneal(annealer::SimulatedAnnealer{T}; num_reads::Int=1_000, num_sweeps::Int=1_000, kws...) where {T}
    return py_simulated_annealing(
        annealer.Q,
        annealer.c;
        num_reads=num_reads,
        num_sweeps=num_sweeps
    )::Tuple{Vector{Tuple{Vector{Int}, Int, T}}, Float64}
end

mutable struct QuantumAnnealer{T} <: AbstractAnnealer{T}
    # QUBO Formulation
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    # Solution
    sample_set::SampleSet{Int, T}

    # Timing
    total_time::Float64
    anneal_time::Float64

    # MOI Stuff
    moi::AnnealerMOI

    function QuantumAnnealer{T}(Q::Dict{Tuple{Int, Int}, T}, c::T) where {T}
        return new{T}(
            Q,
            c,
            SampleSet{Int, T}(),
            NaN,
            NaN,
            AnnealerMOI()
        )
    end

    function QuantumAnnealer{T}() where {T}
        return QuantumAnnealer{T}(Dict{Tuple{Int, Int}, T}(), zero(T))
    end
end

function anneal(annealer::QuantumAnnealer{T}; num_reads::Int=1_000, num_sweeps::Int=1_000, kws...) where {T}
    return py_quantum_annealing(
        annealer.Q,
        annealer.c;
        num_reads=num_reads,
        num_sweeps=num_sweeps
    )::Tuple{Vector{Tuple{Vector{Int}, Int, T}}, Float64}
end

# -*- :: MathOptInterface :: -*-
include("moi.jl")

end # module