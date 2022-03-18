raw"""
Necessary methods for an AbstractOptimizer according to [1]

## References
 * [1] https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/
"""

# -*- :: -*- Optimizer Interface -*- :: -*-
function MOI.empty!(sampler::AbstractSampler{T}) where {T}
    # Variable Mapping
    empty!(sampler.x)

    # QUBO Problem
    empty!(sampler.Q)

    # Constant Term
    sampler.c = zero(T)

    sampler.n = 0

    # MathOptInterface Parameters
    empty!(sampler.moi)

    # Previous Samples
    empty!(sampler.sample_set)

    nothing
end

function MOI.is_empty(sampler::AbstractSampler{T}) where {T}
    return isempty(sampler.x) && isempty(sampler.Q) && (sampler.c == zero(T))
end

function MOI.optimize!(sampler::AbstractSampler, model::MOI.ModelLike)
    if !MOI.is_empty(sampler)
        error("MOI Error: Sampler is not empty")
    end

    MOI.copy_to(sampler, model)

    sample!(sampler)

    # TODO: Open Issue about termination/primal status
    sampler.moi.termination_status = MOI.LOCALLY_SOLVED

    return (MOIU.identity_index_map(model), false)
end

function Base.show(io::IO, ::AbstractSampler)
    Base.print(io, "An sampler for QUBO Models")
end

# -*- :: -*- Constraint Support -*- :: -*-
MOI.supports_constraint(::AbstractSampler, ::Type{<:MOI.AbstractFunction}, ::Type{<:MOI.AbstractSet}) = false
MOI.supports_constraint(::AbstractSampler, ::Type{<:MOI.VariableIndex}, ::Type{<:MOI.ZeroOne}) = true
MOI.supports_add_constrained_variable(::AbstractSampler, ::Type{<:MOI.ZeroOne}) = true
MOI.supports_add_constrained_variables(::AbstractSampler, ::Type{<:MOI.ZeroOne}) = true

# -*- :: -*-  Attributes -*- :: -*-
function MOI.get(::AbstractSampler, ::MOI.SolverName)
    return "Sampler"
end

function MOI.get(::AbstractSampler, ::MOI.SolverVersion)
    return "v0.0.0"
end

function MOI.get(::AbstractSampler, ::MOI.RawSolver)
    return "Generic Sampler"
end

# -*- Name (get, set, supports) -*-
function MOI.get(sampler::AbstractSampler, ::MOI.Name)
    return sampler.moi.name
end

function MOI.set(sampler::AbstractSampler, ::MOI.Name, name::String)
    sampler.moi.name = name
end

MOI.supports(::AbstractSampler, ::MOI.Name) = true

# -*- Silent (get, set, supports) -*-
function MOI.get(sampler::AbstractSampler, ::MOI.Silent)
    return sampler.moi.silent
end

function MOI.set(sampler::AbstractSampler, ::MOI.Silent, silent::Bool)
    sampler.moi.silent = silent
end

MOI.supports(::AbstractSampler, ::MOI.Silent) = true

# -*- TimeLimitSec (get, set, supports) -*-
function MOI.get(sampler::AbstractSampler, ::MOI.TimeLimitSec)
    return sampler.moi.time_limit_sec
end

function MOI.set(sampler::AbstractSampler, ::MOI.TimeLimitSec, time_limit_sec::Union{Nothing, Float64})
    sampler.moi.time_limit_sec = time_limit_sec
end

MOI.supports(::AbstractSampler, ::MOI.TimeLimitSec) = true

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(sampler::AbstractSampler, attr::MOI.RawOptimizerAttribute)
    return sampler.moi.raw_optimizer_attributes[attr.name]
end

function MOI.set(sampler::AbstractSampler, attr::MOI.RawOptimizerAttribute, value::Any)
    sampler.moi.raw_optimizer_attributes[attr.name] = value
end

MOI.supports(::AbstractSampler, ::MOI.RawOptimizerAttribute) = true

# -*- NumberOfThreads (get, set, supports) -*-
function MOI.get(sampler::AbstractSampler, ::MOI.NumberOfThreads)
    return sampler.moi.number_of_threads
end

function MOI.set(sampler::AbstractSampler, ::MOI.NumberOfThreads, n::Int)
    sampler.moi.number_of_threads = n
end

MOI.supports(::AbstractSampler, ::MOI.NumberOfThreads) = true

