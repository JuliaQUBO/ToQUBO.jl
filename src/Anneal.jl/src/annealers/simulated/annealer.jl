# -*- :: Simulated Annealer :: -*-
struct NumberOfSweeps <: MOI.AbstractOptimizerAttribute end

Anneal.@anew_annealer begin
    num_reads::Int = 1_000
    num_sweeps::Int = 1_000
end

# -*- :: Python D-Wave Simulated Annealing :: -*-
const neal = PyNULL()

function __init__()
    copy!(neal, python_import("neal", "dwave-neal"))
end

function Anneal.anneal(annealer::Optimizer{T}) where {T}
    sampler = neal.SimulatedAnnealingSampler()

    t₀ = time()
    samples = [(convert.(Int, s), convert(Int, n), convert(Float64, e + annealer.c)) for (s, e, n) ∈ sampler.sample_qubo(
        annealer.Q;
        num_reads=annealer.settings.num_reads,
        num_sweeps=annealer.settings.num_sweeps
    ).record]
    t₁ = time()

    δt = t₁ - t₀

    return (samples, δt)
end