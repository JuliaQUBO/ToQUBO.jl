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

# -*- Samplers -*-
abstract type AbstractSampler{V <: Any, S <: Any, T <: Any} <: MOI.AbstractOptimizer end

function sample!(sampler::AbstractSampler; num_reads::Int=1_000)
    t₀ = time()
    results, δt = sample(sampler)
    samples_set = SampleSet{S, T}([Sample{S, T}(states, amount, energy) for (states, amount, energy) in results])
    
    if clean
        sampler.samples_set = samples_set
    else
        merge!(sampler.samples_set, samples_set)
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

function sample!(sampler::AbstractSampler; n::Int=1_000)
    return sample!(sampler; num_reads=n)
end