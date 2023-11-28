module Virtual

# Imports
import MathOptInterface as MOI
import PseudoBooleanOptimization as PBO 

import ..ToQUBO: QUBOModel, PreQUBOModel
import ..Encoding: Encoding, VariableEncodingMethod, encode!

# Constants
const MOIU    = MOI.Utilities
const MOIB    = MOI.Bridges
const VI      = MOI.VariableIndex
const CI{F,S} = MOI.ConstraintIndex{F,S}

include("interface.jl")

include("variable.jl")
include("model.jl")
include("encoding.jl")

end # module Virtual
