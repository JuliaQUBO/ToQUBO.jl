module QOBLibBirkhoffPilot

import MathOptInterface as MOI
import ToQUBO
using ToQUBO: Attributes

const PROVENANCE = Dict{String,Any}(
    "collection" => "ToQUBO-generated reformulation benchmark",
    "canonical_qoblib_artifact" => false,
    "qoblib_repository" => "https://github.com/ZIB-AOPT/QOBLIB",
    "qoblib_commit" => "a686aaa09fe14651294f744f34d453d5dce9cf57",
    "qoblib_data_license" => "Creative Commons Attribution 4.0 International",
    "qoblib_class" => "03-birkhoff",
    "source_instance_path" => "03-birkhoff/instances/qbench_03_sparse.json",
    "source_metrics_path" => "03-birkhoff/models/integer_linear/lp_files/metrics.csv",
    "canonical_qubo_metrics_path" =>
        "03-birkhoff/models/integer_linear/metrics_qs_files.csv",
)

const INSTANCE = Dict{String,Any}(
    "qoblib_id" => "B3_3_1",
    "dataset" => "qbench_03_sparse",
    "instance_number" => 1,
    "lp_file" => "bhS-03-001.lp",
    "canonical_qubo_file" => "bhS-3-001.qs",
    "n" => 3,
    "scale" => 1000,
    "scaled_doubly_stochastic_matrix" => [0, 276, 724, 276, 724, 0, 724, 0, 276],
)

const QOBLIB_SOURCE_METRICS = Dict{String,Any}(
    "file" => "bhS-03-001.lp",
    "num_binary_vars" => 0,
    "num_integer_vars" => 12,
    "num_continuous_vars" => 0,
    "num_vars" => 12,
    "num_linear_constraints" => 16,
    "num_quadratic_constraints" => 0,
    "num_constraints" => 16,
    "density" => 0.1875,
    "min_coeff" => -1000.0,
    "max_coeff" => 1.0,
)

const QOBLIB_QUBO_METRICS = Dict{String,Any}(
    "file" => "bhS-3-001.qs",
    "num_variables" => 126,
    "density" => 0.3607049118860142,
    "min_coeff" => -13346277.0,
    "max_coeff" => 7000001.0,
)

const KNOWN_INCUMBENT = Dict{String,Any}(
    "source_objective" => 2,
    "source_feasible" => true,
    "nonzero_weights" =>
        Dict{Tuple{Vararg{Int}},Int}((3, 2, 1) => 724, (2, 1, 3) => 276),
)

function _permutations(values::Vector{Int})
    if length(values) == 1
        return [copy(values)]
    end

    result = Vector{Vector{Int}}()

    for i in eachindex(values)
        rest = [values[j] for j in eachindex(values) if j != i]

        for suffix in _permutations(rest)
            push!(result, [values[i]; suffix])
        end
    end

    return result
end

function _instance_matrix()
    n = INSTANCE["n"]

    return reshape(Float64.(INSTANCE["scaled_doubly_stochastic_matrix"]), n, n)
end

function _permutation_value(permutation::Vector{Int}, row::Int, col::Int)
    return permutation[row] == col ? 1.0 : 0.0
end

function _build_birkhoff_model()
    n = INSTANCE["n"]
    scale = Float64(INSTANCE["scale"])
    matrix = _instance_matrix()
    permutations = _permutations(collect(1:n))

    model = ToQUBO.Optimizer{Float64}()
    lambda = [MOI.add_variable(model) for _ in eachindex(permutations)]
    z = [MOI.add_variable(model) for _ in eachindex(permutations)]

    for vi in lambda
        MOI.add_constraint(model, vi, MOI.Integer())
        MOI.add_constraint(model, vi, MOI.Interval(0.0, scale))
    end

    for vi in z
        MOI.add_constraint(model, vi, MOI.Integer())
        MOI.add_constraint(model, vi, MOI.Interval(0.0, 1.0))
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm{Float64}(1.0, vi) for vi in z],
            0.0,
        ),
    )

    MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm{Float64}(1.0, vi) for vi in lambda],
            0.0,
        ),
        MOI.EqualTo(scale),
    )

    for row in 1:n, col in 1:n
        MOI.add_constraint(
            model,
            MOI.ScalarAffineFunction{Float64}(
                [
                    MOI.ScalarAffineTerm{Float64}(
                        _permutation_value(permutations[i], row, col),
                        lambda[i],
                    ) for i in eachindex(permutations)
                ],
                0.0,
            ),
            MOI.EqualTo(matrix[row, col]),
        )
    end

    for i in eachindex(permutations)
        MOI.add_constraint(
            model,
            MOI.ScalarAffineFunction{Float64}(
                [
                    MOI.ScalarAffineTerm{Float64}(1.0, lambda[i]),
                    MOI.ScalarAffineTerm{Float64}(-scale, z[i]),
                ],
                0.0,
            ),
            MOI.LessThan(0.0),
        )
    end

    return model, lambda, z, permutations
