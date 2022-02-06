using PyCall
using Conda

include("pyimport.jl")

# -*- :: Python D-Wave Simulated Annealing :: -*-
@python_import neal "neal" "dwave-neal"

function py_simulated_annealing(Q::Dict{Tuple{Int, Int}, T}, c::T; params...) where {T}
    sampler = neal.SimulatedAnnealingSampler()

    t₀ = time()
    results = sampler.sample_qubo(Q; params...)
    t₁ = time()

    δt = t₁ - t₀
    samples = [([convert(Int, sᵢ) for sᵢ ∈ s], convert(Int, n), convert(Float64, e)) for (s, e, n) in results.record]

    return (samples, δt)
end

# -*- :: Python D-Wave Quantum Annealing API :: -*-
function py_quantum_annealing(Q::Dict{Tuple{Int, Int}, T}, c::T; params...) where {T}
    throw(AnnealingError("Quantum Annealing Host is Unavailable."))
end

# -*- :: Python Fujitsu Digital Annealing API :: -*-
function py_digital_annealing(Q::Dict{Tuple{Int, Int}, T}, c::T; params...) where {T}
    throw(AnnealingError("Digital Annealing Host is Unavailable."))
end