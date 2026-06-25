module DenseNPPProfile

# In this repository, run with JuMP available from the test environment:
# JULIA_LOAD_PATH="@:test:@stdlib" julia --project=. benchmarks/dense_npp_profile.jl

import JuMP
import MathOptInterface as MOI
import QUBOTools
import ToQUBO
import ToQUBO.Attributes

const DEFAULT_N = 1000
const DEFAULT_REPEATS = 5
const DEFAULT_NON_NPP_N = 250

const SAMPLE_TYPE = NamedTuple{
    (:time, :bytes, :gctime, :compile_time),
    Tuple{Float64,Int64,Float64,Float64},
}

function _env_int(name::AbstractString, default::Int)
    return parse(Int, get(ENV, name, string(default)))
end

function _env_bool(name::AbstractString; default::Bool = false)
    value = lowercase(get(ENV, name, default ? "true" : "false"))

    return value in ("1", "true", "yes")
end

function _check_n(n::Integer)
    n > 0 || throw(ArgumentError("n must be positive"))

    return Int(n)
end

function _model(mode::Symbol)
    if mode === :cached
        return JuMP.Model(() -> ToQUBO.Optimizer{Float64}())
    elseif mode === :direct
        return JuMP.direct_model(ToQUBO.Optimizer{Float64}())
    else
        throw(ArgumentError("unknown optimizer mode: $mode"))
    end
end

function build_npp_model(n::Integer; mode::Symbol = :cached)
    n = _check_n(n)
    model = _model(mode)
    weights = collect(Float64, 1:n)

    JuMP.@variable(model, x[1:n], Bin)
    residual = JuMP.@expression(model, sum(weights[i] * (2 * x[i] - 1) for i = 1:n))
    JuMP.@objective(model, Min, residual^2)

    return model
end

function _dense_quadratic_coefficient(i::Int, j::Int, n::Int)
    return (Float64(mod(5 * i + 3 * j, 17)) - 8.0) / n
end

function build_dense_quadratic_model(n::Integer; mode::Symbol = :cached)
    n = _check_n(n)
    model = _model(mode)

    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@objective(
        model,
        Min,
        sum(_dense_quadratic_coefficient(i, j, n) * x[i] * x[j] for i = 1:n for j = i:n) +
        sum((isodd(i) ? -1.0 : 1.0) * i / n * x[i] for i = 1:n),
    )

    return model
end

function _median(values::Vector{Float64})
    sorted = sort(values)
    n = length(sorted)
    mid = n >>> 1

    return isodd(n) ? sorted[mid + 1] : (sorted[mid] + sorted[mid + 1]) / 2
end

function _sample(time::Float64, bytes::Int64, gctime::Float64; compile_time::Float64 = NaN)
    return (
        time = time,
        bytes = bytes,
        gctime = gctime,
        compile_time = compile_time,
    )::SAMPLE_TYPE
end

function _compilation_time(model)
    for target in (model, JuMP.backend(model))
        try
            return Float64(MOI.get(target, Attributes.CompilationTime()))
        catch
            # Not every JuMP backend layer exposes optimizer attributes.
        end
    end

    return NaN
end

function _summary(samples::Vector{SAMPLE_TYPE})
    times = [sample.time for sample in samples]
    bytes = [Float64(sample.bytes) for sample in samples]
    gctimes = [sample.gctime for sample in samples]
    compile_times = filter(!isnan, [sample.compile_time for sample in samples])

    return (
        samples = length(samples),
        min_time = minimum(times),
        median_time = _median(times),
        median_bytes = _median(bytes),
        median_gctime = _median(gctimes),
        median_compile_time = isempty(compile_times) ? NaN : _median(compile_times),
    )
end

function measure_construction(builder::Function, n::Integer; mode::Symbol, repeats::Int)
    samples = SAMPLE_TYPE[]

    for _ = 1:repeats
        GC.gc()
        stats = @timed begin
            builder(n; mode)
            nothing
        end
        push!(samples, _sample(stats.time, stats.bytes, stats.gctime))
    end

    return _summary(samples)
end