end

function _term_key(vi::MOI.VariableIndex, vj::MOI.VariableIndex)
    i = vi.value
    j = vj.value

    return i <= j ? (i, j) : (j, i)
end

function _qubo_terms(target::MOI.ModelLike)
    objective_type = MOI.get(target, MOI.ObjectiveFunctionType())
    objective = MOI.get(target, MOI.ObjectiveFunction{objective_type}())
    terms = Dict{Tuple{Int,Int},Float64}()

    for term in objective.affine_terms
        key = (term.variable.value, term.variable.value)
        terms[key] = get(terms, key, 0.0) + Float64(term.coefficient)
    end

    for term in objective.quadratic_terms
        key = _term_key(term.variable_1, term.variable_2)
        terms[key] = get(terms, key, 0.0) + Float64(term.coefficient)
    end

    filter!(pair -> !iszero(last(pair)), terms)

    return objective, terms
end

function _target_metrics(optimizer)
    target = MOI.get(optimizer, Attributes.TargetModel())
    objective, terms = _qubo_terms(target)
    n = MOI.get(target, MOI.NumberOfVariables())
    coefficients = collect(values(terms))
    total_slots = n * (n + 1) / 2

    return Dict{String,Any}(
        "num_variables" => n,
        "num_terms" => length(terms),
        "num_linear_terms" => count(key -> first(key) == last(key), keys(terms)),
        "num_quadratic_terms" => count(key -> first(key) != last(key), keys(terms)),
        "density" => isempty(terms) ? 0.0 : length(terms) / total_slots,
        "min_coeff" => isempty(coefficients) ? 0.0 : minimum(coefficients),
        "max_coeff" => isempty(coefficients) ? 0.0 : maximum(coefficients),
        "objective_offset" => Float64(objective.constant),
    )
end

function _source_metrics()
    return Dict{String,Any}(
        "num_binary_vars" => 0,
        "num_integer_vars" => 12,
        "num_continuous_vars" => 0,
        "num_vars" => 12,
        "num_linear_constraints" => 16,
        "num_quadratic_constraints" => 0,
        "num_constraints" => 16,
    )
end

function _known_incumbent_values(permutations)
    weights = KNOWN_INCUMBENT["nonzero_weights"]
    lambda_values = [
        Float64(get(weights, Tuple(permutation), 0)) for permutation in permutations
    ]
    z_values = [value > 0 ? 1.0 : 0.0 for value in lambda_values]

    return lambda_values, z_values
end

function _known_incumbent_summary(permutations)
    n = INSTANCE["n"]
    scale = Float64(INSTANCE["scale"])
    matrix = _instance_matrix()
    lambda_values, z_values = _known_incumbent_values(permutations)

    matrix_feasible = all(
        sum(
            lambda_values[i] * _permutation_value(permutations[i], row, col) for
            i in eachindex(permutations)
        ) == matrix[row, col] for row in 1:n, col in 1:n
    )

    activation_feasible = all(eachindex(permutations)) do i
        0 <= lambda_values[i] <= scale * z_values[i] && z_values[i] in (0.0, 1.0)
    end

    scale_feasible = sum(lambda_values) == scale
    source_feasible = matrix_feasible && activation_feasible && scale_feasible
    source_objective = sum(z_values)

    return Dict{String,Any}(
        "source_objective" => source_objective,
        "source_feasible" => source_feasible,
        "matches_qoblib_solution_record" =>
            source_objective == KNOWN_INCUMBENT["source_objective"] && source_feasible,
    )
end

