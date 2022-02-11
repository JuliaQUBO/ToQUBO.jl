# -*- :: Template Annealer :: -*-

struct SomeAttribute <: MOI.AbstractOptimizerAttribute end

mutable struct TemplateAnnealerSettings <: Anneal.AbstractAnnealerSettings
    num_reads::Int
    some_attribute::Any

    function TemplateAnnealerSettings(;
        num_reads::Int=1_000,
        some_attribute::Any=nothing,
        kws...
        )
        return new(num_reads, some_attribute)
    end
end

mutable struct TemplateAnnealer{S, T} <: Anneal.AbstractAnnealer{S, T}
    x::Dict{S, Int}
    Q::Dict{Tuple{Int, Int}, T}
    c::T

    sample_set::Anneal.SampleSet{Int, T}
    moi::Anneal.AnnealerMOI{T}
    settings::TemplateAnnealerSettings

    function TemplateAnnealer{S, T}(; kws...) where {S, T}
        return new{S, T}(
            Dict{S, Int}(),
            Dict{Tuple{Int, Int}, T}(),
            zero(T),
            Anneal.SampleSet{Int, T}(),
            Anneal.AnnealerMOI{T}(),
            TemplateAnnealerSettings(; kws...)
        )
    end
end

function anneal(annealer::TemplateAnnealer{S, T}) where {S, T}
    return py_template_annealing(
        annealer.Q,
        annealer.c;
        num_reads=annealer.settings.num_reads,
        some_attribute=annealer.settings.some_attribute
    )
end