function measure_optimize(builder::Function, n::Integer; mode::Symbol, repeats::Int)
    samples = SAMPLE_TYPE[]

    for _ = 1:repeats
        model = builder(n; mode)
        GC.gc()
        stats = @timed begin
            JuMP.optimize!(model)
            nothing
        end
        push!(
            samples,
            _sample(
                stats.time,
                stats.bytes,
                stats.gctime;
                compile_time = _compilation_time(model),
            ),
        )
    end

    return _summary(samples)
end

function measure_backend(builder::Function, n::Integer; mode::Symbol, repeats::Int)
    samples = SAMPLE_TYPE[]

    for _ = 1:repeats
        model = builder(n; mode)
        JuMP.optimize!(model)
        GC.gc()
        stats = @timed begin
            QUBOTools.backend(model)
            nothing
        end
        push!(samples, _sample(stats.time, stats.bytes, stats.gctime))
    end

    return _summary(samples)
end

function profile_fixture(
    label::AbstractString,
    builder::Function,
    n::Integer;
    modes = (:cached, :direct),
    repeats::Int = DEFAULT_REPEATS,
    warmup::Bool = true,
)
    n = _check_n(n)
    repeats > 0 || throw(ArgumentError("repeats must be positive"))

    if warmup
        for mode in modes
            warmup_model = builder(n; mode)
            JuMP.optimize!(warmup_model)
            QUBOTools.backend(warmup_model)
        end
    end

    rows = NamedTuple[]

    for mode in modes
        push!(
            rows,
            (
                fixture = String(label),
                n = n,
                mode = mode,
                phase = "model construction",
                summary = measure_construction(builder, n; mode, repeats),
            ),
        )
        push!(
            rows,
            (
                fixture = String(label),
                n = n,
                mode = mode,
                phase = "optimize!",
                summary = measure_optimize(builder, n; mode, repeats),
            ),
        )
        push!(
            rows,
            (
                fixture = String(label),
                n = n,
                mode = mode,
                phase = "QUBOTools.backend",
                summary = measure_backend(builder, n; mode, repeats),
            ),
        )
    end

    return rows
end

function _fmt_seconds(value::Float64)
    return isnan(value) ? "" : string(round(value; digits = 6))
end

function _fmt_mib(bytes::Float64)
    return string(round(bytes / 1024^2; digits = 3))
end

function print_markdown_table(io::IO, rows)
    println(
        io,
        "| Fixture | n | Mode | Phase | Median time (s) | Min time (s) | Median alloc (MiB) | Median GC (s) | Median compile time (s) |",
    )
    println(io, "| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |")

    for row in rows
        summary = row.summary
        println(
            io,
            "| ",
            row.fixture,
            " | ",
            row.n,
            " | ",
            row.mode,
            " | ",
            row.phase,
            " | ",
            _fmt_seconds(summary.median_time),
            " | ",
            _fmt_seconds(summary.min_time),
            " | ",
            _fmt_mib(summary.median_bytes),
            " | ",
            _fmt_seconds(summary.median_gctime),
            " | ",
            _fmt_seconds(summary.median_compile_time),
            " |",
        )
    end

    return nothing
end

function main()
    n = _env_int("TOQUBO_DENSE_PROFILE_N", DEFAULT_N)
    repeats = _env_int("TOQUBO_DENSE_PROFILE_REPEATS", DEFAULT_REPEATS)
    non_npp_n = _env_int("TOQUBO_DENSE_PROFILE_NON_NPP_N", min(n, DEFAULT_NON_NPP_N))
    modes = _env_bool("TOQUBO_DENSE_PROFILE_DIRECT", default = true) ?
            (:cached, :direct) :
            (:cached,)

    rows = NamedTuple[]
    append!(
        rows,
        profile_fixture(
            "NPP-like squared affine",
            build_npp_model,
            n;
            modes,
            repeats,
        ),
    )
    append!(
        rows,
        profile_fixture(
            "generic dense quadratic",
            build_dense_quadratic_model,
            non_npp_n;
            modes,
            repeats,
        ),
    )

    println("# Dense quadratic profile")
    println()
    println("- NPP-like n: ", n)
    println("- Generic dense quadratic n: ", non_npp_n)
    println("- Repeats per phase: ", repeats)
    println(
        "- Compilation time column: `ToQUBO.Attributes.CompilationTime()` after `optimize!`",
    )
    println()
    print_markdown_table(stdout, rows)

    return rows
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    DenseNPPProfile.main()
end
