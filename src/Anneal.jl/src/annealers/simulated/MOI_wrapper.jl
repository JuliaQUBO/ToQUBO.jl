# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "D-Wave Neal"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return v"0.5.8"
end

# -*- RawSolver (get) -*-
function MOI.get(optimizer::Optimizer, ::MOI.RawSolver)
    return optimizer
end