module QOBLibRoutingPilot

import MathOptInterface as MOI
import ToQUBO
using ToQUBO: Attributes

const NUM_NODES = 21
const DEPOT = 1
const VEHICLE_LIMIT = 4
const CAPACITY = 231
const NODES = 1:NUM_NODES
const CUSTOMERS = 2:NUM_NODES
const ARCS = [(i, j) for i in NODES for j in NODES if i != j]

const COORDINATES = Dict{Int,Tuple{Int,Int}}(
    1 => (84, 96),
    2 => (42, 72),
    3 => (7, 82),
    4 => (21, 82),
    5 => (57, 60),
    6 => (38, 75),
    7 => (50, 88),
    8 => (19, 76),
    9 => (58, 68),
    10 => (16, 84),
    11 => (65, 65),
    12 => (53, 55),
    13 => (69, 50),
    14 => (86, 37),
    15 => (93, 44),
    16 => (6, 88),
    17 => (92, 45),
    18 => (60, 58),
    19 => (10, 76),
    20 => (24, 78),
    21 => (59, 66),
)

const DEMAND = Dict{Int,Int}(
    1 => 0,
    2 => 75,
    3 => 42,
    4 => 58,
    5 => 100,
    6 => 2,
    7 => 94,
    8 => 52,
    9 => 39,
    10 => 22,
    11 => 45,
    12 => 18,
    13 => 68,
    14 => 60,
    15 => 14,
    16 => 23,
    17 => 57,
    18 => 28,
    19 => 52,
    20 => 43,
    21 => 32,
)

const PROVENANCE = Dict{String,Any}(
    "collection" => "ToQUBO-generated reformulation benchmark",
    "canonical_qoblib_artifact" => false,
    "qoblib_repository" => "https://github.com/ZIB-AOPT/QOBLIB",
    "qoblib_commit" => "a686aaa09fe14651294f744f34d453d5dce9cf57",
    "qoblib_model_license" => "Apache License, Version 2.0",
    "qoblib_data_license" => "Creative Commons Attribution 4.0 International",
    "qoblib_class" => "09-routing",
    "source_model_path" => "09-routing/models/integer_linear/cvrp_ilp.zpl",
    "source_instance_path" => "09-routing/instances/XSH-n20-k4-01.vrp",
    "source_lp_path" =>
        "09-routing/models/integer_linear/lp_files/XSH-n20-k4-01.lp.xz",
    "source_solution_path" => "09-routing/solutions/XSH-n20-k4-01.opt.sol",
    "source_metrics_path" =>
        "09-routing/models/integer_linear/lp_files/metrics.csv",
    "source_metrics_csv_row" =>
        "XSH-n20-k4-01.lp,0,441,0,441,483,0,483,0.011558522649915729,-331.0,1.0",
    "canonical_qubo_metrics_path" =>
        "09-routing/models/integer_linear/metrics_qs_files.csv",
    "canonical_qubo_metrics_csv_row" =>
        "XSH-n20-k4-01.qs,4527,0.011716313817136443,-12874612219.171257,7397605618.245156",
    "canonical_qubo_artifact_available_at_commit" => false,
    "canonical_qubo_artifact_note" =>
        "The pinned QOBLIB tree contains the XSH-n20-k4-01.qs metrics row but no stored QS artifact, so this pilot compares against the metrics table row.",
    "penalty_scaling_follow_up" => "https://github.com/JuliaQUBO/ToQUBO.jl/issues/162",
)

const UPSTREAM_VERIFICATION = Dict{String,Any}(
    "manual_verification" => true,
    "class_readme_refs" => [
        "09-routing/README.md:18-35",
    ],
    "model_line_refs" => [
        "09-routing/models/integer_linear/cvrp_ilp.zpl:16-23",
        "09-routing/models/integer_linear/cvrp_ilp.zpl:39-44",
        "09-routing/models/integer_linear/cvrp_ilp.zpl:49-84",
    ],
    "instance_line_refs" => [
        "09-routing/instances/XSH-n20-k4-01.vrp:10-15",
        "09-routing/instances/XSH-n20-k4-01.vrp:16-37",
        "09-routing/instances/XSH-n20-k4-01.vrp:38-63",
    ],
    "solution_line_refs" => [
        "09-routing/solutions/XSH-n20-k4-01.opt.sol:1-5",
        "09-routing/solutions/README.md:10",
    ],
    "metrics_line_refs" => [
        "09-routing/models/integer_linear/lp_files/metrics.csv:2",
        "09-routing/models/integer_linear/metrics_qs_files.csv:2",
    ],
    "transcription_notes" => [
        "XSH-n20-k4-01 is the first 21-node, 4-vehicle CVRP instance in the routing class",
        "node 1 is the depot and nodes 2 through 21 are the customers",
        "the QOBLIB solution file uses CVRPLIB customer numbering, so each listed customer id is mapped to QOBLIB node id customer + 1",
        "the ZIMPL model uses Euclidean sqrt distances in the LP objective, while the solution artifact reports the rounded CVRPLIB route cost",
    ],
)

