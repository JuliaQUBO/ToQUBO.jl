module QOBLibSteinerPilot

import MathOptInterface as MOI
import ToQUBO
using ToQUBO: Attributes

const PROVENANCE = Dict{String,Any}(
    "collection" => "ToQUBO-generated reformulation benchmark",
    "canonical_qoblib_artifact" => false,
    "qoblib_repository" => "https://github.com/ZIB-AOPT/QOBLIB",
    "qoblib_commit" => "a686aaa09fe14651294f744f34d453d5dce9cf57",
    "qoblib_data_license" => "Creative Commons Attribution 4.0 International",
    "qoblib_class" => "04-steiner",
    "source_model_path" => "04-steiner/models/integer_linear/stp_node_disjoint.zpl",
    "source_instance_path" => "04-steiner/instances/stp_s003_l1_t2_h0_rs97531",
    "source_metrics_path" => "04-steiner/models/integer_linear/lp_files/metrics.csv",
    "source_metrics_csv_row" =>
        "stp_s003_l1_t2_h0_rs97531.lp,0,48,0,48,44,0,44,0.056818181818181816,-1.0,1.0",
    "canonical_qubo_metrics_path" =>
        "04-steiner/models/integer_linear/metrics_qs_files.csv",
    "canonical_qubo_metrics_available" => false,
    "canonical_qubo_metrics_note" =>
        "The pinned QOBLIB metrics_qs_files.csv has rows for larger Steiner instances, but no row or stored QS artifact for stp_s003_l1_t2_h0_rs97531; this pilot reports ToQUBO-generated QUBO metrics for the smallest source instance instead.",
)

const INSTANCE = Dict{String,Any}(
    "qoblib_id" => "stp_s003_l1_t2_h0_rs97531",
    "lp_file" => "stp_s003_l1_t2_h0_rs97531.lp",
    "size" => 3,
    "layers" => 1,
    "terminals" => 2,
    "holes" => 0,
    "random_seed" => 97531,
    "nodes" => 9,
    "nets" => 1,
    "roots" => [1],
    "terms" => [9],
    "special_nodes" => [1, 9],
)

const ARCS = [
    (1, 2, 1),
    (2, 1, 1),
    (1, 4, 1),
    (4, 1, 1),
    (2, 3, 1),
    (3, 2, 1),
    (2, 5, 1),
    (5, 2, 1),
    (3, 6, 1),
    (6, 3, 1),
    (4, 5, 1),
    (5, 4, 1),
    (4, 7, 1),
    (7, 4, 1),
    (5, 6, 1),
    (6, 5, 1),
    (5, 8, 1),
    (8, 5, 1),
    (6, 9, 1),
    (9, 6, 1),
    (7, 8, 1),
    (8, 7, 1),
    (8, 9, 1),
    (9, 8, 1),
]

const QOBLIB_SOURCE_METRICS = Dict{String,Any}(
    "file" => "stp_s003_l1_t2_h0_rs97531.lp",
    "num_binary_vars" => 0,
    "num_integer_vars" => 48,
    "num_continuous_vars" => 0,
    "num_vars" => 48,
    "num_linear_constraints" => 44,
    "num_quadratic_constraints" => 0,
    "num_constraints" => 44,
    "density" => 0.056818181818181816,
    "min_coeff" => -1.0,
    "max_coeff" => 1.0,
)

const QOBLIB_QUBO_METRICS = Dict{String,Any}(
    "available" => false,
    "file" => nothing,
    "num_variables" => nothing,
    "density" => nothing,
    "min_coeff" => nothing,
    "max_coeff" => nothing,
)

const KNOWN_INCUMBENT = Dict{String,Any}(
    "source_objective" => 4,
    "source_feasible" => true,
    "active_arcs" => [(1, 2), (2, 3), (3, 6), (6, 9)],
    "solution_path" => "1 -> 2 -> 3 -> 6 -> 9",
)

function _arc_tail(index::Integer)
    return ARCS[index][1]
end

function _arc_head(index::Integer)
    return ARCS[index][2]
end

function _arc_cost(index::Integer)
    return ARCS[index][3]
