module VirtualMapping

# :: Pseudo-Boolean Optimization ::
import ..PBO

# -*- :: MathOptInterface :: -*-
using MathOptInterface
const MOI = MathOptInterface
const VI = MOI.VariableIndex

export AbstractVirtualModel, SourceModel, TargetModel
export VirtualVariable, Variables, Source, Target
export expansion, penaltyfn, source, target, isslack
export Mirror, Linear, Unary, Binary, OneHot, DomainWall
export encode!

include("variable.jl")
include("model.jl")
include("encoding.jl")
include("wrapper.jl")
include("print.jl")

end