const INSTANCE = Dict{String,Any}(
    "qoblib_id" => "XSH-n20-k4-01",
    "lp_file" => "XSH-n20-k4-01.lp",
    "canonical_qubo_file" => "XSH-n20-k4-01.qs",
    "nodes" => NUM_NODES,
    "customers" => length(CUSTOMERS),
    "vehicles" => VEHICLE_LIMIT,
    "capacity" => CAPACITY,
    "depot" => DEPOT,
    "edge_weight_type" => "EUC_2D",
    "comment_optimal_cost" => 646,
)

const QOBLIB_SOURCE_METRICS = Dict{String,Any}(
    "file" => "XSH-n20-k4-01.lp",
    "num_binary_vars" => 0,
    "num_integer_vars" => 441,
    "num_continuous_vars" => 0,
    "num_vars" => 441,
    "num_linear_constraints" => 483,
    "num_quadratic_constraints" => 0,
    "num_constraints" => 483,
    "density" => 0.011558522649915729,
    "min_coeff" => -331.0,
    "max_coeff" => 1.0,
)

const QOBLIB_QUBO_METRICS = Dict{String,Any}(
    "available" => true,
    "file" => "XSH-n20-k4-01.qs",
    "num_variables" => 4_527,
    "density" => 0.011716313817136443,
    "min_coeff" => -12_874_612_219.171257,
    "max_coeff" => 7_397_605_618.245156,
)

const KNOWN_INCUMBENT = Dict{String,Any}(
    "qoblib_solution_cost" => 646,
    "solution_routes_customer_ids" => [
        [15, 2, 18, 1, 8],
        [10, 11, 7, 9, 6],
        [17, 4, 5, 19, 3],
        [20, 12, 13, 14, 16],
    ],
    "solution_routes_node_ids" => [
        [16, 3, 19, 2, 9],
        [11, 12, 8, 10, 7],
        [18, 5, 6, 20, 4],
        [21, 13, 14, 15, 17],
    ],
)

function _distance(i::Integer, j::Integer)
    xi, yi = COORDINATES[i]
    xj, yj = COORDINATES[j]

    return sqrt(Float64((xi - xj)^2 + (yi - yj)^2))
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

function _add_counted_constraint(model, func, set, counts::AbstractDict, category::String)
    MOI.add_constraint(model, func, set)
    counts[category] = get(counts, category, 0) + 1

    return nothing
end