end

function _indices_with_tail(node::Integer)
    return [index for index in eachindex(ARCS) if _arc_tail(index) == node]
end

function _indices_with_head(node::Integer)
    return [index for index in eachindex(ARCS) if _arc_head(index) == node]
end

function _affine(terms::Vector{MOI.ScalarAffineTerm{Float64}}, constant = 0.0)
    return MOI.ScalarAffineFunction{Float64}(terms, Float64(constant))
end

function _add_binary_integer_variable(model)
    variable = MOI.add_variable(model)

    MOI.add_constraint(model, variable, MOI.Integer())
    MOI.add_constraint(model, variable, MOI.Interval(0.0, 1.0))

    return variable
end

function _build_steiner_model()
    model = ToQUBO.Optimizer{Float64}()
    x = [_add_binary_integer_variable(model) for _ in eachindex(ARCS)]
    y = [_add_binary_integer_variable(model) for _ in eachindex(ARCS)]
    root = only(INSTANCE["roots"])
    term = only(INSTANCE["terms"])
    normal_nodes = setdiff(collect(1:INSTANCE["nodes"]), INSTANCE["special_nodes"])

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        _affine([
            MOI.ScalarAffineTerm{Float64}(Float64(_arc_cost(index)), y[index]) for
            index in eachindex(ARCS)
        ]),
    )

    MOI.add_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, x[index]) for
            index in _indices_with_tail(root)
        ]),
        MOI.EqualTo(1.0),
    )
    MOI.add_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, x[index]) for
            index in _indices_with_head(root)
        ]),
        MOI.EqualTo(0.0),
    )
    MOI.add_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, x[index]) for
            index in _indices_with_tail(term)
        ]),
        MOI.EqualTo(0.0),
    )
    MOI.add_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, x[index]) for
            index in _indices_with_head(term)
        ]),
        MOI.EqualTo(1.0),
    )

    for node in normal_nodes
        terms = MOI.ScalarAffineTerm{Float64}[]

        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(1.0, x[index]) for
                index in _indices_with_tail(node)
            ],
        )
        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(-1.0, x[index]) for
                index in _indices_with_head(node)
            ],
        )

        MOI.add_constraint(model, _affine(terms), MOI.EqualTo(0.0))
    end

    for index in eachindex(ARCS)
        MOI.add_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, x[index]),
                MOI.ScalarAffineTerm{Float64}(-1.0, y[index]),
            ]),
            MOI.LessThan(0.0),
        )
    end

    for node in setdiff(collect(1:INSTANCE["nodes"]), INSTANCE["roots"])
        MOI.add_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, y[index]) for
                index in _indices_with_head(node)
            ]),
            MOI.LessThan(1.0),
        )
    end

    MOI.add_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, y[index]) for
            index in _indices_with_head(root)
        ]),
        MOI.LessThan(0.0),
    )

    return model, x, y
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
        "num_integer_vars" => length(ARCS) * 2,
        "num_continuous_vars" => 0,
        "num_vars" => length(ARCS) * 2,
        "num_linear_constraints" => 44,
        "num_quadratic_constraints" => 0,
        "num_constraints" => 44,
        "num_flow_constraints" => 11,
        "num_binding_constraints" => length(ARCS),
        "num_disjointness_constraints" => 9,
    )
end

function _metadata_summary(optimizer)
    return _metadata_summary(ToQUBO.reformulation_metadata(optimizer))
end

function _metadata_summary(metadata::AbstractDict)
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
        "constraint_penalties" =>
            sort!(unique(Float64(entry["penalty"]) for entry in penalties["constraints"])),
        "encoding_types" => sort!(unique([
            entry["encoding"]["type"] for entry in metadata["original_variables"] if
            entry["encoding"] !== nothing
        ])),
    )
end

