# -*- :: Quantum Annealer :: -*-
mutable struct QuantumAnnealerSettings <: Anneal.AbstractAnnealerSettings
    num_reads::Int
    # beta schedule + tuning

    function QuantumAnnealerSettings(;
        num_reads::Int=1_000,
        kws...
        )
        return new(num_reads)
    end
end

mutable struct QuantumAnnealer{S, T} <: Anneal.AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::Anneal.SampleSet{Int, T}
    moi::Anneal.AnnealerMOI{T}
    settings::QuantumAnnealerSettings

    function QuantumAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            Anneal.SampleSet{Int, T}(),
            Anneal.AnnealerMOI{T}(),
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