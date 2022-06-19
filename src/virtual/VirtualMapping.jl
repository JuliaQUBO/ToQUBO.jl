module VirtualMapping

# :: Pseudo-Boolean Optimization ::
import ..PBO

# -*- :: MathOptInterface :: -*-
using MathOptInterface
const MOI = MathOptInterface
const VI = MOI.VariableIndex

include("variable.jl")
include("model.jl")
include("encoding.jl")

end