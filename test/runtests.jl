using Test

using JuMP
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex
using QUBODrivers
using LinearAlgebra
using TOML

using ToQUBO
using ToQUBO: PBO, Attributes

include("assets/assets.jl")
include("unit/unit.jl")
include("integration/integration.jl")
include("examples/examples.jl")

function main()
    @testset "::  ::  :: ToQUBO.jl ::  ::  ::" verbose = true begin
        test_unit()
        test_integration()
        test_examples()
    end

    return nothing
end

main() # Here we go!
