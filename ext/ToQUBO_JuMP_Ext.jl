module ToQUBO_JuMP_Ext

import ToQUBO
import JuMP

function ensure_supports_compilation(jm::JuMP.Model)
    if !ToQUBO.supports_compilation(jm)
        error("The current model does not support ToQUBO compilation.")
    end

    return nothing
end

function ToQUBO.supports_compilation(jm::JuMP.Model)
    return (unsafe_backend(jm) isa ToQUBO.Optimizer)
end

function ToQUBO.compile!(jm::JuMP.Model)
    @assert ToQUBO.supports_compilation(jm)

    ToQUBO.compile!(unsafe_backend(jm))

    return jm
end

end