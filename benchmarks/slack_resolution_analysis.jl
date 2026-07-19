module SlackResolutionAnalysis

import JuMP
import ToQUBO
using ToQUBO: Attributes

const ISSUE_208_URL = "https://github.com/JuliaQUBO/ToQUBO.jl/issues/208"
const ISSUE_205_URL = "https://github.com/JuliaQUBO/ToQUBO.jl/issues/205"
const CANONICAL_MODEL_REPOSITORY = "ZOMEGA-Group/QUBO_UC"
const CANONICAL_MODEL_BRANCH = "QUBO_feasibility_tests"
const CANONICAL_MODEL_COMMIT = "707b30a527d33da3df0cdeb3ca336d55a28ca90a"
const TOQUBO_BASE_COMMIT = "ed438ebe8ad6d39873c52894ddcc25a2825cb62c"

const CANONICAL_COMPILATION_AUDIT = [
    (
        family = "demand",
        constraints = 3,
        encoded = 3,
        slacks = 3,
        bits = "6",
        integral = "yes",
    ),
    (
        family = "level_select",
        constraints = 6,
        encoded = 6,
        slacks = 0,
        bits = "-",
        integral = "n/a",
    ),
    (
        family = "logic",
        constraints = 4,
        encoded = 4,
        slacks = 0,
        bits = "-",
        integral = "n/a",
    ),
    (
        family = "logic_t1",
        constraints = 2,
        encoded = 2,
        slacks = 0,
        bits = "-",
        integral = "n/a",
    ),
    (
        family = "min_down",
        constraints = 2,
        encoded = 2,
        slacks = 2,
        bits = "1",
        integral = "yes",
    ),
    (
        family = "min_up",
        constraints = 2,
        encoded = 2,
        slacks = 2,
        bits = "1",
        integral = "yes",
    ),
    (
        family = "ramp_down",
        constraints = 4,
        encoded = 4,
        slacks = 4,
        bits = "5-6",
        integral = "yes",
    ),
    (
        family = "ramp_down_t1",
        constraints = 2,
        encoded = 1,
        slacks = 1,
        bits = "6",
        integral = "yes",
    ),
    (
        family = "ramp_up",
        constraints = 4,
        encoded = 4,
        slacks = 4,
        bits = "5-6",
        integral = "yes",
    ),
    (
        family = "ramp_up_t1",
        constraints = 2,
        encoded = 2,
        slacks = 2,
        bits = "3",
        integral = "yes",
    ),
]

const CANONICAL_NEAL_RESULTS = [
    (
        configuration = "default",
        equality_penalty = 26_101.0,
        inequality_penalty = 26_101.0,
        feasible_rate = 0.0,
        demand = 0.06671,
        level_select = 0.99920,
        logic = 0.95144,
        logic_t1 = 0.55994,
        min_down = 0.87011,
        min_up = 0.17686,
        ramp_down = 0.13516,
        ramp_down_t1 = 0.00032,
        ramp_up = 0.23202,
        ramp_up_t1 = 0.71383,
    ),
    (
        configuration = "c2-c4 scale 100",
        equality_penalty = 2_610_100.0,
        inequality_penalty = 26_101.0,
        feasible_rate = 0.00102,
        demand = 0.29493,
        level_select = 0.60835,
        logic = 0.00023,
        logic_t1 = 0.0,
        min_down = 0.97124,
        min_up = 0.01698,
        ramp_down = 0.16468,
        ramp_down_t1 = 0.00002,
        ramp_up = 0.22597,
        ramp_up_t1 = 0.68441,
    ),
    (
        configuration = "c2-c4 scale 400",
        equality_penalty = 10_440_400.0,
        inequality_penalty = 26_101.0,
        feasible_rate = 0.00156,
        demand = 0.53475,
        level_select = 0.03960,
        logic = 0.0,
        logic_t1 = 0.0,
        min_down = 0.96308,
        min_up = 0.03197,
        ramp_down = 0.14863,
        ramp_down_t1 = 0.00275,
        ramp_up = 0.23716,
        ramp_up_t1 = 0.59002,
    ),
    (
        configuration = "c2-c4 hint 1e7",
        equality_penalty = 10_000_000.0,
        inequality_penalty = 26_101.0,
        feasible_rate = 0.00141,
        demand = 0.53050,
        level_select = 0.04322,
        logic = 0.0,
        logic_t1 = 0.0,
        min_down = 0.96395,
        min_up = 0.03017,
        ramp_down = 0.14555,
        ramp_down_t1 = 0.00247,
        ramp_up = 0.23533,
        ramp_up_t1 = 0.59103,
    ),
    (
        configuration = "inequalities scale 400",
        equality_penalty = 26_101.0,
        inequality_penalty = 10_440_400.0,
        feasible_rate = 0.0,
        demand = 0.06501,
        level_select = 0.99963,
        logic = 0.97478,
        logic_t1 = 0.72713,
        min_down = 0.84630,
        min_up = 0.31417,
        ramp_down = 0.13454,
        ramp_down_t1 = 0.00073,
        ramp_up = 0.23057,
        ramp_up_t1 = 0.69182,
    ),
]