function _known_incumbent_summary()
    active = Set(KNOWN_INCUMBENT["active_arcs"])
    root = only(INSTANCE["roots"])
    term = only(INSTANCE["terms"])
    normal_nodes = setdiff(collect(1:INSTANCE["nodes"]), INSTANCE["special_nodes"])
    active_indices = [
        index for index in eachindex(ARCS) if (_arc_tail(index), _arc_head(index)) in active
    ]
    out_count(node) = count(index -> _arc_tail(index) == node, active_indices)
    in_count(node) = count(index -> _arc_head(index) == node, active_indices)
    source_objective = sum(_arc_cost(index) for index in active_indices)
    flow_feasible =
        out_count(root) == 1 &&
        in_count(root) == 0 &&
        out_count(term) == 0 &&
        in_count(term) == 1 &&
        all(node -> out_count(node) - in_count(node) == 0, normal_nodes)
    disjoint_feasible =
        all(node -> in_count(node) <= 1, setdiff(collect(1:INSTANCE["nodes"]), INSTANCE["roots"])) &&
        in_count(root) == 0
    x_active(index) = (_arc_tail(index), _arc_head(index)) in active
    y_active(index) = (_arc_tail(index), _arc_head(index)) in active
    binding_feasible = all(index -> !x_active(index) || y_active(index), eachindex(ARCS))
    source_feasible = flow_feasible && disjoint_feasible && binding_feasible

    return Dict{String,Any}(
        "source_objective" => source_objective,
        "source_feasible" => source_feasible,
        "flow_feasible" => flow_feasible,
        "disjointness_feasible" => disjoint_feasible,
        "binding_feasible" => binding_feasible,
        "active_arcs" => [collect(arc) for arc in KNOWN_INCUMBENT["active_arcs"]],
        "solution_path" => KNOWN_INCUMBENT["solution_path"],
        "matches_qoblib_solution_record" =>
            source_objective == KNOWN_INCUMBENT["source_objective"] && source_feasible,
    )
end

function _comparison(target)
    return Dict{String,Any}(
        "canonical_qubo_metrics_available" => QOBLIB_QUBO_METRICS["available"],
        "target_variables_minus_source_integer_vars" =>
            target["num_variables"] - QOBLIB_SOURCE_METRICS["num_integer_vars"],
        "density_source_to_target_delta" =>
            target["density"] - QOBLIB_SOURCE_METRICS["density"],
    )
end

function run_steiner_pilot()
    model, _x, _y = _build_steiner_model()

    MOI.optimize!(model)

    target = _target_metrics(model)
    metadata = _metadata_summary(model)

    return Dict{String,Any}(
        "provenance" => copy(PROVENANCE),
        "instance" => copy(INSTANCE),
        "source" => Dict{String,Any}(
            "modeling_assumptions" => [
                "the source model follows QOBLIB's node-disjoint Steiner tree packing formulation",
                "x variables route one unit of flow from the root to each terminal",
                "y variables mark selected directed arcs for the only net",
                "all x and y variables are integer-bounded in [0, 1]",
                "node-disjointness limits every non-root node to at most one selected incoming arc and forbids incoming selected arcs to the root",
            ],
            "variable_naming" => [
                "x[a,t] is represented as x[index] because the pilot has one terminal t = 9",
                "y[a,k] is represented as y[index] because the pilot has one net k = 1",
                "arc indices follow the upstream arcs.dat order",
            ],
            "bounds" => [
                "0 <= x[index] <= 1, integer",
                "0 <= y[index] <= 1, integer",
            ],
            "generated_metrics" => _source_metrics(),
            "qoblib_metrics" => copy(QOBLIB_SOURCE_METRICS),
        ),
        "qoblib_qubo_metrics" => copy(QOBLIB_QUBO_METRICS),
        "toqubo" => Dict{String,Any}(
            "target" => target,
            "metadata" => metadata,
        ),
        "known_incumbent" => _known_incumbent_summary(),
        "comparison" => _comparison(target),
        "follow_up" =>
            "No major formulation gap was found in this pilot. The smallest Steiner source instance has no pinned canonical QUBO metrics row, so expansion to larger Steiner instances should be tracked separately if canonical QS parity is required.",
    )
end