function _metadata_summary(optimizer)
    metadata = ToQUBO.reformulation_metadata(optimizer)
    penalties = metadata["applied_penalties"]

    return Dict{String,Any}(
        "schema_version" => metadata["schema_version"],
        "source_variable_count" => metadata["source"]["num_variables"],
        "target_variable_count" => metadata["target"]["num_variables"],
        "auxiliary_variable_count" => length(metadata["auxiliary_variables"]),
        "slack_variable_count" => length(metadata["slack_variables"]),
        "constraint_penalty_count" => length(penalties["constraints"]),
        "variable_penalty_count" => length(penalties["variables"]),
        "slack_penalty_count" => length(penalties["slack_variables"]),
        "target_offset" => metadata["target"]["offset"],
        "encoding_types" => sort!(unique([
            entry["encoding"]["type"] for entry in metadata["original_variables"] if
            entry["encoding"] !== nothing
        ])),
    )
end

function _comparison(toqubo_metrics)
    return Dict{String,Any}(
        "target_variable_delta_vs_qoblib_qs" =>
            toqubo_metrics["num_variables"] - QOBLIB_QUBO_METRICS["num_variables"],
        "density_delta_vs_qoblib_qs" =>
            toqubo_metrics["density"] - QOBLIB_QUBO_METRICS["density"],
        "min_coeff_delta_vs_qoblib_qs" =>
            toqubo_metrics["min_coeff"] - QOBLIB_QUBO_METRICS["min_coeff"],
        "max_coeff_delta_vs_qoblib_qs" =>
            toqubo_metrics["max_coeff"] - QOBLIB_QUBO_METRICS["max_coeff"],
    )
end

function run_birkhoff_pilot()
    model, _lambda, _z, permutations = _build_birkhoff_model()

    MOI.optimize!(model)

    target = _target_metrics(model)

    return Dict{String,Any}(
        "provenance" => copy(PROVENANCE),
        "instance" => copy(INSTANCE),
        "source" => Dict{String,Any}(
            "modeling_assumptions" => [
                "all n! permutation matrices are included as decomposition columns",
                "lambda variables are integer-bounded by the QOBLIB scale",
                "z selector variables are integer-bounded in [0, 1]",
                "activation constraints enforce lambda_i <= scale * z_i",
            ],
            "generated_metrics" => _source_metrics(),
            "qoblib_metrics" => copy(QOBLIB_SOURCE_METRICS),
        ),
        "qoblib_qubo_metrics" => copy(QOBLIB_QUBO_METRICS),
        "toqubo" => Dict{String,Any}(
            "target" => target,
            "metadata" => _metadata_summary(model),
        ),
        "known_incumbent" => _known_incumbent_summary(permutations),
        "comparison" => _comparison(target),
        "follow_up" =>
            "The pilot records a coefficient-range delta: ToQUBO's maximum coefficient is above the canonical QOBLIB metrics row for this instance. Keep this PR as the pilot evidence and investigate the penalty-scaling convention before expanding class coverage.",
    )
end

function _fmt(value)
    if value isa AbstractFloat
        return string(round(value; sigdigits = 8))
    elseif value isa Bool
        return value ? "true" : "false"
    else
        return string(value)
    end
end

function _metric_row(metric, source, canonical, generated)
    return "| $(metric) | $(_fmt(source)) | $(_fmt(canonical)) | $(_fmt(generated)) |\n"
end

