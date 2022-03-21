# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "Exact Sampler"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return v"1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(sampler::Optimizer, ::MOI.RawSolver)
    return sampler
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
# function MOI.get(sampler::Optimizer, ::NumberOfReads)
#     return (2 ^ sampler.n)
# end