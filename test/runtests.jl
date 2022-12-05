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

# -*- Tests: Version -*- #
include("lib/version.jl")

# -*- Tests: Library -*- #
include("lib/pbo.jl")
include("lib/pbo_ma.jl")
include("lib/virtual.jl")

# -*- Tests: Interface -*- #
include("interface/interface.jl")

# -*- Tests: Examples -*- #
include("examples/examples.jl")

function main()
    @testset ":: -*- :: ~*~ ToQUBO.jl ~*~ :: -*- ::" verbose = true begin
        test_version()
        test_pbo()
        test_pbo_ma()
        test_virtual()
        test_interface()
        test_examples()
    end
end

main() # Here we go!