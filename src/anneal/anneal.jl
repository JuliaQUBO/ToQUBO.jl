module Anneal

using PyCall
using MathOptInterface

const MOI = MathOptInterface

py"""
import time
import neal

def py_simulated_annealing(Q, c = 0.0, **params):
    '''

    Parameters
    ----------
    Q: dict[tuple, float]

    c: float = 0.0
        Base energy (QUBO constant term)

    Returns
    -------
    samples: list[tuple[list[int], int, float]]
        List of sample tuples
            states: list[int]
                Binary states
            amount: int
                Sampling frequency for the given state
            energy: float
                Total energy for the given state
    delta_t: float
        Annealing (Sampling) Time
    '''
    sampler = neal.SimulatedAnnealingSampler()
    
    t_0 = time.perf_counter()
    results = sampler.sample_qubo(Q, **params)
    t_1 = time.perf_counter()
    
    samples = [(list(map(int, s)), int(n), float(e)) for (s, e, n) in results.record]
    delta_t = t_1 - t_0

    return (samples, delta_t)

def py_quantum_annealing(Q, c = 0.0, **params):
    '''
        1. Connect to D-Wave Leap API
    '''
    raise NotImplementedError()
"""

# -*- Sample & SampleSet -*-
mutable struct Sample{S <: Any, T <: Any}
    states::S
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

# -*- Annealers -*-
abstract type AbstractAnnealer{V <: Any, S <: Any, T <: Any}
    # Problem
    # Q::Dict{Tuple{V, V}, T}
    # c::T

    # Solution
    # samples_set::SampleSet{S, T}

    # Timing
    # total_time::Float64
    # anneal_time::Float64

    # Settings
    # # num_reads::Int
    # # num_sweeps::Int
end

function anneal!(annealer::AbstractAnnealer{V, S, T}; clean::Bool=true)::Nothing where {V, S, T}
    t₀ = time()
    results, δt = anneal(annealer)
    samples_set = SampleSet{S, T}([Sample{S, T}(states, amount, energy) for (states, amount, energy) in results])
    
    if clean
        annealer.samples_set = samples_set
    else
        merge!(annealer.samples_set, samples_set)
    end

    t₁ = time()
    Δt = t₁ - t₀

    if annealer.total_time === NaN
        annealer.total_time = Δt
    else
        annealer.total_time += Δt
    end

    if annealer.anneal_time === NaN
        annealer.anneal_time = δt
    else
        annealer.anneal_time += δt
    end

    nothing
end

function anneal!(annealer::AbstractAnnealer{V, S, T}, Q::Dict{Tuple{V, V}, T}, c::T) where {V, S, T}
    annealer.Q = Q
    annealer.c = c
    anneal!(annealer; clean=true)
end

mutable struct SimulatedAnnealer{V, S, T} <: AbstractAnnealer{V, S, T}
    # Problem
    Q::Dict{Tuple{V, V}, T}
    c::T

    # Solution
    samples_set::SampleSet{S, T}

    total_time::Float64
    anneal_time::Float64

    # Settings
    num_reads::Int
    num_sweeps::Int

    function SimulatedAnnealer{V, S, T}(; num_reads::Int=1000, num_sweeps::Int=1000) where {V, S, T}
        return new{V, S, T}(
            Dict{Tuple{V, V}, T}(),
            zero(T),
            SampleSet{S, T}(),
            NaN,
            NaN,
            num_reads,
            num_sweeps
        )
    end

    function SimulatedAnnealer{V, S, T}(Q::Dict{Tuple{V, V}, T}, c::T; num_reads::Int=1000, num_sweeps::Int=1000) where {V, S, T}
        return new{V, S, T}(
            Q,
            c,
            SampleSet{S, T}(),
            NaN,
            NaN,
            num_reads,
            num_sweeps
        )
    end
end

function anneal(annealer::SimulatedAnnealer{V, S, T})::Tuple{Vector{Tuple{S, Int, T}}, Float64} where {V, S, T}
    return py"py_simulated_annealing"(
        annealer.Q,
        annealer.c,
        num_reads=annealer.num_reads,
        num_sweeps=annealer.num_sweeps
    )
end

mutable struct QuantumAnnealer{V, S, T} <: AbstractAnnealer{V, S, T} end

function anneal(annealer::QuantumAnnealer{V, S, T})::Tuple{Vector{Tuple{S, Int, T}}, Float64} where {V, S, T}
    return py"py_quantum_annealing"()
end


end # module