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

function Base.getindex(s::SampleSet, i::Int)
    return getindex(s.samples, i)
end

function merge(x::SampleSet{S, T}, y::SampleSet{S, T}) where {S, T}
    return SampleSet{S, T}(Vector{Sample{S, T}}([x.samples; y.samples]))
end

function merge!(x::SampleSet{S, T}, y::SampleSet{S, T}) where {S, T}
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

# -*- :: Samplers :: -*-
abstract type AbstractSampler{T <: Any} <: MOI.AbstractOptimizer end

abstract type AbstractSamplerSettings{T <: Any} end

abstract type AbstractMOI{T <: Any} end

const SamplingResults = Vector{Tuple{Vector{Int}, Int, Float64}}

function sample!(sampler::AbstractSampler{T}) where {T}
    result, δt = sample(sampler)::Tuple{SamplingResults, Float64}

    sample_set = SampleSet{Int, T}([Sample{Int, T}(sample...) for sample in result])
    
    merge!(sampler.sample_set, sample_set)

    if sampler.moi.solve_time_sec === NaN
        sampler.moi.solve_time_sec = δt
    else
        sampler.moi.solve_time_sec += δt
    end

    nothing
end

function init!(::AbstractSampler) end

function energy(sampler::AbstractSampler{T}, s::Vector{Int}) where {T}
    return sum(s[i] * s[j] * Qᵢⱼ for ((i, j), Qᵢⱼ) ∈ sampler.Q; init=sampler.c)
end

Base.@kwdef mutable struct SamplerMOI{T} <: AbstractMOI{T}
    name::String = ""
    silent::Bool = false
    time_limit_sec::Union{Nothing, Float64} = nothing
    raw_optimizer_attributes::Dict{String, Any} = Dict{String, Any}()
    number_of_threads::Int = 1

    objective_value::T = zero(T)
    solve_time_sec::Float64 = NaN
    termination_status::MOI.TerminationStatusCode = MOI.OPTIMIZE_NOT_CALLED
    primal_status::MOI.ResultStatusCode = MOI.NO_SOLUTION
    raw_status_string::String = ""

    variable_primal_start::Dict{MOI.VariableIndex, T} = Dict{MOI.VariableIndex, T}()

    objective_sense::MOI.OptimizationSense = MOI.MIN_SENSE
end

struct NumberOfReads <: MOI.AbstractOptimizerAttribute end

macro anew_sampler(expr)
    expr = macroexpand(__module__, expr)

    if !(expr isa Expr && expr.head === :block)
        error("Invalid usage of @anew")
    end

    return esc(:(
            Base.@kwdef mutable struct SamplerSettings{T} <: Anneal.AbstractSamplerSettings{T}
                $(expr)
            end;

            mutable struct Optimizer{T} <: Anneal.AbstractSampler{T}

                x::Dict{MOI.VariableIndex, Union{Int, Missing}}
                Q::Dict{Tuple{Int, Int}, T}
                c::T
                n::Int

                settings::SamplerSettings{T}
                sample_set::Anneal.SampleSet{Int, T}
                moi::Anneal.SamplerMOI{T}

                function Optimizer{T}(; kws...) where {T}
                    optimizer = new{T}(
                        Dict{MOI.VariableIndex, Int}(),
                        Dict{Tuple{Int, Int}, T}(),
                        zero(T),
                        0,

                        SamplerSettings{T}(; kws...),
                        Anneal.SampleSet{Int, T}(),
                        Anneal.SamplerMOI{T}(),
                    )

                    Anneal.init!(optimizer)

                    return optimizer
                end

                function Optimizer(; kws...)
                    return Optimizer{Float64}(; kws...)
                end
            end;
            )
        )
end