function write_markdown_report(io::IO, report::AbstractDict)
    provenance = report["provenance"]
    instance = report["instance"]
    source = report["source"]
    qoblib_source = source["qoblib_metrics"]
    qoblib_qubo = report["qoblib_qubo_metrics"]
    target = report["toqubo"]["target"]
    metadata = report["toqubo"]["metadata"]
    incumbent = report["known_incumbent"]
    comparison = report["comparison"]

    write(io, "# QOBLib Birkhoff Reformulation Pilot\n\n")
    write(
        io,
        "This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.\n\n",
    )

    write(io, "## Provenance\n\n")
    write(io, "- QOBLIB repository: $(provenance["qoblib_repository"])\n")
    write(io, "- QOBLIB commit: `$(provenance["qoblib_commit"])`\n")
    write(io, "- QOBLIB class: `$(provenance["qoblib_class"])`\n")
    write(io, "- Source data: `$(provenance["source_instance_path"])`\n")
    write(io, "- Source metrics: `$(provenance["source_metrics_path"])`\n")
    write(io, "- Canonical QUBO metrics: `$(provenance["canonical_qubo_metrics_path"])`\n")
    write(io, "- Data license: $(provenance["qoblib_data_license"])\n")
    write(io, "- Generated collection label: $(provenance["collection"])\n\n")

    write(io, "## Instance\n\n")
    write(io, "- Dataset: `$(instance["dataset"])`\n")
    write(io, "- Instance: `$(lpad(string(instance["instance_number"]), 3, '0'))`\n")
    write(io, "- QOBLIB id: `$(instance["qoblib_id"])`\n")
    write(io, "- Source LP file: `$(instance["lp_file"])`\n")
    write(io, "- Canonical QUBO metrics row: `$(instance["canonical_qubo_file"])`\n")
    write(io, "- Matrix size: $(_fmt(instance["n"]))\n")
    write(io, "- Scale: $(_fmt(instance["scale"]))\n\n")

    write(io, "## Modeling Assumptions\n\n")

    for assumption in source["modeling_assumptions"]
        write(io, "- $(assumption)\n")
    end

    write(io, "\n## Metrics\n\n")
    write(io, "| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |\n")
    write(io, "|:--|--:|--:|--:|\n")
    write(
        io,
        _metric_row(
            "variables",
            qoblib_source["num_vars"],
            qoblib_qubo["num_variables"],
            target["num_variables"],
        ),
    )
    write(
        io,
        _metric_row(
            "density",
            qoblib_source["density"],
            qoblib_qubo["density"],
            target["density"],
        ),
    )
    write(
        io,
        _metric_row(
            "minimum coefficient",
            qoblib_source["min_coeff"],
            qoblib_qubo["min_coeff"],
            target["min_coeff"],
        ),
    )
    write(
        io,
        _metric_row(
            "maximum coefficient",
            qoblib_source["max_coeff"],
            qoblib_qubo["max_coeff"],
            target["max_coeff"],
        ),
    )
    write(
        io,
        _metric_row("objective offset", "n/a", "n/a", target["objective_offset"]),
    )
    write(io, _metric_row("QUBO terms", "n/a", "n/a", target["num_terms"]))
    write(
        io,
        _metric_row("quadratic terms", "n/a", "n/a", target["num_quadratic_terms"]),
    )

    write(io, "\n## Reformulation Metadata\n\n")
    write(io, "- Metadata schema version: $(metadata["schema_version"])\n")
    write(io, "- Source variables: $(metadata["source_variable_count"])\n")
    write(io, "- Target variables: $(metadata["target_variable_count"])\n")
    write(io, "- Auxiliary variables: $(metadata["auxiliary_variable_count"])\n")
    write(io, "- Slack variables: $(metadata["slack_variable_count"])\n")
    write(io, "- Constraint penalties: $(metadata["constraint_penalty_count"])\n")
    write(io, "- Variable penalties: $(metadata["variable_penalty_count"])\n")
    write(io, "- Slack penalties: $(metadata["slack_penalty_count"])\n")
    write(io, "- Encoding types: `$(join(metadata["encoding_types"], "`, `"))`\n")
    write(io, "\n## Known Incumbent\n\n")
    write(io, "- Source objective: $(_fmt(incumbent["source_objective"]))\n")
    write(io, "- Source feasible: $(_fmt(incumbent["source_feasible"]))\n")
    write(
        io,
        "- Matches QOBLIB solution record: $(_fmt(incumbent["matches_qoblib_solution_record"]))\n",
    )

    write(io, "\n## Comparison Deltas\n\n")
    write(
        io,
        "- Target variable delta vs QOBLIB canonical QUBO metrics: $(comparison["target_variable_delta_vs_qoblib_qs"])\n",
    )
    write(
        io,
        "- Density delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["density_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Minimum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["min_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Maximum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["max_coeff_delta_vs_qoblib_qs"]))\n",
    )

    write(io, "\n## Follow-Up\n\n")
    write(io, report["follow_up"], "\n")

    return nothing
end

function write_markdown_report(path::AbstractString, report::AbstractDict)
    mkpath(dirname(path))

    open(path, "w") do io
        write_markdown_report(io, report)
    end

    return path
end

function main(args = ARGS)
    output = isempty(args) ? joinpath(@__DIR__, "reports", "birkhoff_pilot.md") : first(args)
    report = run_birkhoff_pilot()

    write_markdown_report(output, report)
    println(output)

    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
