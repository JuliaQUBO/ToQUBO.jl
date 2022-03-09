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

# -*- QUBO Errors -*-
include("error.jl")

# -*- PBO Library -*-
include("pbo.jl")
using .PBO

# -*- PBO Aliases -*-
const ℱ{T} = PBF{VI, T}

# -*- Virtual Mapping -*-
include("virtual.jl")
using .VirtualMapping

# -*- QUBO Model -*-
include("model.jl")

# -*- ToQUBO Aliases -*-
const Optimizer{T} = VirtualQUBOModel{T}

# -*- -> QUBO <- -*-
include("qubo.jl")

# -*- MOI Wrapper -*-
include("MOI_wrapper.jl")

end # module