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