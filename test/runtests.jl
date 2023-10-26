using Test

using JuMP
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex
using QUBODrivers
using LinearAlgebra
using TOML

using ToQUBO
using ToQUBO: QUBOTools, PBO, Attributes

function QUBOTools.backend(model::JuMP.Model)
    return QUBOTools.backend(JuMP.unsafe_backend(model))
end

include("unit/unit.jl")
include("integration/integration.jl")

function main()
    @testset "♡ ToQUBO.jl $(ToQUBO.__VERSION__) Test Suite ♡" verbose = true begin
        test_unit()
        test_integration()
    end

    return nothing
end

main() # Here we go!
