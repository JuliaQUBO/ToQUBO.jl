module ToQUBO

# ::: Imports :::
using Documenter
using JSON

# -*- MOI Stuff -*-
using MathOptInterface

const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex
const ZO = MOI.ZeroOne

# -*- :: Exports :: -*-
export QUBOModel, toqubo, isqubo
export PBO
export SimulatedAnnealer, QuantumAnnealer
export VirtualVariable, VV, coefficient, coefficients, offset, isslack, source, target, name

# -*- :: Library Imports :: -*-

# -*- Library: Samplers -*-
include("./lib/anneal/anneal.jl")
using .Anneal

include("./lib/varmap.jl")
using .VarMap

include("./lib/pbo.jl")

# -*- Model: QUBO -*-
include("./model/model.jl")
using .QUBO: toqubo

# -*- Library: IO, Printing & Plots? -*-
# include("./lib/io.jl")

end # module