module ToQUBO

# Base Imports & Constants 
import TOML
const PROJECT_FILE_PATH = joinpath(@__DIR__, "..", "Project.toml")
const PROJECT_VERSION   = VersionNumber(getindex(TOML.parsefile(PROJECT_FILE_PATH), "version"))

# QUBOTools
import QUBOTools
import QUBOTools: PBO

# External Imports
import MathOptInterface as MOI

const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

# MOI Aliases
const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# Library
include("error.jl")

# Model
include("model/qubo.jl")
include("model/prequbo.jl")
include("model/virtual.jl")
include("model/wrapper.jl")

# Attributes
include("attributes/model.jl")
include("attributes/solver.jl")
include("attributes/virtual.jl")
include("attributes/compiler.jl")

# Compiler & Analysis
include("compiler/compiler.jl")

end # module
