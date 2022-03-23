# -*- :: Simulated Annealer :: -*-
Anneal.@anew begin
    NumberOfReads::Int = 1_000
    NumberOfSweeps::Int = 1_000
end

# -*- :: Python D-Wave Simulated Annealing :: -*-
const neal = PythonCall.pynew() # initially NULL

function __init__()
    PythonCall.pycopy!(neal, pyimport("neal"))
end

function Anneal.sample(annealer::Optimizer{T}) where {T}
    sampler = neal.SimulatedAnnealingSampler()

    t₀ = time()
    samples = [(pyconvert.(Int, s), pyconvert(Int, n), pyconvert(Float64, e + annealer.c)) for (s, e, n) ∈ sampler.sample_qubo(
        annealer.Q;
        num_reads=annealer.settings.NumberOfReads,
        num_sweeps=annealer.settings.NumberOfSweeps,
    ).record]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end