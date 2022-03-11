# -*- :: Simulated Annealer :: -*-
struct NumberOfSweeps <: MOI.AbstractOptimizerAttribute end

Anneal.@anew_annealer begin
    num_reads::Int = 1_000
    num_sweeps::Int = 1_000
end

# -*- :: Python D-Wave Simulated Annealing :: -*-
const neal = PythonCall.pynew() # initially NULL

function __init__()
    PythonCall.pycopy!(neal, pyimport("neal"))
end

function Anneal.anneal(annealer::Optimizer{T}) where {T}
    sampler = neal.SimulatedAnnealingSampler()

    t₀ = time()
    samples = [(pyconvert.(Int, s), pyconvert(Int, n), pyconvert(Float64, e + annealer.c)) for (s, e, n) ∈ sampler.sample_qubo(
        annealer.Q;
        num_reads=annealer.settings.num_reads,
        num_sweeps=annealer.settings.num_sweeps
    ).record]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end