using PyCall
using Conda

# -*- Python Simulated Annealing -*-
const neal = PyNULL()

function __init__()
    try
        pyimport("neal")
    catch 𝕖
        @warn """
        D-Wave Neal is not installed.
        Running `pip install dwave-neal`
        """
        Conda.pip_interop(true)
        Conda.pip("install", "dwave-neal")
    end

    copy!(neal, pyimport("neal"))
end

function py_simulated_annealing(Q::Dict{Tuple{Int, Int}, T}, c::T; params...) where {T}
    sampler = neal.SimulatedAnnealingSampler()

    t₀ = time()
    results = sampler.sample_qubo(Q; params...)
    t₁ = time()

    δt = t₁ - t₀
    samples = [([convert(Int, sᵢ) for sᵢ ∈ s], convert(Int, n), convert(Float64, e)) for (s, e, n) in results.record]

    return (samples, δt)
end

function py_quantum_annealing(Q::Dict{Tuple{Int, Int}, T}, c::T; params...) where {T}
    throw(ErrorException("Quantum Host is Unavailable."))
end