function _fmt(value)
    if value === nothing
        return "n/a"
    elseif value isa AbstractFloat
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

    write(io, "# QOBLib Steiner Reformulation Pilot\n\n")
    write(
        io,
        "This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.\n\n",
    )

    write(io, "## Provenance\n\n")
    write(io, "- QOBLIB repository: $(provenance["qoblib_repository"])\n")
    write(io, "- QOBLIB commit: `$(provenance["qoblib_commit"])`\n")
    write(io, "- QOBLIB class: `$(provenance["qoblib_class"])`\n")
    write(io, "- Source model: `$(provenance["source_model_path"])`\n")
    write(io, "- Source instance: `$(provenance["source_instance_path"])`\n")
    write(io, "- Source metrics: `$(provenance["source_metrics_path"])`\n")
    write(io, "- Source metrics CSV row: `$(provenance["source_metrics_csv_row"])`\n")
    write(io, "- Canonical QUBO metrics: `$(provenance["canonical_qubo_metrics_path"])`\n")
    write(io, "- Canonical QUBO metrics available for this instance: false\n")
    write(io, "- Canonical QUBO metrics note: $(provenance["canonical_qubo_metrics_note"])\n")
    write(io, "- Data license: $(provenance["qoblib_data_license"])\n")
    write(io, "- Generated collection label: $(provenance["collection"])\n\n")

    write(io, "## Instance\n\n")
    write(io, "- QOBLIB id: `$(instance["qoblib_id"])`\n")
    write(io, "- Source LP file: `$(instance["lp_file"])`\n")
    write(io, "- Size: $(instance["size"])\n")
    write(io, "- Layers: $(instance["layers"])\n")
    write(io, "- Terminals: $(instance["terminals"])\n")
    write(io, "- Holes: $(instance["holes"])\n")
    write(io, "- Random seed: $(instance["random_seed"])\n")
    write(io, "- Nodes: $(instance["nodes"])\n")
    write(io, "- Nets: $(instance["nets"])\n")
    write(io, "- Roots: `$(join(instance["roots"], ", "))`\n")
    write(io, "- Terms: `$(join(instance["terms"], ", "))`\n\n")

    write(io, "## Modeling Assumptions\n\n")

    for assumption in source["modeling_assumptions"]
        write(io, "- $(assumption)\n")
    end

    write(io, "\n## Bounds and Naming\n\n")

    for bound in source["bounds"]
        write(io, "- $(bound)\n")
    end

    for naming in source["variable_naming"]
        write(io, "- $(naming)\n")
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
    write(io, "- Distinct constraint penalties: $(join(_fmt.(metadata["constraint_penalties"]), ", "))\n")
    write(io, "- Encoding types: `$(join(metadata["encoding_types"], "`, `"))`\n")

    write(io, "\n## Known Incumbent\n\n")
    write(io, "- QOBLIB solution path: $(incumbent["solution_path"])\n")
    write(io, "- Active arcs: $(join(["($(arc[1]), $(arc[2]))" for arc in incumbent["active_arcs"]], ", "))\n")
    write(io, "- Source objective: $(_fmt(incumbent["source_objective"]))\n")
    write(io, "- Source feasible: $(_fmt(incumbent["source_feasible"]))\n")
    write(io, "- Flow feasible: $(_fmt(incumbent["flow_feasible"]))\n")
    write(io, "- Node-disjointness feasible: $(_fmt(incumbent["disjointness_feasible"]))\n")
    write(io, "- Matches QOBLIB solution record: $(_fmt(incumbent["matches_qoblib_solution_record"]))\n")

    write(io, "\n## Comparison Notes\n\n")
    write(
        io,
        "- Canonical QUBO metrics available for this instance: $(_fmt(comparison["canonical_qubo_metrics_available"]))\n",
    )
    write(
        io,
        "- Target variable delta vs QOBLIB source integer variables: $(comparison["target_variables_minus_source_integer_vars"])\n",
    )
    write(
        io,
        "- Target density delta vs QOBLIB source LP density: $(_fmt(comparison["density_source_to_target_delta"]))\n",
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
    output = isempty(args) ? joinpath(@__DIR__, "reports", "steiner_pilot.md") : first(args)
    report = run_steiner_pilot()

    write_markdown_report(output, report)
    println(output)

    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