# -*- :: -*- The copy_to Interface -*- :: -*-
function MOI.copy_to(sampler::AbstractSampler{T}, model::MOI.ModelLike) where {T}
    sampler.x, sampler.Q, sampler.c = qubo_normal_form(T, model)
    sampler.n = length(sampler.x)

    sampler.moi.objective_sense = MOI.get(model, MOI.ObjectiveSense())

    nothing
end

function MOI.get(sampler::AbstractSampler, ps::MOI.PrimalStatus)
    i = ps.result_index
    n = MOI.get(sampler, MOI.ResultCount())
    return (1 <= i <= n) ? MOI.FEASIBLE_POINT : MOI.NO_SOLUTION
end

function MOI.get(sampler::AbstractSampler, ps::MOI.DualStatus)
    i = ps.result_index
    n = MOI.get(sampler, MOI.ResultCount())
    return (1 <= i <= n) ? MOI.UNKNOWN_RESULT_STATUS : MOI.NO_SOLUTION
end

function MOI.get(sampler::AbstractSampler, ::MOI.RawStatusString)
    return sampler.moi.raw_status_string
end

# -*- ResultCount -*-
function MOI.get(sampler::AbstractSampler, ::MOI.ResultCount) 
    return length(sampler.sample_set)
end

# -*- TerminationStatus -*-
function MOI.get(sampler::AbstractSampler, ::MOI.TerminationStatus)
    return sampler.moi.termination_status
end

function MOI.get(sampler::AbstractSampler, ::MOI.ObjectiveSense)
    return sampler.moi.objective_sense
end

# -*- ObjectiveValue -*-
function MOI.get(sampler::AbstractSampler{T}, ov::MOI.ObjectiveValue) where {T}
    n = MOI.get(sampler, MOI.ResultCount())

    j = ov.result_index

    if !(1 <= j <= n)
        throw(BoundsError("Result Index is out of bounds: $j ∉ [1, $n]"))
    end

    e = sampler.sample_set[j].energy

    if sampler.moi.objective_sense === MOI.MIN_SENSE
        return e
    else # MOI.MAX_SENSE    
        return -e
    end
end

# -*- SolveTimeSec -*-
function MOI.get(sampler::AbstractSampler, ::MOI.SolveTimeSec)
    return sampler.moi.solve_time_sec
end

# -*- VariablePrimal -*-
function MOI.get(sampler::AbstractSampler{T}, vp::MOI.VariablePrimal, vi::MOI.VariableIndex) where {T}
    n = length(sampler.x)

    j = vp.result_index

    if !(1 <= j <= n)
        throw(MOI.ResultIndexBoundsError{MOI.VariablePrimal}(vp, n))
    end

    if !haskey(sampler.x, vi)
        throw(MOI.InvalidIndex{MOI.VariableIndex}(vi))
    end

    i = sampler.x[vi]

    if i === nothing
        return zero(T)
    else
        return convert(T, sampler.sample_set[j].states[i])
    end
end

# -*- ObjectiveFunction -*-
MOI.supports(::AbstractSampler{T}, ::MOI.ObjectiveFunction{SQF{T}}) where T = true

# -*- :: Settings :: -*-
function MOI.get(sampler::AbstractSampler, ::NumberOfReads)
    return sampler.settings.num_reads
end

function MOI.set(sampler::AbstractSampler, ::NumberOfReads, num_reads::Int)
    sampler.settings.num_reads = num_reads

    nothing
end

function MOI.get(sampler::AbstractSampler, ::MOI.VariablePrimalStart, vi::MOI.VariableIndex)
    if !haskey(sampler.x, vi)
        throw(MOI.InvalidIndex{MOI.VariableIndex}(vi))
    elseif haskey(sampler.moi.variable_primal_start, vi)
        return sampler.moi.variable_primal_start[vi]
    else
        return nothing
    end
end

function MOI.set(sampler::AbstractSampler{T}, ::MOI.VariablePrimalStart, vi::MOI.VariableIndex, s::Union{Nothing, T}) where {T}
    if !haskey(sampler.x, vi)
        throw(MOI.InvalidIndex{MOI.VariableIndex}(vi))
    elseif s === nothing
        delete!(sampler.moi.variable_primal_start, vi)
    else
        sampler.moi.variable_primal_start[vi] = s
    end

    nothing
end

MOI.supports(::AbstractSampler, ::MOI.VariablePrimalStart, ::Type{<:MOI.VariableIndex}) = true