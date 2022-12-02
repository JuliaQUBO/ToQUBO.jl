module ToQUBO

# -*- :: Base Imports & Constants :: -*- #
using TOML
using Base: @kwdef
const PROJECT_FILE_PATH = joinpath(@__DIR__, "..", "Project.toml")
const PROJECT_VERSION   = VersionNumber(getindex(TOML.parsefile(PROJECT_FILE_PATH), "version"))

# -*- :: External Imports :: -*- #
using MathOptInterface
const MOI  = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

# -*- MOI Aliases -*- #
const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- :: QUBOTools :: -*- #
import QUBOTools: QUBOTools, qubo, backend

# -*- :: Library Icludes :: -*- #

# -*- Library -*- #
include("lib/error.jl")
include("lib/pbo/PBO.jl")

# -*- Model -*- #
include("model/qubo.jl")
include("model/prequbo.jl")
include("model/virtual.jl")
include("model/wrapper.jl")
include("model/attributes.jl")

# ~*~ Compiler & Analysis ~*~ #
include("compiler/compiler.jl")

end # module