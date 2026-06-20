module ToQUBOJuMPExt

import JuMP
import QUBOTools
import ToQUBO

# Intentional extension glue: ToQUBO owns the compiler result, while
# QUBOTools owns the backend/export surface used to inspect it.
function QUBOTools.backend(model::JuMP.Model; kwargs...)
    return QUBOTools.backend(JuMP.unsafe_backend(model); kwargs...)
end

function ToQUBO.violations(model::JuMP.Model; kwargs...)
    return ToQUBO.violations(JuMP.unsafe_backend(model); kwargs...)
end

function ToQUBO.is_feasible(model::JuMP.Model; kwargs...)
    return ToQUBO.is_feasible(JuMP.unsafe_backend(model); kwargs...)
end

function ToQUBO.feasibility_report(model::JuMP.Model; kwargs...)
    return ToQUBO.feasibility_report(JuMP.unsafe_backend(model); kwargs...)
end

end
