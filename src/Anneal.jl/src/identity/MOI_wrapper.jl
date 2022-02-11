# -*- :: -*- Attributes -*- :: -*-

# -*- SolverName (get) -*-
function MOI.get(::TemplateAnnealer, ::MOI.SolverName)
    return "Template Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::TemplateAnnealer, ::MOI.SolverVersion)
    return "v0.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::TemplateAnnealer, ::MOI.RawSolver)
    return "Template"
end

# -*- :: -*- Solver-specific attributes -*- :: -*-
function MOI.get(annealer::TemplateAnnealer, ::SomeAttribute)
    return annealer.settings.num_sweeps
end

function MOI.set(annealer::TemplateAnnealer, ::SomeAttribute, some_attribute::Any)
    annealer.settings.some_attribute = some_attribute

    nothing
end
