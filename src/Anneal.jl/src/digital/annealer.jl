# -*- :: Digital Annealer :: -*-
mutable struct DigitalAnnealerSettings <: Anneal.AbstractAnnealerSettings
    num_reads::Int

    function DigitalAnnealerSettings(;
        num_reads::Int=1_000,
        kws...
        )
        return new(num_reads)
    end
end

mutable struct DigitalAnnealer{S, T} <: Anneal.AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::Anneal.SampleSet{Int, T}
    moi::Anneal.AnnealerMOI{T}
    settings::DigitalAnnealerSettings

    function DigitalAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            Anneal.SampleSet{Int, T}(),
            Anneal.AnnealerMOI{T}(),
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