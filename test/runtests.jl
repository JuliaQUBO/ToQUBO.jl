using Test

# -*- Imports: JuMP + MOI -*-
using JuMP
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- Imports: JuMP + MOI -*-
import MutableArithmetics
const MA = MutableArithmetics

# -*- Imports -*-
using ToQUBO: ToQUBO, PBO
using Anneal
using LinearAlgebra
using TOML

# -*- Test Assets -*- #
include("assets/assets.jl")

# -*- Unit Tests -*- #
include("unit/unit.jl")

# -*- Integration Tests -*- #
include("integration/integration.jl")

# -*- Examples -*- #
include("examples/examples.jl")

function main()
    @testset ":: -*- :: ~*~ :: ToQUBO.jl :: ~*~ :: -*- ::" verbose = true begin
        test_unit()
        test_integration()
        test_examples()
    end

    return nothing
end

main() # Here we go!