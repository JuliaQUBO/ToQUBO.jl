module ToQUBO

# ::: Imports :::
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

const ∅ = Set{VI}()

# -*- :: Exports :: -*-
export VirtualQUBOModel, PreQUBOModel, QUBOModel, toqubo, isqubo
export PseudoBooleanFunction, PBF, qubo, ising, Δ, δ, reduce_degree
export SimulatedAnnealer, QuantumAnnealer
export VirtualVariable, VV, coefficient, coefficients, offset, isslack, source, target, name
export mapvar!, expandℝ!, expandℤ!, mirror𝔹!, slackℝ!, slackℤ!, slack𝔹!

# -*- :: Library Imports :: -*-

# -*- Library: Samplers -*-
include("./lib/anneal/anneal.jl")
using .Anneal

include("./lib/virtual.jl")
using .VirtualMapping

include("./lib/pbo.jl")
using .PBO

# -*- Model: QUBO -*-
include("./model/model.jl")

# -*- MOI: Bind QUBOModel and Annealing -*-
include("./moi.jl")

# -*- Library: IO, Printing & Plots? -*-
include("./lib/io.jl")

end # module