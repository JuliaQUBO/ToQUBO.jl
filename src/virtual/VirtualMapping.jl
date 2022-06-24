module VirtualMapping

# :: Pseudo-Boolean Optimization ::
import ..PBO

# -*- :: MathOptInterface :: -*-
import MathOptInterface
const MOI = MathOptInterface
const VI = MOI.VariableIndex

include("variable.jl")
include("model.jl")
include("encoding.jl")
include("wrapper.jl")
include("print.jl")

end