using Test

# -*- Imports: JuMP + MOI -*-
using JuMP
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- Imports -*-
using ToQUBO: ToQUBO, PBO, VM
using Anneal
using LinearAlgebra
using TOML

# -*- Tests: Version -*-
include("lib/version.jl")

# -*- Tests: Library -*-
include("lib/pbo.jl")
include("lib/virtual.jl")

# -*- Tests: Interface -*-
include("interface/moi.jl")
include("interface/jump.jl")

# -*- Tests: Examples -*-
include("examples/qba/qba.jl")
include("examples/linear/linear.jl")

function main()
    @testset ":: -*- :: ToQUBO.jl :: -*- ::" verbose = true begin
        test_version()
        test_pbo()
        test_virtual()
        test_moi()
        test_jump()
        test_qba()
        test_linear()
    end
end

main() # Here we go!