module ToQUBO

using MathOptInterface
const MOI = MathOptInterface

import PseudoBooleanOptimization as PBO
import QUBOTools

# Versioning
import TOML

const __PROJECT__ = Ref{Union{String,Nothing}}(nothing)

function __project__()
    if isnothing(__PROJECT__[])
        proj_path = abspath(dirname(@__DIR__))
    
        @assert isdir(proj_path)
    
        __PROJECT__[] = proj_path
    end

    return __PROJECT__[]::String
end

const __VERSION__ = Ref{Union{VersionNumber,Nothing}}(nothing)

function __version__()::VersionNumber
    if isnothing(__VERSION__[])
        proj_file_path = abspath(__project__(), "Project.toml")

        @assert isfile(proj_file_path)

        proj_file_data = TOML.parsefile(proj_file_path)

        __VERSION__[] = VersionNumber(proj_file_data["version"])
    end

    return __VERSION__[]::VersionNumber
end

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
