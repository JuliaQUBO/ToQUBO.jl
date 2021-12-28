# -*- SolverName (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.SolverName)
    
end

# -*- SolverVersion (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.SolverVersion)
    
end

# -*- RawSolver (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawSolver)
    
end

# -*- Name (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Name)::String
    
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Name, name::String)
    
end

function MOI.supports(::AbstractAnnealer, ::MOI.Name)::Bool
    return true
end

# -*- Silent (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Silent)::Bool
    
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Silent, v::Bool)
    
end

function MOI.supports(::AbstractAnnealer, ::MOI.Silent)::Bool
    return true
end

# -*- TimeLimitSec (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.TimeLimitSec)::Float64
    
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.TimeLimitSec, s::Float64)
    
end

function MOI.supports(::AbstractAnnealer, ::MOI.TimeLimitSec)::Bool
    return true
end

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute)::Any
    
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute, attr::Any)
    
end

function MOI.supports(::AbstractAnnealer, ::MOI.RawOptimizerAttribute)::Bool
    return true
end

# -*- NumberOfThreads (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.NumberOfThreads)::Int
    
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.NumberOfThreads, n::Int)
    
end

function MOI.supports(::AbstractAnnealer, ::MOI.NumberOfThreads)::Bool
    return true
end