raw"""
Necessary methods for an AbstractOptimizer according to [1]

## References
 * [1] https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/
"""

# -*- :: -*- Optimizer Interface -*- :: -*-
function MOI.empty!(annealer::AbstractAnnealer{S, T}) where {S, T}
    # Variable Mapping
    empty!(annealer.x)

    # QUBO Problem
    empty!(annealer.Q)

    # Constant Term
    annealer.c = zero(T)

    nothing
end

function MOI.is_empty(annealer::AbstractAnnealer{S, T}) where {S, T}
    return isempty(annealer.x) && isempty(annealer.Q) && (annealer.c == zero(T))
end

function MOI.optimize!(annealer::AbstractAnnealer)
    anneal!(annealer)

    nothing
end

function Base.show(io::IO, ::AbstractAnnealer)
    Base.print(io, "An Annealer for QUBO Models")
end

# -*- :: -*- Constraint Support -*- :: -*-
MOI.supports_constraint(::AbstractAnnealer, ::Any, ::Any) = false
MOI.supports_constraint(::AbstractAnnealer, ::Type{<: MOI.VariableIndex}, ::Type{<: MOI.ZeroOne}) = true

# -*- :: -*-  Attributes -*- :: -*-
function MOI.get(::AbstractAnnealer, ::MOI.SolverName)
    return "Annealer"
end

function MOI.get(::AbstractAnnealer, ::MOI.SolverVersion)
    return "v0.0.0"
end

function MOI.get(::AbstractAnnealer, ::MOI.RawSolver)
    return "Generic Annealer"
end

# -*- Name (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Name)
    return annealer.moi.name
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Name, name::String)
    annealer.moi.name = name
end

MOI.supports(::AbstractAnnealer, ::MOI.Name) = true

# -*- Silent (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Silent)
    return annealer.moi.silent
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Silent, silent::Bool)
    annealer.moi.silent = silent
end

MOI.supports(::AbstractAnnealer, ::MOI.Silent) = true

# -*- TimeLimitSec (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.TimeLimitSec)
    return annealer.moi.time_limit_sec
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.TimeLimitSec, time_limit_sec::Union{Nothing, Float64})
    annealer.moi.time_limit_sec = time_limit_sec
end

MOI.supports(::AbstractAnnealer, ::MOI.TimeLimitSec) = true

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, attr::MOI.RawOptimizerAttribute)
    return annealer.moi.raw_optimizer_attributes[attr.name]
end

function MOI.set(annealer::AbstractAnnealer, attr::MOI.RawOptimizerAttribute, value::Any)
    annealer.moi.raw_optimizer_attributes[attr.name] = value
end

MOI.supports(::AbstractAnnealer, ::MOI.RawOptimizerAttribute) = true

# -*- NumberOfThreads (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.NumberOfThreads)
    return annealer.moi.number_of_threads
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.NumberOfThreads, n::Int)
    annealer.moi.number_of_threads = n
end

MOI.supports(::AbstractAnnealer, ::MOI.NumberOfThreads) = true

# -*- :: -*- The copy_to Interface -*- :: -*-
function MOI.copy_to(annealer::AbstractAnnealer{S, T}, model::MOI.ModelLike) where {S, T}
    (annealer.x, annealer.Q, annealer.c) = toqubo(T, model; sense=MOI.MIN_SENSE)

    nothing
end

# -*- :: -*- Names -*- :: -*-
function MOI.get(annealer::AbstractAnnealer, ps::MOI.PrimalStatus)
    i = ps.result_index
    n = MOI.get(annealer, MOI.ResultCount())

    if 1 <= i <= n
        return nothing
    else
        return MOI.NO_SOLUTION
    end
end

# -*- RawStatusString -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawStatusString)
    return annealer.moi.raw_status_string
end

# -*- ResultCount -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.ResultCount) 
    return length(annealer.sample_set)
end

# -*- TerminationStatus -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.TerminationStatus)
    return annealer.moi.termination_status
end

# -*- ObjectiveValue -*-
function MOI.get(annealer::AbstractAnnealer{S, T}, ov::MOI.ObjectiveValue) where {S, T}
    n = length(annealer.sample_set)

    j = ov.result_index

    if !(1 <= j <= n)
        throw(BoundsError("Result Index is out of bounds: $j ∉ [1, $n]"))
    end

    sample = annealer.sample_set[j]

    return (sample.energy + annealer.c)::T
end

# -*- SolveTimeSec -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.SolveTimeSec)
    return annealer.moi.solve_time_sec
end

# -*- VariablePrimal -*-
function MOI.get(annealer::AbstractAnnealer{S, T}, vp::MOI.VariablePrimal, s::S) where {S, T}
    n = length(annealer.sample_set.samples)

    j = vp.result_index

    if !(1 <= j <= n)
        throw(MOI.ResultIndexBoundsError("Result Index is out of bounds: $j ∉ [1, $n]"))
    end

    sample = annealer.sample_set[j]

    i = annealer.x[s]

    m = length(sample.states)

    if !(1 <= i <= m)
        throw(MOI.InvalidIndex("Variable Index is out of bounds: $i ∉ [1, $m]"))
    end

    return (sample.states[i] > 0)
end



# -*- :: Settings :: -*-
function MOI.get(annealer::AbstractAnnealer, ::NumberOfReads)
    return annealer.settings.num_reads
end

function MOI.set(annealer::AbstractAnnealer, ::NumberOfReads, num_reads::Int)
    annealer.settings.num_reads = num_reads

    nothing
end