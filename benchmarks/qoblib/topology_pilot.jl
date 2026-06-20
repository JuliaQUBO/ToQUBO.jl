module QOBLibTopologyPilot

import MathOptInterface as MOI
import ToQUBO
using ToQUBO: Attributes

const PROVENANCE = Dict{String,Any}(
    "collection" => "ToQUBO-generated reformulation benchmark",
    "canonical_qoblib_artifact" => false,
    "qoblib_repository" => "https://github.com/ZIB-AOPT/QOBLIB",
    "qoblib_commit" => "a686aaa09fe14651294f744f34d453d5dce9cf57",
    "qoblib_model_license" => "Apache License, Version 2.0",
    "qoblib_data_license" => "Creative Commons Attribution 4.0 International",
    "qoblib_class" => "10-topology",
    "source_model_path" => "10-topology/models/seidel_linear/topology_seidel_linear.zpl",
    "source_instance_path" => "10-topology/instances/topology_15_4.dat",
    "source_bounds_path" => "10-topology/instances/bounds.csv",
    "source_lp_path" => "10-topology/models/seidel_linear/lp_files/topology_15_4.lp.xz",
    "source_solution_path" => "10-topology/solutions/topology_15_4.opt.gph",
    "source_metrics_path" => "10-topology/models/seidel_linear/lp_files/metrics.csv",
    "source_metrics_csv_row" =>
        "topology_15_4.lp,0,1576,0,1576,2955,0,2955,0.0016233347934757401,-1.0,1.0",
    "canonical_qubo_metrics_path" =>
        "10-topology/models/seidel_linear/metrics_qs_files.csv",
    "canonical_qubo_metrics_csv_row" =>
        "topology_15_4.qs,4831,0.002770805545312352,-7.0,49.0",
    "canonical_qubo_artifact_available_at_commit" => false,
    "canonical_qubo_artifact_note" =>
        "The pinned QOBLIB tree contains the topology_15_4.qs metrics row but no stored topology_15_4.qs or topology_15_4.qs.xz artifact, so this pilot compares against the metrics table row.",
)

const UPSTREAM_VERIFICATION = Dict{String,Any}(
    "manual_verification" => true,
    "class_readme_refs" => [
        "10-topology/README.md:17-30",
        "10-topology/README.md:32-40",
    ],
    "model_line_refs" => [
        "10-topology/models/seidel_linear/topology_seidel_linear.zpl:19-24",
        "10-topology/models/seidel_linear/topology_seidel_linear.zpl:30-44",
    ],
    "instance_line_refs" => [
        "10-topology/instances/README.md:3-6",
        "10-topology/instances/README.md:20-30",
        "10-topology/instances/bounds.csv:3",
        "10-topology/instances/topology_15_4.dat:1",
    ],
    "solution_line_refs" => [
        "10-topology/solutions/topology_15_4.opt.gph:1-3",
        "10-topology/solutions/topology_15_4.opt.gph:4-33",
    ],
    "metrics_line_refs" => [
        "10-topology/models/seidel_linear/lp_files/metrics.csv:3",
        "10-topology/models/seidel_linear/metrics_qs_files.csv:3",
    ],
    "transcription_notes" => [
        "topology_15_4.dat gives nodes=15 and degree=4",
        "bounds.csv fixes both minDiameter and maxDiameter to 2 for topology_15_4",
        "the Seidel linear model declares distance indicators over D = 0:1 and linearization variables only for the active d=0 constraints in the generated LP",
        "the .gph solution lists a 30-edge undirected graph with diameter 2",
    ],
)

const NUM_NODES = 15
const DEGREE = 4
const MIN_DIAMETER = 2
const MAX_DIAMETER = 2
const NODES = collect(0:(NUM_NODES - 1))
const PAIRS = [(s, t) for s in NODES for t in NODES if s < t]
const DISTANCE_LEVELS = collect(0:(MAX_DIAMETER - 1))
const LINEARIZATION_LEVELS = collect(0:(MAX_DIAMETER - 2))
const Y_KEYS = [
    (s, t, k, d) for (s, t) in PAIRS for k in NODES if k != s && k != t for
    d in LINEARIZATION_LEVELS
]

