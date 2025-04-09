module ToQUBO_JuMP_Ext

import ToQUBO
import JuMP

function ToQUBO.supports_compilation(jm::JuMP.Model)
    return (unsafe_backend(jm) isa ToQUBO.Optimizer)
end

function ToQUBO.compile!(jm::JuMP.Model)
    @assert ToQUBO.supports_compilation(jm)

    ToQUBO.compile!(unsafe_backend(jm))

    return jm
end

end