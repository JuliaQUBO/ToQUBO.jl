"""
Necessary methods for an AbstractOptimizer according to [1]

    [1] https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/
"""

# ::: Implement methods for Optimizer :::
function MOI.empty!(annealer::AbstractAnnealer{T}) where {T}
    empty!(annealer.Q)
    annealer.c = zero(T)

    nothing
end

function MOI.is_empty(annealer::AbstractAnnealer{T}) where {T}
    return isempty(annealer.Q) && annealer.c === zero(T)
end

function MOI.optimize!(annealer::AbstractAnnealer)
    if MOI.is_empty(annealer)
        throw(ErrorException("Empty Annealer"))
    end

    anneal!(annealer)
end

# ::: Implement attributes :::
# -*- SolverName (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.SolverName)
    return "Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.SolverVersion)
    return "1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.RawSolver)
    return ""
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

function MOI.set(annealer::AbstractAnnealer, ::MOI.TimeLimitSec, Δt::Float64)
    annealer.moi.time_limit_sec = Δt
end

MOI.supports(::AbstractAnnealer, ::MOI.TimeLimitSec) = true

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute)
    return annealer.moi.raw_optimizer_attribute
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute, attr::Any)
    annealer.moi.raw_optimizer_attribute = attr
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

# -*- Define supports_constraint -*-

# -*- Define supports_constraint -*-
MOI.supports_constraint(::AbstractAnnealer, ::Any, ::Any) = false
MOI.supports_constraint(::AbstractAnnealer, ::Type{<: MOI.VariableIndex}, ::Type{<: MOI.ZeroOne}) = true

# -*- Simulated Annealer -*-

# -*- SolverName (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.SolverName)
    return "Simulated Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.SolverVersion)
    return "1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.RawSolver)
    return "Python D-Wave Neal (0.5.8)"
end

function MOI.get(optimizer::SimulatedAnnealer{T}, ov::MOI.ObjectiveValue) where {T}
    n = length(optimizer.sample_set.samples)

    j = ov.result_index

    if !(1 <= j <= n)
        throw(BoundsError("Result Index is out of bounds: $j ∉ [1, $n]"))
    end

    sample = optimizer.sample_set.samples[j]

    return (sample.energy + optimizer.c)::T
end

function MOI.get(optimizer::SimulatedAnnealer{T}, vp::MOI.VariablePrimal, i::Int) where {T}
    n = length(optimizer.sample_set.samples)

    j = vp.result_index

    if !(1 <= j <= n)
        throw(BoundsError("Result Index is out of bounds: $j ∉ [1, $n]"))
    end

    sample = optimizer.sample_set.samples[j]

    m = length(sample.states)

    if !(1 <= i <= m)
        throw(BoundsError("Variable Index is out of bounds: $i ∉ [1, $m]"))
    end

    return (sample.states[i] > 0)
end