function binary_grid_spacing(span::Real, bits::Integer)
    bits > 0 || throw(ArgumentError("bits must be positive"))

    return span / (2^bits - 1)
end
maximum_squared_residual_floor(spacing::Real) = spacing^2 / 4

function required_penalty(
    objective_advantage::Real,
    feasible_floor::Real,
    infeasible_penalty::Real,
)
    contrast = infeasible_penalty - feasible_floor

    return contrast > 0 ? objective_advantage / contrast : Inf
end

function build_fixture(bits::Integer)
    bits > 0 || throw(ArgumentError("bits must be positive"))

    model = JuMP.Model(() -> ToQUBO.Optimizer{Float64}())
    JuMP.set_attribute(model, Attributes.Discretize(), false)
    JuMP.set_attribute(model, Attributes.StableCompilation(), true)

    JuMP.@variable(model, x[1:2], Bin)
    JuMP.@objective(model, Min, -sum(x))
    capacity = JuMP.@constraint(model, 0.6sum(x) <= 1.0)
    JuMP.set_attribute(capacity, Attributes.SlackVariableEncodingBits(), bits)

    JuMP.optimize!(model)

    return model, capacity, x
end

function _constraint_descriptor(constraint)
    object = JuMP.constraint_object(constraint)

    return Dict{String,Any}(
        "function_type" => string(typeof(JuMP.moi_function(object.func))),
        "set_type" => string(typeof(object.set)),
        "id" => JuMP.index(constraint).value,
    )
end

function _entry_for_constraint(entries, constraint)
    descriptor = _constraint_descriptor(constraint)

    return only(entry for entry in entries if entry["constraint"] == descriptor)
end

function _slack_grid(slack_entry)
    coefficients =
        sort(Float64[term["coefficient"] for term in slack_entry["expansion_terms"]])
    grid = [0.0]

    for coefficient in coefficients
        grid = sort!(unique(vcat(grid, grid .+ coefficient)))
    end

    return coefficients, grid
end

