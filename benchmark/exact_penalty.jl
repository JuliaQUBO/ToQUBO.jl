# Run with a pinned ToQUBO project and an externally bounded Julia process:
# julia --startup-file=no --project=. benchmark/exact_penalty.jl results.toml
import ToQUBO, PseudoBooleanOptimization as PBO, MathOptInterface as MOI, TOML

function legacy_exact(x)
    (!(x isa Real) || x isa Bool || !isfinite(x)) && return nothing
    try
        return Rational{BigInt}(x)
    catch
        return nothing
    end
end

function legacy_compare(p, q_exact)
    q = PBO.PBF{MOI.VariableIndex,Rational{BigInt}}()
    for (term, c) in p
        cq = legacy_exact(c)
        isnothing(cq) && return false
        iszero(cq) || (q[term] = cq)
    end
    return q == q_exact
end

function conversion_batch(exact, coefficients)
    result = nothing
    for c in coefficients
        result = exact(c)
    end
    return result
end

function main(output)
    isempty(output) || !ispath(output) || error("Refusing to overwrite benchmark output")
    p = PBO.PBF{MOI.VariableIndex,Float64}()
    for i in 1:100, j in i:100
        p[MOI.VariableIndex(i), MOI.VariableIndex(j)] = 2.0^((i + j) % 8)
    end
    q = ToQUBO.Compiler._pbf_to_rational(p)
    integers = Float64[(-1)^i * (i % 127) for i in 1:10_000]
    operations = (
        ("legacy_integral_conversion", () -> conversion_batch(legacy_exact, integers)),
        ("candidate_integral_conversion", () -> conversion_batch(ToQUBO.Compiler._exact_rational, integers)),
        ("legacy_equal_polynomials", () -> legacy_compare(p, q)),
        ("candidate_equal_polynomials", () -> ToQUBO.Compiler._pbf_matches_exact_rational(p, q)),
    )
    for _ in 1:2, (_, action) in operations
        action()
    end
    samples = Any[]
    for repetition in 1:5
        order = isodd(repetition) ? operations : reverse(operations)
        for (name, action) in order
            GC.gc()
            t = @timed action()
            @assert t.value == (occursin("polynomials", name) ? true : legacy_exact(last(integers)))
            push!(samples, Dict("operation" => name, "repetition" => repetition,
                "seconds" => t.time, "allocated_bytes" => t.bytes,
                "allocations" => Base.gc_alloc_count(t.gcstats), "gc_seconds" => t.gctime))
        end
    end
    report = Dict("julia" => string(VERSION), "threads" => Threads.nthreads(),
        "ToQUBO_source" => pathof(ToQUBO), "PBO_source" => pathof(PBO),
        "terms" => length(p), "conversion_batch_size" => length(integers),
        "warmups" => 2, "repetitions" => 5, "samples" => samples,
        "scope" => "Warmed helper microbenchmarks; fixture construction, GC between samples, imports and JIT excluded. No end-to-end or solver claim.")
    if isempty(output)
        TOML.print(stdout, report)
    else
        open(io -> TOML.print(io, report), output, "w")
    end
end
main(isempty(ARGS) ? "" : only(ARGS))
