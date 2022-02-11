# -*- :: Simulated Annealer :: -*-

struct NumberOfSweeps <: MOI.AbstractOptimizerAttribute end

mutable struct SimulatedAnnealerSettings <: Anneal.AbstractAnnealerSettings
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

mutable struct SimulatedAnnealer{S, T} <: Anneal.AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::Anneal.SampleSet{Int, T}
    moi::Anneal.AnnealerMOI{T}
    settings::SimulatedAnnealerSettings

    function SimulatedAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            Anneal.SampleSet{Int, T}(),
            Anneal.AnnealerMOI{T}(),
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