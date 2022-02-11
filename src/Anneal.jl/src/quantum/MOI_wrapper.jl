# -*- :: -*-  Attributes -*- :: -*-
function MOI.get(::QuantumAnnealer, ::MOI.SolverName)
    return "Quantum Annealer"
end

function MOI.get(::QuantumAnnealer, ::MOI.SolverVersion)
    return "v0.0.0" # Unknown
end

function MOI.get(::QuantumAnnealer, ::MOI.RawSolver)
    return "D-Wave"
end