function analyze_bits(bits::Integer)
    model, capacity, x = build_fixture(bits)
    metadata = ToQUBO.reformulation_metadata(JuMP.unsafe_backend(model))
    slack = _entry_for_constraint(metadata["slack_variables"], capacity)
    encoding = _entry_for_constraint(metadata["constraint_encodings"], capacity)
    coefficients, grid = _slack_grid(slack)
    span = last(grid) - first(grid)
    spacing = binary_grid_spacing(span, bits)

    @assert length(grid) == 2^bits
    @assert all(isapprox(grid[i+1] - grid[i], spacing) for i = 1:(length(grid)-1))

    feasible_state = Dict(x[1] => 1.0, x[2] => 0.0)
    infeasible_state = Dict(x[1] => 1.0, x[2] => 1.0)
    feasible_value = variable -> feasible_state[variable]
    infeasible_value = variable -> infeasible_state[variable]
    rhs = JuMP.normalized_rhs(capacity)
    feasible_residual = JuMP.value(feasible_value, capacity) - rhs
    infeasible_residual = JuMP.value(infeasible_value, capacity) - rhs
    feasible_floor = minimum((feasible_residual + slack_value)^2 for slack_value in grid)
    infeasible_penalty =
        minimum((infeasible_residual + slack_value)^2 for slack_value in grid)
    contrast = infeasible_penalty - feasible_floor
    objective = JuMP.objective_function(model)
    feasible_objective = JuMP.value(feasible_value, objective)
    infeasible_objective = JuMP.value(infeasible_value, objective)
    objective_advantage = feasible_objective - infeasible_objective
    threshold = required_penalty(objective_advantage, feasible_floor, infeasible_penalty)
    inferred_penalty = Float64(encoding["penalty"])
    feasible_energy = feasible_objective + inferred_penalty * feasible_floor
    infeasible_energy = infeasible_objective + inferred_penalty * infeasible_penalty

    return (
        bits = Int(bits),
        target_bits = length(slack["target_variables"]),
        coefficients,
        grid_points = length(grid),
        span,
        spacing,
        maximum_floor = maximum_squared_residual_floor(spacing),
        feasible_residual,
        infeasible_residual,
        feasible_objective,
        infeasible_objective,
        objective_advantage,
        feasible_floor,
        infeasible_penalty,
        contrast,
        required_penalty = threshold,
        inferred_penalty,
        inferred_prefers_feasible = feasible_energy < infeasible_energy,
        feasible_energy,
        infeasible_energy,
    )
end

function run_analysis(; bit_counts = 1:6)
    return (
        public_fixture = [analyze_bits(bits) for bits in bit_counts],
        canonical_compilation = copy(CANONICAL_COMPILATION_AUDIT),
        canonical_neal = copy(CANONICAL_NEAL_RESULTS),
    )
end

_number(value; digits = 8) = string(round(value; digits))
_percent(value) = string(round(100value; digits = 3), "%")

function _threshold(value)
    return isfinite(value) ? _number(value; digits = 4) : "impossible"
end

