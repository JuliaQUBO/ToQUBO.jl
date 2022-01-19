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

# ::: Exports :::
export QUBOModel, toqubo, isqubo
export PBO
export SimulatedAnnealer, QuantumAnnealer

# ::: Library Imports :::

# -*- Library: Samplers
include("./lib/sample/anneal.jl")
using .Anneal

# -*- Library: QUBO Model -*-
include("./lib/qubo.jl")

# -*- MOI Stuff -*-
include("./lib/moi.jl")

# -*- IO, Printing & Plots -*-
include("./lib/io.jl")

end # module