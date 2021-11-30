module ToQUBO
    using JuMP, MathOptInterface
    const MOI = MathOptInterface
    const MOIU = MathOptInterface.Utilities
    const MOIB = MathOptInterface.Bridges

    const SVF = MOI.SingleVariable
    const VVF = MOI.VectorOfVariables
    const SAF{T} = MOI.ScalarAffineFunction{T}
    const VAF{T} = MOI.VectorAffineFunction{T}
    const SQF{T} = MOI.ScalarQuadraticFunction{T}
    const VQF{T} = MOI.VectorQuadraticFunction{T}

    const VI = MOI.VariableIndex
    const CI = MOI.ConstraintIndex

    

    include("moi.jl")

end # module