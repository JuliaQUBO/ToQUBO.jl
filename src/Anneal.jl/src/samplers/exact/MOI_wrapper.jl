# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "Exact Sampler"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return "v0.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::Optimizer, ::MOI.RawSolver)
    return "Exact Sampler"
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
function MOI.get(sampler::Optimizer, ::NumberOfReads)
    return (2 ^ sampler.n)
end

function MOI.set(::Optimizer, ::NumberOfReads, ::Int) end