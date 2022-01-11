module Anneal

# -*- Sample, SampleSet, AbstractSampler -*-
using MathOptInterface
const MOI = MathOptInterface

# -*- Exports -*-
export Sample, SampleSet, AbstractSampler
export AbstractAnnealer, SimulatedAnnealer, QuantumAnnealer

# -*- Samplers -*-
include("./sample.jl")

# -*- Python Annealing Interface -*-
using PyCall
include("./pyanneal.jl")

# -*- Annealers -*-
abstract type AbstractAnnealer{V <: Any, S <: Any, T <: Any} <: AbstractSampler{V, S, T} end

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
    return py"py_quantum_annealing"(
        annealer.Q,
        annealer.c,
        num_reads=annealer.num_reads
    )
end

# -*- Aliases -*-
function anneal!(annealer::AbstractAnnealer; kws...)
    return sample!(annealer; kws...)
end

function sample(annealer::AbstractAnnealer{V, S, T})::Tuple{Vector{Tuple{S, Int, T}}, Float64} where {V, S, T}
    anneal(annealer)
end
include("./moi.jl")

end # module