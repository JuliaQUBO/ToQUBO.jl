# -*- :: -*-  Attributes -*- :: -*-
function MOI.get(::DigitalAnnealer, ::MOI.SolverName)
    return "Digital Annealer"
end

function MOI.get(::DigitalAnnealer, ::MOI.SolverVersion)
    return "v0.0.0" # Unknown
end

function MOI.get(::DigitalAnnealer, ::MOI.RawSolver)
    return "Fujitsu"
end