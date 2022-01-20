using PyCall
using Conda

# -*- Python Simulated Annealing -*-
const neal = PyNULL()

function __init__()
    try
        copy!(neal, pyimport("neal"))
    catch
        @warn """
        D-Wave Neal is not installed.
        Running `pip install --user dwave-neal`
        """
        sys = pyimport("sys")
        cmd = Cmd([sys.executable, "-m", "pip", "install", "--user", "dwave-neal"])
        
        ans = run(cmd)

        if ans.exitcode != 0
            throw(SystemError("Unable to install D-Wave Neal via pip", ans.exitcode))
        end

        copy!(neal, pyimport("neal"))
    end
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