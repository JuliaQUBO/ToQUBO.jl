# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.SolverName)
    return "Simulated Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.SolverVersion)
    return "v0.5.8"
end

# -*- RawSolver (get) -*-
function MOI.get(::SimulatedAnnealer, ::MOI.RawSolver)
    return "D-Wave Neal"
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
function MOI.get(annealer::SimulatedAnnealer, ::NumberOfSweeps)
    return annealer.settings.num_sweeps
end

function MOI.set(annealer::SimulatedAnnealer, ::NumberOfSweeps, num_sweeps::Int)
    annealer.settings.num_sweeps = num_sweeps

    nothing
end
