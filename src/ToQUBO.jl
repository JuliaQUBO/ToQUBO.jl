module ToQUBO

using MathOptInterface
const MOI = MathOptInterface

import PseudoBooleanOptimization as PBO
import QUBOTools

# Versioning
using TOML
const __PROJECT__ = abspath(@__DIR__, "..")
const __VERSION__ = VersionNumber(getindex(TOML.parsefile(joinpath(__PROJECT__, "Project.toml")), "version"))

# MOI Aliases
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI      = MOI.VariableIndex
const CI{F,S} = MOI.ConstraintIndex{F,S}

# Encoding Module
include("encoding/encoding.jl")

# Models
include("model/qubo.jl")
include("model/prequbo.jl")

# Virtual mapping module
include("virtual/virtual.jl")

# MOI wrapper
include("wrapper.jl")

# Attributes
include("attributes/model.jl")
include("attributes/solver.jl")
include("attributes/compiler.jl")

# Compiler
include("compiler/compiler.jl")

end # module