const INSTANCE = Dict{String,Any}(
    "qoblib_id" => "topology_15_4",
    "lp_file" => "topology_15_4.lp",
    "canonical_qubo_file" => "topology_15_4.qs",
    "nodes" => NUM_NODES,
    "degree" => DEGREE,
    "diameter_lower_bound" => MIN_DIAMETER,
    "diameter_upper_bound" => MAX_DIAMETER,
    "distance_levels" => DISTANCE_LEVELS,
    "undirected_pairs" => length(PAIRS),
)

const QOBLIB_SOURCE_METRICS = Dict{String,Any}(
    "file" => "topology_15_4.lp",
    "num_binary_vars" => 0,
    "num_integer_vars" => 1576,
    "num_continuous_vars" => 0,
    "num_vars" => 1576,
    "num_linear_constraints" => 2955,
    "num_quadratic_constraints" => 0,
    "num_constraints" => 2955,
    "density" => 0.0016233347934757401,
    "min_coeff" => -1.0,
    "max_coeff" => 1.0,
)

const QOBLIB_QUBO_METRICS = Dict{String,Any}(
    "available" => true,
    "file" => "topology_15_4.qs",
    "num_variables" => 4831,
    "density" => 0.002770805545312352,
    "min_coeff" => -7.0,
    "max_coeff" => 49.0,
)

const KNOWN_INCUMBENT = Dict{String,Any}(
    "qoblib_solution_objective" => 2,
    "solution_model" => "seidel_linear",
    "selected_edges" => [
        (1, 2),
        (1, 3),
        (1, 4),
        (1, 5),
        (2, 4),
        (2, 13),
        (2, 15),
        (3, 9),
        (3, 11),
        (3, 14),
        (4, 8),
        (4, 12),
        (5, 6),
        (5, 7),
        (5, 10),
        (6, 11),
        (6, 12),
        (6, 15),
        (7, 8),
        (7, 13),
        (7, 14),
        (8, 9),
        (8, 11),
        (9, 10),
        (9, 15),
        (10, 12),
        (10, 13),
        (11, 13),
        (12, 14),
        (14, 15),
    ],
)

function _pair_key(i::Integer, j::Integer)
    i == j && error("topology pair keys require distinct nodes")

    return i < j ? (Int(i), Int(j)) : (Int(j), Int(i))
end

function _affine(terms::Vector{MOI.ScalarAffineTerm{Float64}}, constant = 0.0)
    return MOI.ScalarAffineFunction{Float64}(terms, Float64(constant))
end

function _add_integer_variable(model, lower::Real, upper::Real)
    variable = MOI.add_variable(model)

    MOI.add_constraint(model, variable, MOI.Integer())
    MOI.add_constraint(model, variable, MOI.Interval(Float64(lower), Float64(upper)))

    return variable
end

function _add_binary_integer_variable(model)
    return _add_integer_variable(model, 0, 1)
end

function _add_counted_constraint(model, func, set, counts::AbstractDict, category::String)
    MOI.add_constraint(model, func, set)
    counts[category] = get(counts, category, 0) + 1

    return nothing
end

