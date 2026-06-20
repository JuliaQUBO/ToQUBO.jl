module TSPBackendExtractionBenchmark

import MathOptInterface as MOI
import QUBOTools
import ToQUBO

const VI = MOI.VariableIndex
const SAF{T} = MOI.ScalarAffineFunction{T}
const SAT{T} = MOI.ScalarAffineTerm{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}

const DEFAULT_N = 30
const DEFAULT_BACKEND_ALLOCATION_BUDGET_BYTES = 256 * 1024^2

function _env_bool(name::AbstractString; default::Bool = false)
    value = lowercase(get(ENV, name, default ? "true" : "false"))

    return value in ("1", "true", "yes")
end

function _distance(i::Int, j::Int)
    return Float64(abs(i - j) + 1)
end

function build_tsp_style_model(n::Int)
    model = ToQUBO.Optimizer{Float64}()
    x = Matrix{VI}(undef, n, n)

    for i = 1:n, j = 1:n
        x[i, j], _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
    end

    for i = 1:n
        terms = [SAT{Float64}(1.0, x[i, j]) for j = 1:n]
        MOI.add_constraint(model, SAF{Float64}(terms, 0.0), MOI.EqualTo(1.0))
    end

    for j = 1:n
        terms = [SAT{Float64}(1.0, x[i, j]) for i = 1:n]
        MOI.add_constraint(model, SAF{Float64}(terms, 0.0), MOI.EqualTo(1.0))
    end

    quadratic_terms = SQT{Float64}[]

    for position = 1:n
        next_position = position == n ? 1 : position + 1

        for from = 1:n, to = 1:n
            from == to && continue

            push!(
                quadratic_terms,
                SQT{Float64}(_distance(from, to), x[position, from], x[next_position, to]),
            )
        end
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{SQF{Float64}}(),
        SQF{Float64}(quadratic_terms, SAT{Float64}[], 0.0),
    )

    MOI.optimize!(model)

    return model
end

function _measure(f::Function)
    GC.gc()

    return @timed f()
end

function _print_result(label::AbstractString, stats)
    println(
        label,
        ": time = ",
        round(stats.time; digits = 6),
        " s, allocated = ",
        round(stats.bytes / 1024^2; digits = 3),
        " MiB, gc = ",
        round(stats.gctime; digits = 6),
        " s",
    )

    return nothing
end

function main()
    n = parse(Int, get(ENV, "TOQUBO_TSP_BACKEND_N", string(DEFAULT_N)))
    allocation_budget = parse(
        Int,
        get(
            ENV,
            "TOQUBO_TSP_BACKEND_ALLOC_BUDGET_BYTES",
            string(DEFAULT_BACKEND_ALLOCATION_BUDGET_BYTES),
        ),
    )
    run_full_metadata = _env_bool("TOQUBO_TSP_BACKEND_FULL_METADATA")

    model = build_tsp_style_model(n)

    QUBOTools.backend(model)
    default_stats = _measure() do
        QUBOTools.backend(model)
    end

    println("TSP-style backend extraction benchmark")
    println("n = ", n)
    println("allocation budget = ", round(allocation_budget / 1024^2; digits = 3), " MiB")
    _print_result("default backend extraction", default_stats)

    if default_stats.bytes > allocation_budget
        error(
            "default backend extraction allocated $(default_stats.bytes) bytes, above " *
            "the budget of $(allocation_budget) bytes",
        )
    end

    if run_full_metadata
        full_stats = _measure() do
            QUBOTools.backend(model; full_metadata = true)
        end

        _print_result("full metadata extraction", full_stats)
    else
        println(
            "full metadata extraction skipped; set " *
            "TOQUBO_TSP_BACKEND_FULL_METADATA=true to measure it",
        )
    end

    return nothing
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    TSPBackendExtractionBenchmark.main()
end
