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

include("unit/unit.jl")
include("integration/integration.jl")

function main()
    @testset "◈ ◈ ◈ ToQUBO.jl Test Suite ◈ ◈ ◈" verbose = true begin
        test_unit()
        # test_integration()
    end

    return nothing
end

main() # Here we go!
