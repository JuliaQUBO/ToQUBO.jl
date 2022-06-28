module ToQUBO

# -*- :: External Imports :: -*-
using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

# -*- MOI Aliases -*-
const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- :: Library Imports :: -*-

# -*- Error -*-
include("error.jl")

# -*- Library -*-
include(joinpath("pbo", "PBO.jl"))
include(joinpath("virtual", "VirtualMapping.jl"))
include(joinpath("model", "model.jl"))
include(joinpath("analysis", "analysis.jl"))

end # module