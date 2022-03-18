# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverName)
    return "D-Wave Neal - Simulated Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    return "v0.5.8"
end

# -*- RawSolver (get) -*-
function MOI.get(::Optimizer, ::MOI.RawSolver)
    return "D-Wave Neal"
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
function MOI.get(annealer::Optimizer, ::NumberOfSweeps)
    return annealer.settings.num_sweeps
end

function MOI.set(annealer::Optimizer, ::NumberOfSweeps, num_sweeps::Int)
    annealer.settings.num_sweeps = num_sweeps

    nothing
end
