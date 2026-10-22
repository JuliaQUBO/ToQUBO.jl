using Test

using JuMP
const MOIU    = MOI.Utilities
const VI      = MOI.VariableIndex
const CI{F,S} = MOI.ConstraintIndex{F,S}
using QUBODrivers
using LinearAlgebra
using Logging
using TOML

using ToQUBO
using ToQUBO: Attributes, Encoding

import QUBOTools
import PseudoBooleanOptimization as PBO

# Move this to QUBOTools / PBO
function MOIU.map_indices(::Function, arch::QUBOTools.AbstractArchitecture)
    return arch
end

function MOIU.map_indices(::Function, quad::PBO.QuadratizationMethod)
    return quad
end

function _exact_sampler_termination_status()
    return pkgversion(QUBODrivers) >= v"0.6.6" ? MOI.OPTIMAL : MOI.LOCALLY_SOLVED
end

include("unit/unit.jl")
include("integration/integration.jl")

function main()
    @testset "♡ ToQUBO.jl $(ToQUBO.__version__()) Test Suite ♡" verbose = true begin
        test_unit()
        test_integration()
    end

    return nothing
end

main() # Here we go!