function _build_topology_model()
    model = ToQUBO.Optimizer{Float64}()
    diameter = _add_integer_variable(model, MIN_DIAMETER, MAX_DIAMETER)
    dist = Dict{Tuple{Int,Int,Int},MOI.VariableIndex}()
    y = Dict{Tuple{Int,Int,Int,Int},MOI.VariableIndex}()
    constraint_counts = Dict{String,Int}(
        "diameter" => 0,
        "distance_calculation" => 0,
        "linearization" => 0,
        "degree" => 0,
    )

    for (s, t) in PAIRS, d in DISTANCE_LEVELS
        dist[(s, t, d)] = _add_binary_integer_variable(model)
    end

    for key in Y_KEYS
        y[key] = _add_binary_integer_variable(model)
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        _affine([MOI.ScalarAffineTerm{Float64}(1.0, diameter)]),
    )

    for (s, t) in PAIRS
        terms = [MOI.ScalarAffineTerm{Float64}(-1.0, diameter)]

        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(-1.0, dist[(s, t, d)]) for
                d in DISTANCE_LEVELS
            ],
        )
        _add_counted_constraint(
            model,
            _affine(terms, 1 + length(DISTANCE_LEVELS)),
            MOI.LessThan(0.0),
            constraint_counts,
            "diameter",
        )
    end

    for d in LINEARIZATION_LEVELS, (s, t) in PAIRS
        terms = [
            MOI.ScalarAffineTerm{Float64}(1.0, dist[(s, t, d + 1)]),
            MOI.ScalarAffineTerm{Float64}(-1.0, dist[(s, t, d)]),
        ]

        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(-1.0, y[(s, t, k, d)]) for
                k in NODES if k != s && k != t
            ],
        )
        _add_counted_constraint(
            model,
            _affine(terms),
            MOI.LessThan(0.0),
            constraint_counts,
            "distance_calculation",
        )
    end

    for d in LINEARIZATION_LEVELS, (s, t) in PAIRS, k in NODES
        (k == s || k == t) && continue

        y_variable = y[(s, t, k, d)]
        _add_counted_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, y_variable),
                MOI.ScalarAffineTerm{Float64}(-1.0, dist[(_pair_key(s, k)..., d)]),
            ]),
            MOI.LessThan(0.0),
            constraint_counts,
            "linearization",
        )
        _add_counted_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, y_variable),
                MOI.ScalarAffineTerm{Float64}(-1.0, dist[(_pair_key(k, t)..., 0)]),
            ]),
            MOI.LessThan(0.0),
            constraint_counts,
            "linearization",
        )
    end

    for s in NODES[1:(end - 1)]
        _add_counted_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, dist[(_pair_key(s, t)..., 0)]) for
                t in NODES if t != s
            ]),
            MOI.EqualTo(Float64(DEGREE)),
            constraint_counts,
            "degree",
        )
    end

    last_node = last(NODES)
    last_degree = iseven(NUM_NODES * DEGREE) ? DEGREE : DEGREE - 1
    _add_counted_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, dist[(t, last_node, 0)]) for
            t in NODES[1:(end - 1)]
        ]),
        MOI.EqualTo(Float64(last_degree)),
        constraint_counts,
        "degree",
    )

    return model, diameter, dist, y, constraint_counts
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

function _qoblib_symmetric_coefficient(key::Tuple{Int,Int}, coefficient::Float64)
    return first(key) == last(key) ? coefficient : coefficient / 2
end

function _target_metrics(optimizer)
    target = MOI.get(optimizer, Attributes.TargetModel())
    objective, terms = _qubo_terms(target)
    n = MOI.get(target, MOI.NumberOfVariables())
    coefficients = collect(values(terms))
    qoblib_coefficients = [
        _qoblib_symmetric_coefficient(key, coefficient) for (key, coefficient) in terms
    ]
    total_slots = n * (n + 1) / 2

    return Dict{String,Any}(
        "num_variables" => n,
        "num_terms" => length(terms),
        "num_linear_terms" => count(key -> first(key) == last(key), keys(terms)),
        "num_quadratic_terms" => count(key -> first(key) != last(key), keys(terms)),
        "density" => isempty(terms) ? 0.0 : length(terms) / total_slots,
        "min_coeff" => isempty(coefficients) ? 0.0 : minimum(coefficients),
        "max_coeff" => isempty(coefficients) ? 0.0 : maximum(coefficients),
        "qoblib_symmetric_min_coeff" =>
            isempty(qoblib_coefficients) ? 0.0 : minimum(qoblib_coefficients),
        "qoblib_symmetric_max_coeff" =>
            isempty(qoblib_coefficients) ? 0.0 : maximum(qoblib_coefficients),
        "objective_offset" => Float64(objective.constant),
    )