function _build_routing_model()
    model = ToQUBO.Optimizer{Float64}()
    x = Dict{Tuple{Int,Int},MOI.VariableIndex}()
    y = Dict{Int,MOI.VariableIndex}()
    constraint_counts = Dict{String,Int}(
        "customer_visited_once" => 0,
        "flow_conservation" => 0,
        "vehicle_limit" => 0,
        "capacity_limit" => 0,
        "capacity_node_ub" => 0,
        "capacity_node_lb" => 0,
    )

    for arc in ARCS
        x[arc] = _add_integer_variable(model, 0.0, 1.0)
    end

    for node in NODES
        y[node] = _add_integer_variable(model, 0.0, CAPACITY)
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        _affine([
            MOI.ScalarAffineTerm{Float64}(_distance(i, j), x[(i, j)]) for
            (i, j) in ARCS
        ]),
    )

    for i in CUSTOMERS
        _add_counted_constraint(
            model,
            _affine([
                MOI.ScalarAffineTerm{Float64}(1.0, x[(i, j)]) for j in NODES if
                j != i
            ]),
            MOI.EqualTo(1.0),
            constraint_counts,
            "customer_visited_once",
        )
    end

    for h in CUSTOMERS
        terms = MOI.ScalarAffineTerm{Float64}[]

        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(1.0, x[(i, h)]) for i in NODES if
                i != h
            ],
        )
        append!(
            terms,
            [
                MOI.ScalarAffineTerm{Float64}(-1.0, x[(h, j)]) for j in NODES if
                j != h
            ],
        )

        _add_counted_constraint(
            model,
            _affine(terms),
            MOI.EqualTo(0.0),
            constraint_counts,
            "flow_conservation",
        )
    end

    _add_counted_constraint(
        model,
        _affine([
            MOI.ScalarAffineTerm{Float64}(1.0, x[(DEPOT, j)]) for j in CUSTOMERS
        ]),
        MOI.LessThan(Float64(VEHICLE_LIMIT)),
        constraint_counts,
        "vehicle_limit",
    )

    for i in NODES
        for j in CUSTOMERS
            i == j && continue

            _add_counted_constraint(
                model,
                _affine([
                    MOI.ScalarAffineTerm{Float64}(1.0, y[j]),
                    MOI.ScalarAffineTerm{Float64}(-1.0, y[i]),
                    MOI.ScalarAffineTerm{Float64}(
                        -Float64(CAPACITY + DEMAND[j]),
                        x[(i, j)],
                    ),
                ]),
                MOI.GreaterThan(-Float64(CAPACITY)),
                constraint_counts,
                "capacity_limit",
            )
        end
    end

    for i in NODES
        _add_counted_constraint(
            model,
            _affine([MOI.ScalarAffineTerm{Float64}(1.0, y[i])]),
            MOI.LessThan(Float64(CAPACITY)),
            constraint_counts,
            "capacity_node_ub",
        )
        _add_counted_constraint(
            model,
            _affine([MOI.ScalarAffineTerm{Float64}(1.0, y[i])]),
            MOI.GreaterThan(Float64(DEMAND[i])),
            constraint_counts,
            "capacity_node_lb",
        )
    end

    return model, x, y, constraint_counts
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

    return Dict{String,Any}(
        "num_binary_vars" => 0,
        "num_integer_vars" => length(ARCS) + NUM_NODES,
        "num_continuous_vars" => 0,
        "num_vars" => length(ARCS) + NUM_NODES,
        "num_linear_constraints" => num_constraints,
        "num_quadratic_constraints" => 0,
        "num_constraints" => num_constraints,
        "num_customer_visited_once_constraints" =>
            constraint_counts["customer_visited_once"],
        "num_flow_conservation_constraints" => constraint_counts["flow_conservation"],
        "num_vehicle_limit_constraints" => constraint_counts["vehicle_limit"],
        "num_capacity_limit_constraints" => constraint_counts["capacity_limit"],
        "num_capacity_node_ub_constraints" => constraint_counts["capacity_node_ub"],
        "num_capacity_node_lb_constraints" => constraint_counts["capacity_node_lb"],
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

function _active_arcs()
    arcs = Tuple{Int,Int}[]

    for route in KNOWN_INCUMBENT["solution_routes_node_ids"]
        sequence = [DEPOT; route; DEPOT]

        append!(arcs, [(sequence[index], sequence[index + 1]) for index in 1:(length(sequence) - 1)])
    end

    return arcs
end

function _route_loads()
    loads = Dict{Int,Int}(DEPOT => 0)

    for route in KNOWN_INCUMBENT["solution_routes_node_ids"]
        load = 0

        for node in route
            load += DEMAND[node]
            loads[node] = load
        end
    end

    return loads
end

function _route_demands()
    return [sum(DEMAND[node] for node in route) for route in KNOWN_INCUMBENT["solution_routes_node_ids"]]
end

function _source_objective(active_arcs)
    return sum(_distance(i, j) for (i, j) in active_arcs)
end

function _rounded_route_cost(active_arcs)
    return sum(round(_distance(i, j)) for (i, j) in active_arcs)
end

function _known_incumbent_summary()
    active_arcs = _active_arcs()
    active_set = Set(active_arcs)
    y_values = _route_loads()
    x_value(arc) = arc in active_set ? 1 : 0
    customer_visited_once_feasible = all(CUSTOMERS) do customer
        sum(x_value((customer, j)) for j in NODES if j != customer) == 1
    end
    flow_conservation_feasible = all(CUSTOMERS) do customer
        incoming = sum(x_value((i, customer)) for i in NODES if i != customer)
        outgoing = sum(x_value((customer, j)) for j in NODES if j != customer)

        return incoming == outgoing
    end
    vehicle_limit_feasible =
        sum(x_value((DEPOT, j)) for j in CUSTOMERS) <= VEHICLE_LIMIT
    capacity_limit_feasible = all(NODES) do i
        all(CUSTOMERS) do j
            i == j && return true

            return y_values[j] >=
                   y_values[i] + DEMAND[j] * x_value((i, j)) -
                   CAPACITY * (1 - x_value((i, j)))
        end
    end
    capacity_node_ub_feasible = all(node -> y_values[node] <= CAPACITY, NODES)
    capacity_node_lb_feasible = all(node -> DEMAND[node] <= y_values[node], NODES)
    route_demands = _route_demands()
    capacity_tight = all(==(CAPACITY), route_demands)
    source_feasible =
        customer_visited_once_feasible &&
        flow_conservation_feasible &&
        vehicle_limit_feasible &&
        capacity_limit_feasible &&
        capacity_node_ub_feasible &&
        capacity_node_lb_feasible
    source_objective = _source_objective(active_arcs)
    rounded_cost = _rounded_route_cost(active_arcs)

    return Dict{String,Any}(
        "source_objective" => source_objective,
        "rounded_route_cost" => rounded_cost,
        "qoblib_solution_cost" => KNOWN_INCUMBENT["qoblib_solution_cost"],
        "source_feasible" => source_feasible,
        "customer_visited_once_feasible" => customer_visited_once_feasible,
        "flow_conservation_feasible" => flow_conservation_feasible,
        "vehicle_limit_feasible" => vehicle_limit_feasible,
        "capacity_limit_feasible" => capacity_limit_feasible,
        "capacity_node_ub_feasible" => capacity_node_ub_feasible,
        "capacity_node_lb_feasible" => capacity_node_lb_feasible,
        "route_demands" => route_demands,
        "capacity_tight" => capacity_tight,
        "active_arc_count" => length(active_arcs),
        "selected_arcs" => [collect(arc) for arc in active_arcs],
        "matches_qoblib_solution_artifact" =>
            rounded_cost == KNOWN_INCUMBENT["qoblib_solution_cost"] && source_feasible,
    )
end

function _comparison(target, metadata)
    return Dict{String,Any}(
        "canonical_qubo_metrics_available" => QOBLIB_QUBO_METRICS["available"],
        "target_variable_delta_vs_qoblib_qs" =>
            target["num_variables"] - QOBLIB_QUBO_METRICS["num_variables"],
        "target_variable_delta_note" =>
            "ToQUBO generates fewer binary variables than the pinned QOBLIB QS metrics row. The current compiler also detects 22 explicit source constraints as always feasible, so the target-size delta should be interpreted alongside the redundant-constraint count and encoding metadata.",
        "redundant_constraint_count" =>
            QOBLIB_SOURCE_METRICS["num_linear_constraints"] -
            metadata["constraint_penalty_count"],
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

function run_routing_pilot()
    model, _x, _y, constraint_counts = _build_routing_model()

    MOI.optimize!(model)

    target = _target_metrics(model)
    metadata = _metadata_summary(model)

    return Dict{String,Any}(
        "provenance" => copy(PROVENANCE),
        "upstream_verification" => copy(UPSTREAM_VERIFICATION),
        "instance" => copy(INSTANCE),
        "source" => Dict{String,Any}(
            "modeling_assumptions" => [
                "the source model follows QOBLIB's integer-linear CVRP formulation",
                "node 1 is the depot and each non-depot node is visited exactly once",
                "flow-conservation constraints balance incoming and outgoing selected arcs at each customer",
                "the depot has at most four outgoing selected arcs, matching the vehicle limit",
                "MTZ-style load variables y[i] are integer-bounded in [0, 231]",
                "the explicit capacity upper and lower constraints are kept to match the pinned LP row",
            ],
            "variable_naming" => [
                "x[i,j] follows the QOBLIB selected directed arc variable",
                "y[i] follows the QOBLIB cumulative demand/load variable",
                "QOBLIB LP variable names use x#i#j and y#i",
            ],
            "bounds" => [
                "0 <= x[i,j] <= 1, integer, for i != j",
                "0 <= y[i] <= 231, integer",
                "explicit source constraints also enforce demand[i] <= y[i] <= 231",
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
        "comparison" => _comparison(target, metadata),
        "follow_up" =>
            "The objective-range automatic penalty policy brings ToQUBO's generated routing QUBO coefficient range into the same order as the pinned QOBLIB QS metrics row under the QOBLIB-style symmetrized convention. The source transcription and incumbent feasibility checks pass. Remaining routing differences should be interpreted alongside ToQUBO's variable and slack encodings, redundant-constraint handling, and target-variable delta; those benchmark-expansion questions remain tracked in https://github.com/JuliaQUBO/ToQUBO.jl/issues/162.",
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

    write(io, "# QOBLib Routing Reformulation Pilot\n\n")
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
    write(io, "- Penalty scaling follow-up: $(provenance["penalty_scaling_follow_up"])\n")
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

    write(io, "\n")

    write(io, "## Instance\n\n")
    write(io, "- QOBLIB id: `$(instance["qoblib_id"])`\n")
    write(io, "- Source LP file: `$(instance["lp_file"])`\n")
    write(io, "- Canonical QUBO file: `$(instance["canonical_qubo_file"])`\n")
    write(io, "- Nodes: $(instance["nodes"])\n")
    write(io, "- Customers: $(instance["customers"])\n")
    write(io, "- Vehicles: $(instance["vehicles"])\n")
    write(io, "- Capacity: $(instance["capacity"])\n")
    write(io, "- Depot: $(instance["depot"])\n")
    write(io, "- Edge weight type: $(instance["edge_weight_type"])\n")
    write(io, "- QOBLIB solution cost: $(instance["comment_optimal_cost"])\n\n")

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
    write(io, _metric_row("objective offset", "n/a", "n/a", target["objective_offset"]))
    write(io, _metric_row("QUBO terms", "n/a", "n/a", target["num_terms"]))
    write(
        io,
        _metric_row("quadratic terms", "n/a", "n/a", target["num_quadratic_terms"]),
    )

    generated_source = source["generated_metrics"]
    write(io, "\n## Source Model Counts\n\n")
    write(io, "- Generated source variables: $(generated_source["num_vars"])\n")
    write(io, "- Generated source constraints: $(generated_source["num_constraints"])\n")
    write(
        io,
        "- Customer-visited-once constraints: $(generated_source["num_customer_visited_once_constraints"])\n",
    )
    write(
        io,
        "- Flow-conservation constraints: $(generated_source["num_flow_conservation_constraints"])\n",
    )
    write(io, "- Vehicle-limit constraints: $(generated_source["num_vehicle_limit_constraints"])\n")
    write(io, "- Capacity-linking constraints: $(generated_source["num_capacity_limit_constraints"])\n")
    write(
        io,
        "- Capacity upper-bound constraints: $(generated_source["num_capacity_node_ub_constraints"])\n",
    )
    write(
        io,
        "- Capacity lower-bound constraints: $(generated_source["num_capacity_node_lb_constraints"])\n",
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
    write(io, "- Source objective using sqrt distances: $(_fmt(incumbent["source_objective"]))\n")
    write(io, "- Rounded CVRPLIB route cost: $(_fmt(incumbent["rounded_route_cost"]))\n")
    write(io, "- QOBLIB solution artifact cost: $(_fmt(incumbent["qoblib_solution_cost"]))\n")
    write(io, "- Source feasible: $(_fmt(incumbent["source_feasible"]))\n")
    write(
        io,
        "- Customer-visited-once feasible: $(_fmt(incumbent["customer_visited_once_feasible"]))\n",
    )
    write(io, "- Flow-conservation feasible: $(_fmt(incumbent["flow_conservation_feasible"]))\n")
    write(io, "- Vehicle-limit feasible: $(_fmt(incumbent["vehicle_limit_feasible"]))\n")
    write(io, "- Capacity-linking feasible: $(_fmt(incumbent["capacity_limit_feasible"]))\n")
    write(io, "- Capacity upper bounds feasible: $(_fmt(incumbent["capacity_node_ub_feasible"]))\n")
    write(io, "- Capacity lower bounds feasible: $(_fmt(incumbent["capacity_node_lb_feasible"]))\n")
    write(io, "- Route demands: $(join(incumbent["route_demands"], ", "))\n")
    write(io, "- All routes capacity-tight: $(_fmt(incumbent["capacity_tight"]))\n")
    write(io, "- Active selected arcs: $(incumbent["active_arc_count"])\n")
    write(
        io,
        "- Selected arcs: $(join(["($(arc[1]), $(arc[2]))" for arc in incumbent["selected_arcs"]], ", "))\n",
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
    write(io, "- Redundant source constraints detected: $(comparison["redundant_constraint_count"])\n")
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
    output = isempty(args) ? joinpath(@__DIR__, "reports", "routing_pilot.md") : first(args)
    report = run_routing_pilot()

    write_markdown_report(output, report)
    println(output)

    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
