module Quantum
    using Anneal
    using MathOptInterface
    const MOI = MathOptInterface

    include("annealer.jl")
    include("MOI_wrapper.jl")

    const Optimizer{T} = QuantumAnnealer{MOI.VariableIndex, T}
end # module