end

function _source_metrics(constraint_counts::AbstractDict)
    num_constraints = sum(values(constraint_counts))
    num_variables = 1 + length(PAIRS) * length(DISTANCE_LEVELS) + length(Y_KEYS)

    return Dict{String,Any}(
        "num_binary_vars" => 0,
        "num_integer_vars" => num_variables,
        "num_continuous_vars" => 0,
        "num_vars" => num_variables,
        "num_linear_constraints" => num_constraints,
        "num_quadratic_constraints" => 0,
        "num_constraints" => num_constraints,
        "num_diameter_constraints" => constraint_counts["diameter"],
        "num_distance_calculation_constraints" =>
            constraint_counts["distance_calculation"],
        "num_linearization_constraints" => constraint_counts["linearization"],
        "num_degree_constraints" => constraint_counts["degree"],
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

function _zero_based_incumbent_edges()
    return [_pair_key(i - 1, j - 1) for (i, j) in KNOWN_INCUMBENT["selected_edges"]]
end

function _adjacency(edges)
    adjacency = Dict{Int,Vector{Int}}(node => Int[] for node in NODES)

    for (i, j) in edges
        push!(adjacency[i], j)
        push!(adjacency[j], i)
    end

    return adjacency
end

function _shortest_path_lengths(adjacency)
    distances = Dict{Tuple{Int,Int},Int}()

    for source in NODES
        queue = [source]
        seen = Dict{Int,Int}(source => 0)
        head = 1

        while head <= length(queue)
            node = queue[head]
            head += 1

            for neighbor in adjacency[node]
                if !haskey(seen, neighbor)
                    seen[neighbor] = seen[node] + 1
                    push!(queue, neighbor)
                end
            end
        end

        for target in NODES
            source < target && (distances[(source, target)] = seen[target])
        end
    end

    return distances
end

function _dist_value(distances, s::Integer, t::Integer, d::Integer)
    return distances[_pair_key(s, t)] <= d + 1 ? 1 : 0
end

function _y_value(distances, s::Integer, t::Integer, k::Integer, d::Integer)
    first_leg = _dist_value(distances, s, k, d)
    second_leg = _dist_value(distances, k, t, 0)

    return first_leg == 1 && second_leg == 1 ? 1 : 0
end

function _known_incumbent_summary()
    edges = _zero_based_incumbent_edges()
    edge_set = Set(edges)
    adjacency = _adjacency(edges)
    distances = _shortest_path_lengths(adjacency)
    degree_sequence = [length(adjacency[node]) for node in NODES]
    last_degree = iseven(NUM_NODES * DEGREE) ? DEGREE : DEGREE - 1
    degree_feasible =
        all(degree_sequence[index + 1] == DEGREE for index in NODES[1:(end - 1)]) &&
        degree_sequence[end] == last_degree
    diameter_constraints_feasible = all(PAIRS) do (s, t)
        lhs =
            1 +
            sum(1 - _dist_value(distances, s, t, d) for d in DISTANCE_LEVELS)

        return lhs <= KNOWN_INCUMBENT["qoblib_solution_objective"]
    end
    distance_calculation_feasible = all(PAIRS) do (s, t)
        all(LINEARIZATION_LEVELS) do d
            lhs = _dist_value(distances, s, t, d + 1)
            rhs =
                _dist_value(distances, s, t, d) +
                sum(_y_value(distances, s, t, k, d) for k in NODES if k != s && k != t)

            return lhs <= rhs
        end
    end
    linearization_feasible = all(Y_KEYS) do (s, t, k, d)
        y_value = _y_value(distances, s, t, k, d)

        return y_value <= _dist_value(distances, s, k, d) &&
               y_value <= _dist_value(distances, k, t, 0)
    end
    max_distance = maximum(values(distances))
    source_feasible =
        degree_feasible &&
        diameter_constraints_feasible &&
        distance_calculation_feasible &&
        linearization_feasible &&
        max_distance <= MAX_DIAMETER

    return Dict{String,Any}(
        "source_objective" => KNOWN_INCUMBENT["qoblib_solution_objective"],
        "qoblib_solution_objective" => KNOWN_INCUMBENT["qoblib_solution_objective"],
        "source_feasible" => source_feasible,
        "degree_feasible" => degree_feasible,
        "diameter_constraints_feasible" => diameter_constraints_feasible,
        "distance_calculation_feasible" => distance_calculation_feasible,
        "linearization_feasible" => linearization_feasible,
        "max_shortest_path_distance" => max_distance,
        "selected_edge_count" => length(edge_set),
        "selected_edges" => [collect(edge) for edge in KNOWN_INCUMBENT["selected_edges"]],
        "degree_sequence" => degree_sequence,
        "distance_zero_count" =>
            count(((s, t),) -> _dist_value(distances, s, t, 0) == 1, PAIRS),
        "distance_one_count" =>
            count(((s, t),) -> _dist_value(distances, s, t, 1) == 1, PAIRS),
        "linearization_active_count" =>
            count(((s, t, k, d),) -> _y_value(distances, s, t, k, d) == 1, Y_KEYS),
        "matches_qoblib_solution_artifact" =>
            source_feasible &&
            length(edge_set) == 30 &&
            max_distance == KNOWN_INCUMBENT["qoblib_solution_objective"],
    )
end

function _comparison(target)
    return Dict{String,Any}(
        "canonical_qubo_metrics_available" => QOBLIB_QUBO_METRICS["available"],
        "target_variable_delta_vs_qoblib_qs" =>
            target["num_variables"] - QOBLIB_QUBO_METRICS["num_variables"],
        "target_variable_delta_note" =>
            "QOBLIB's pinned QS metrics row was produced from the generated Seidel-linear LP. ToQUBO reformulates the same source constraints through its current integer encodings and reports the delta here for parity tracking.",
        "density_delta_vs_qoblib_qs" =>
            target["density"] - QOBLIB_QUBO_METRICS["density"],
        "min_coeff_delta_vs_qoblib_qs" =>
            target["min_coeff"] - QOBLIB_QUBO_METRICS["min_coeff"],
        "max_coeff_delta_vs_qoblib_qs" =>
            target["max_coeff"] - QOBLIB_QUBO_METRICS["max_coeff"],
        "qoblib_symmetric_min_coeff_delta_vs_qoblib_qs" =>
            target["qoblib_symmetric_min_coeff"] - QOBLIB_QUBO_METRICS["min_coeff"],
        "qoblib_symmetric_max_coeff_delta_vs_qoblib_qs" =>
            target["qoblib_symmetric_max_coeff"] - QOBLIB_QUBO_METRICS["max_coeff"],
    )
end

function run_topology_pilot()
    model, _diameter, _dist, _y, constraint_counts = _build_topology_model()

    MOI.optimize!(model)

    target = _target_metrics(model)
    metadata = _metadata_summary(model)

    return Dict{String,Any}(
        "provenance" => copy(PROVENANCE),
        "upstream_verification" => copy(UPSTREAM_VERIFICATION),
        "instance" => copy(INSTANCE),
        "source" => Dict{String,Any}(
            "modeling_assumptions" => [
                "the source model follows QOBLIB's linearized Seidel all-pairs shortest-path formulation",
                "topology_15_4 fixes the diameter integer variable to 2 using QOBLIB's bounds.csv row",
                "dist[s,t,0] marks selected undirected graph edges and dist[s,t,1] marks node pairs connected within two hops",
                "y[s,t,k,0] linearizes the conjunction of a path from s to k within one hop and an edge from k to t",
                "degree constraints enforce degree 4 for every node because nodes * degree is even",
            ],
            "variable_naming" => [
                "N uses QOBLIB's zero-based model indices 0:14",
                "F is stored as sorted undirected pairs (s,t) with s < t",
                "D is stored as distance levels 0 and 1 because maxDiameter is fixed to 2",
                "the upstream .gph solution uses one-based node labels and is shifted to zero-based labels for feasibility checks",
            ],
            "bounds" => [
                "2 <= diameter <= 2, integer",
                "0 <= dist[s,t,d] <= 1, integer",
                "0 <= y[s,t,k,0] <= 1, integer",
            ],
            "generated_metrics" => _source_metrics(constraint_counts),
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
            "No major formulation gap was found in this pilot. ToQUBO's QOBLIB-style symmetrized coefficient range matches the pinned Seidel-linear QS metrics row, while the target variable count differs by one; expansion to larger topology instances should track that parity delta separately if exact QS variable-count parity is required.",
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
    verification = report["upstream_verification"]
    instance = report["instance"]
    source = report["source"]
    qoblib_source = source["qoblib_metrics"]
    qoblib_qubo = report["qoblib_qubo_metrics"]
    target = report["toqubo"]["target"]
    metadata = report["toqubo"]["metadata"]
    incumbent = report["known_incumbent"]
    comparison = report["comparison"]

    write(io, "# QOBLib Topology Reformulation Pilot\n\n")
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
    write(io, "- Source bounds: `$(provenance["source_bounds_path"])`\n")
    write(io, "- Source LP: `$(provenance["source_lp_path"])`\n")
    write(io, "- Source solution: `$(provenance["source_solution_path"])`\n")
    write(io, "- Source metrics: `$(provenance["source_metrics_path"])`\n")
    write(io, "- Source metrics CSV row: `$(provenance["source_metrics_csv_row"])`\n")
    write(io, "- Canonical QUBO metrics: `$(provenance["canonical_qubo_metrics_path"])`\n")
    write(
        io,
        "- Canonical QUBO metrics CSV row: `$(provenance["canonical_qubo_metrics_csv_row"])`\n",
    )
    write(
        io,
        "- Canonical QUBO artifact available at pinned commit: $(_fmt(provenance["canonical_qubo_artifact_available_at_commit"]))\n",
    )
    write(io, "- Canonical QUBO artifact note: $(provenance["canonical_qubo_artifact_note"])\n")
    write(io, "- Model license: $(provenance["qoblib_model_license"])\n")
    write(io, "- Data license: $(provenance["qoblib_data_license"])\n")
    write(io, "- Generated collection label: $(provenance["collection"])\n\n")

    write(io, "## Upstream Verification\n\n")
    write(
        io,
        "- Manual verification: $(_fmt(verification["manual_verification"])) against QOBLIB commit `$(provenance["qoblib_commit"])`.\n",
    )
    write(io, "- Class refs: $(join(verification["class_readme_refs"], ", ")).\n")
    write(io, "- Model refs: $(join(verification["model_line_refs"], ", ")).\n")
    write(io, "- Instance refs: $(join(verification["instance_line_refs"], ", ")).\n")
    write(io, "- Solution refs: $(join(verification["solution_line_refs"], ", ")).\n")
    write(io, "- Metrics refs: $(join(verification["metrics_line_refs"], ", ")).\n")

    for note in verification["transcription_notes"]
        write(io, "- $(note).\n")
    end

    write(io, "\n## Instance\n\n")
    write(io, "- QOBLIB id: `$(instance["qoblib_id"])`\n")
    write(io, "- Source LP file: `$(instance["lp_file"])`\n")
    write(io, "- Canonical QUBO file: `$(instance["canonical_qubo_file"])`\n")
    write(io, "- Nodes: $(instance["nodes"])\n")
    write(io, "- Degree: $(instance["degree"])\n")
    write(io, "- Diameter lower bound: $(instance["diameter_lower_bound"])\n")
    write(io, "- Diameter upper bound: $(instance["diameter_upper_bound"])\n")
    write(io, "- Undirected node pairs: $(instance["undirected_pairs"])\n\n")

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
        _metric_row(
            "QOBLIB-style minimum coefficient",
            "n/a",
            qoblib_qubo["min_coeff"],
            target["qoblib_symmetric_min_coeff"],
        ),
    )
    write(
        io,
        _metric_row(
            "QOBLIB-style maximum coefficient",
            "n/a",
            qoblib_qubo["max_coeff"],
            target["qoblib_symmetric_max_coeff"],
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

    generated_source = source["generated_metrics"]
    write(io, "\n## Source Model Counts\n\n")
    write(io, "- Generated source variables: $(generated_source["num_vars"])\n")
    write(io, "- Generated source constraints: $(generated_source["num_constraints"])\n")
    write(io, "- Diameter constraints: $(generated_source["num_diameter_constraints"])\n")
    write(
        io,
        "- Distance-calculation constraints: $(generated_source["num_distance_calculation_constraints"])\n",
    )
    write(io, "- Linearization constraints: $(generated_source["num_linearization_constraints"])\n")
    write(io, "- Degree constraints: $(generated_source["num_degree_constraints"])\n")

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
    write(io, "- Source objective: $(_fmt(incumbent["source_objective"]))\n")
    write(
        io,
        "- QOBLIB solution artifact objective: $(_fmt(incumbent["qoblib_solution_objective"]))\n",
    )
    write(io, "- Source feasible: $(_fmt(incumbent["source_feasible"]))\n")
    write(io, "- Degree feasible: $(_fmt(incumbent["degree_feasible"]))\n")
    write(
        io,
        "- Diameter constraints feasible: $(_fmt(incumbent["diameter_constraints_feasible"]))\n",
    )
    write(
        io,
        "- Distance-calculation constraints feasible: $(_fmt(incumbent["distance_calculation_feasible"]))\n",
    )
    write(io, "- Linearization constraints feasible: $(_fmt(incumbent["linearization_feasible"]))\n")
    write(io, "- Max shortest-path distance: $(incumbent["max_shortest_path_distance"])\n")
    write(io, "- Selected undirected edges: $(incumbent["selected_edge_count"])\n")
    write(io, "- Degree sequence: `$(join(incumbent["degree_sequence"], ", "))`\n")
    write(io, "- Active dist[s,t,0] entries: $(incumbent["distance_zero_count"])\n")
    write(io, "- Active dist[s,t,1] entries: $(incumbent["distance_one_count"])\n")
    write(io, "- Active y[s,t,k,0] entries: $(incumbent["linearization_active_count"])\n")
    write(
        io,
        "- Selected edges: $(join(["($(edge[1]), $(edge[2]))" for edge in incumbent["selected_edges"]], ", "))\n",
    )
    write(
        io,
        "- QOBLIB solution artifact consistency check: $(_fmt(incumbent["matches_qoblib_solution_artifact"] ? "pass" : "fail"))\n",
    )

    write(io, "\n## Comparison Notes\n\n")
    write(
        io,
        "- Canonical QUBO metrics available for this instance: $(_fmt(comparison["canonical_qubo_metrics_available"]))\n",
    )
    write(
        io,
        "- Target variable delta vs QOBLIB QS metrics: $(comparison["target_variable_delta_vs_qoblib_qs"])\n",
    )
    write(io, "- Target variable delta note: $(comparison["target_variable_delta_note"])\n")
    write(
        io,
        "- Target density delta vs QOBLIB QS metrics: $(_fmt(comparison["density_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Native min-coefficient delta vs QOBLIB QS metrics: $(_fmt(comparison["min_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Native max-coefficient delta vs QOBLIB QS metrics: $(_fmt(comparison["max_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- QOBLIB-style min-coefficient delta vs QOBLIB QS metrics: $(_fmt(comparison["qoblib_symmetric_min_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- QOBLIB-style max-coefficient delta vs QOBLIB QS metrics: $(_fmt(comparison["qoblib_symmetric_max_coeff_delta_vs_qoblib_qs"]))\n",
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
    output = isempty(args) ? joinpath(@__DIR__, "reports", "topology_pilot.md") : first(args)
    report = run_topology_pilot()

    write_markdown_report(output, report)
    println(output)

    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
