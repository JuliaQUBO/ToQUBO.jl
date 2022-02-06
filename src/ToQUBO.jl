module ToQUBO

# ::: Imports :::
using JSON

# -*- MOI Stuff -*-
using MathOptInterface

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

const SAF{T} = MOI.ScalarAffineFunction{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const EQ{T} = MOI.EqualTo{T}
const LT{T} = MOI.LessThan{T}
const GT{T} = MOI.GreaterThan{T}

const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# -*- :: Exports :: -*-
export VirtualQUBOModel, PreQUBOModel, QUBOModel, toqubo, isqubo
export PseudoBooleanFunction, PBF, qubo, ising, Δ, Θ, quadratize, discretize, gap, @quadratization
export SimulatedAnnealer, QuantumAnnealer
export VirtualVariable, VV, coefficient, coefficients, offset, isslack, source, target, name
export mapvar!, expandℝ!, expandℤ!, mirror𝔹!, slackℝ!, slackℤ!, slack𝔹!

# -*- :: Library Imports :: -*-
include("./error.jl")

# -*- Proto-Package: Anneal.jl -*-
include("./Anneal.jl/src/Anneal.jl")
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