# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "Identity Sampler"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return "v1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(model::Optimizer, ::MOI.RawSolver)
    return model
end