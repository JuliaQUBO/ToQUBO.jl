# -*- Annealers -*-
abstract type AbstractAnnealer{T <: Any} <: AbstractSampler{T} end
abstract type AbstractAnnealerSettings{T} <: AbstractSamplerSettings{T} end

const AnnealingResults = Vector{Tuple{Vector{Int}, Int, Float64}}

sample(annealer::AbstractAnnealer) = anneal(annealer)

function anneal(::AbstractAnnealer)
    error("`anneal(::AbstractAnnealer)` was not implemented")
end

const AnnealerMOI{T} = SamplerMOI{T}

macro anew_annealer(expr)
    expr = macroexpand(__module__, expr)

    if !(expr isa Expr && expr.head === :block)
        error("Invalid usage of @anew")
    end

    return esc(:(
            Base.@kwdef mutable struct AnnealerSettings{T} <: Anneal.AbstractAnnealerSettings{T}
                $(expr)
            end;

            mutable struct Optimizer{T} <: Anneal.AbstractAnnealer{T}

                x::Dict{MOI.VariableIndex, Union{Int, Missing}}
                Q::Dict{Tuple{Int, Int}, T}
                c::T
                n::Int

                settings::AnnealerSettings{T}
                sample_set::Anneal.SampleSet{Int, T}
                moi::Anneal.AnnealerMOI{T}

                function Optimizer{T}(; kws...) where {T}
                    optimizer = new{T}(
                        Dict{MOI.VariableIndex, Int}(),
                        Dict{Tuple{Int, Int}, T}(),
                        zero(T),
                        0,

                        AnnealerSettings{T}(; kws...),
                        Anneal.SampleSet{Int, T}(),
                        Anneal.AnnealerMOI{T}(),
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