function write_markdown_report(io::IO, report = run_analysis())
    println(io, "# Slack-resolution penalty analysis")
    println(io)
    println(
        io,
        "This report records the analysis slice for [issue #208](",
        ISSUE_208_URL,
        "). It tests the continuous-slack mechanism separately from its proposed ",
        "causal role in [issue #205](",
        ISSUE_205_URL,
        ").",
    )
    println(io)
    println(io, "## Provenance and scope")
    println(io)
    println(io, "- ToQUBO base commit: `", TOQUBO_BASE_COMMIT, "`")
    println(io, "- Public fixture: generated by `benchmarks/slack_resolution_analysis.jl`")
    println(
        io,
        "- Canonical #205 model: access-controlled `",
        CANONICAL_MODEL_REPOSITORY,
        "`, branch `",
        CANONICAL_MODEL_BRANCH,
        "`, commit `",
        CANONICAL_MODEL_COMMIT,
        "`",
    )
    println(io, "- Canonical source copied into this repository: no")
    println(io, "- Julia: 1.10.11; JuMP: 1.30.1; ToQUBO: 0.6.0 from this checkout")
    println(io, "- Local sampler: Neal 0.6.0 with dimod 0.12.21")
    println(io, "- Sampler design: seeds 1-10, 10,000 reads per seed, 100 sweeps")
    println(io)
    println(io, "Run the public portion with:")
    println(io)
    println(io, "```sh")
    println(
        io,
        "JULIA_LOAD_PATH=\"@:test:@stdlib\" julia +1.10 --project=. benchmarks/slack_resolution_analysis.jl",
    )
    println(io, "```")
    println(io)
    println(io, "## Relationship between resolution and penalty")
    println(io)
    println(
        io,
        "For the default binary encoding of a continuous slack on `[0, S]` with `n` bits, ",
        "the grid spacing is `Delta = S / (2^n - 1)`. If a feasible source assignment ",
        "requires slack `z*`, its best squared residual is",
    )
    println(io)
    println(io, "```text")
    println(io, "p_F = min_k |z* - k Delta|^2 <= Delta^2 / 4.")
    println(io, "```")
    println(io)
    println(
        io,
        "The floor can be zero when `z*` lies on the grid; it is not strictly positive for ",
        "every feasible point and need not decrease strictly at every bit count because grid ",
        "alignment changes.",
    )
    println(io)
    println(
        io,
        "Penalty sizing depends on contrast, not on `Delta` alone. If an infeasible assignment ",
        "has penalty `p_I` and objective advantage `B` over a feasible assignment, a positive ",
        "penalty coefficient can prefer the feasible assignment only when",
    )
    println(io)
    println(io, "```text")
    println(io, "rho (p_I - p_F) > B.")
    println(io, "```")
    println(io)
    println(
        io,
        "Thus `rho > B / (p_I - p_F)` when `p_I > p_F`. If `p_I <= p_F`, increasing ",
        "`rho` cannot repair the ordering and may strengthen the wrong bias. The usual exact-",
        "penalty proof using the smallest positive penalty gap assumes feasible assignments have ",
        "zero penalty; a continuous-slack floor violates that premise.",
    )
    println(io)
    println(io, "## Executable public fixture")
    println(io)
    println(
        io,
        "The fixture minimizes `-(x1 + x2)` subject to `0.6(x1 + x2) <= 1` with binary ",
        "source variables, `Discretize(false)`, and an explicitly bit-limited binary slack on ",
        "`[0, 1]`. A one-active-variable feasible state needs slack `0.4`; the two-active-",
        "variable infeasible state has residual `0.2` and objective advantage `B = 1`.",
    )
    println(io)
    println(
        io,
        "| Bits | Grid spacing | Feasible floor `p_F` | Infeasible penalty `p_I` | Contrast | Required `rho` | Inferred `rho` | Inferred ranking |",
    )
    println(io, "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |")

    for row in report.public_fixture
        println(
            io,
            "| ",
            row.bits,
            " | ",
            _number(row.spacing),
            " | ",
            _number(row.feasible_floor),
            " | ",
            _number(row.infeasible_penalty),
            " | ",
            _number(row.contrast),
            " | ",
            _threshold(row.required_penalty),
            " | ",
            _number(row.inferred_penalty; digits = 4),
            " | ",
            row.inferred_prefers_feasible ? "feasible" : "infeasible",
            " |",
        )
    end

    println(io)
    println(
        io,
        "At one bit, the feasible floor exceeds the infeasible penalty, so no positive `rho` ",
        "can favor the feasible state. From two bits onward the contrast is positive. This is ",
        "why a universal resolution-only multiplier is not an automatic remedy.",
    )
    println(io)
    println(io, "## Canonical #205 compiler audit")
    println(io)
    println(
        io,
        "Unlike the executable public fixture, the canonical compiler-audit and Neal-sweep ",
        "tables are pinned evidence inputs from the access-controlled model; this public ",
        "script reports but cannot re-derive them.",
    )
    println(io)
    println(
        io,
        "The canonical model has 36 source variables, all binary. ToQUBO reports ",
        "`Discretize() == true`; every generated slack expansion has integral coefficients. ",
        "The reported c2-c4 families (`level_select`, `logic`, and `logic_t1`) are equalities ",
        "and generate no slack at all.",
    )
    println(io)
    println(
        io,
        "| Constraint family | Source constraints | Encoded penalties | Generated slacks | Slack bits | Integral expansion |",
    )
    println(io, "| :--- | ---: | ---: | ---: | :--- | :--- |")

    for row in report.canonical_compilation
        println(
            io,
            "| `",
            row.family,
            "` | ",
            row.constraints,
            " | ",
            row.encoded,
            " | ",
            row.slacks,
            " | ",
            row.bits,
            " | ",
            row.integral,
            " |",
        )
    end

    println(io)
    println(
        io,
        "One `ramp_down_t1` constraint is detected as always feasible and omitted, which explains ",
        "the 1-of-2 encoded count. The remaining inequality slacks are integer encodings, so the ",
        "continuous-slack residual floor is absent model-wide at this commit.",
    )
    println(io)
    println(io, "## Canonical #205 Neal sweep")
    println(io)
    println(
        io,
        "Each row aggregates 100,000 returned reads. Rates are read-weighted source-feasibility ",
        "rates, not only the best result from each run.",
    )
    println(io)
    println(
        io,
        "The canonical model was compiled without an internal solver, converted with ",
        "`QUBOTools.ising`, and sampled with a local sparse dimod BQM using the same interaction ",
        "ordering and Neal parameters as the DWave.jl wrapper.",
    )
    println(io)
    println(
        io,
        "| Configuration | c2-c4 penalty | Other penalty | Feasible | Demand violated | Level-select violated | Logic violated | Min-down violated |",
    )
    println(io, "| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")

    for row in report.canonical_neal
        println(
            io,
            "| ",
            row.configuration,
            " | ",
            _number(row.equality_penalty; digits = 1),
            " | ",
            _number(row.inequality_penalty; digits = 1),
            " | ",
            _percent(row.feasible_rate),
            " | ",
            _percent(row.demand),
            " | ",
            _percent(row.level_select),
            " | ",
            _percent(row.logic),
            " | ",
            _percent(row.min_down),
            " |",
        )
    end

    println(io)
    println(io, "Full family-level violation rates:")
    println(io)
    println(
        io,
        "| Configuration | Logic t1 | Min-up | Ramp-down | Ramp-down t1 | Ramp-up | Ramp-up t1 |",
    )
    println(io, "| :--- | ---: | ---: | ---: | ---: | ---: | ---: |")

    for row in report.canonical_neal
        println(
            io,
            "| ",
            row.configuration,
            " | ",
            _percent(row.logic_t1),
            " | ",
            _percent(row.min_up),
            " | ",
            _percent(row.ramp_down),
            " | ",
            _percent(row.ramp_down_t1),
            " | ",
            _percent(row.ramp_up),
            " | ",
            _percent(row.ramp_up_t1),
            " |",
        )
    end

    println(io)
    println(io, "## Conclusions")
    println(io)
    println(
        io,
        "- The continuous-slack mechanism is real in the public `Discretize(false)` fixture, ",
        "but the relevant weight is controlled by penalty contrast, not grid spacing alone.",
    )
    println(
        io,
        "- The mechanism does not explain #205. Its most-violated c2-c4 constraints have no ",
        "slack, and its inequality slacks are integral under the default discretization path.",
    )
    println(
        io,
        "- Increasing c2-c4 pressure changes the finite-run sampler landscape as reported: ",
        "scale 400 reduces level-selection violations from 99.92% to 3.96% and produces a ",
        "0.156% feasible-read rate, close to the fixed `1e7` result of 0.141%.",
    )
    println(
        io,
        "- Scaling only the slack-bearing inequalities does not produce a feasible read and ",
        "does not repair c2-c4. This is the opposite of the prediction from a slack-resolution ",
        "root cause.",
    )
    println(
        io,
        "- The evidence does not justify a resolution-aware automatic penalty implementation ",
        "for #205. Any general continuous-slack policy should be evaluated separately, and a ",
        "tolerance-band design must account for the nonzero-floor failure of the usual exact-",
        "penalty premise.",
    )
    println(io)
    println(io, "## Limitations and next decision")
    println(io)
    println(
        io,
        "The public fixture covers the default binary continuous encoding, not every encoding ",
        "method. The canonical solver sweep measures one seeded Neal schedule and should not be ",
        "read as an exact-solver guarantee. The access-controlled source is intentionally absent ",
        "from this repository; collaborators need access to the pinned model commit to rerun that ",
        "portion.",
    )
    println(io)
    println(
        io,
        "A follow-up documentation PR is useful to make the `Discretize()` boundary and the ",
        "penalty-contrast condition explicit. A compiler PR should not be opened from this result ",
        "without a separate design decision and evidence from genuinely continuous-slack models.",
    )

    return nothing
end

function main()
    write_markdown_report(stdout)

    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
