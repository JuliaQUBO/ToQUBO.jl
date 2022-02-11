module Simulated
    using Anneal
    using MathOptInterface
    const MOI = MathOptInterface

    include("annealer.jl")
    include("MOI_wrapper.jl")

    const Optimizer{T} = SimulatedAnnealer{MOI.VariableIndex, T}
end # module