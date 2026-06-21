include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "birkhoff_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "steiner_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "sports_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "network_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "routing_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "topology_pilot.jl"))

function _normalized_file(path)
    return replace(read(path, String), "\r\n" => "\n")
end

function test_qoblib_benchmark_pilot()
    @testset "QOBLib benchmark pilot" begin
        report = QOBLibBirkhoffPilot.run_birkhoff_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["source_instance_json_key"] == "1"
        @test report["provenance"]["coefficient_gap_follow_up"] ==
              "https://github.com/JuliaQUBO/ToQUBO.jl/issues/148"

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 12
        @test source["qoblib_metrics"]["num_linear_constraints"] == 16

        target = report["toqubo"]["target"]
        @test target["num_variables"] == report["qoblib_qubo_metrics"]["num_variables"]
        @test target["num_terms"] > 0
        @test target["num_quadratic_terms"] > 0
        @test target["density"] > 0
        @test target["max_coeff"] == 8_762_880.0
        @test target["qoblib_symmetric_min_coeff"] ==
              report["qoblib_qubo_metrics"]["min_coeff"]
        @test target["qoblib_symmetric_max_coeff"] ==
              report["qoblib_qubo_metrics"]["max_coeff"]
        @test Set(Tuple(term["variables"]) for term in target["native_max_coeff_terms"]) ==
              Set([(29, 30), (59, 60)])

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 12
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["constraint_penalty_count"] > 0
        @test !isempty(metadata["encoding_types"])

        comparison = report["comparison"]
        @test comparison["max_coeff_delta_vs_qoblib_qs"] == 1_762_879.0
        @test comparison["qoblib_symmetric_min_coeff_delta_vs_qoblib_qs"] == 0.0
        @test comparison["qoblib_symmetric_max_coeff_delta_vs_qoblib_qs"] == 0.0

        attribution = report["coefficient_attribution"]
        @test attribution["upstream_evidence"]["canonical_artifact_available_at_commit"] ===
              false
        @test attribution["upstream_evidence"]["manual_verification"] === true
        @test attribution["upstream_evidence"]["metrics_line_ref"] ==
              "03-birkhoff/models/integer_linear/metrics_qs_files.csv:42"
        @test attribution["source_lp_comparison"]["matches_qoblib_lp_after_column_renaming"] ===
              true
        @test attribution["source_lp_comparison"]["manual_verification"] === true
        @test attribution["constraint_penalties"] == [7.0]
        @test attribution["penalty"] == 7.0
        @test attribution["ownership_decision"] == "documentation-only"
        @test length(attribution["native_max_terms"]) == 2
        @test all(
            term -> term["qoblib_symmetric_coefficient"] == 4_381_440.0,
            attribution["native_max_terms"],
        )
        @test all(
            term -> term["native_coefficient"] == 7_000_001.0,
            attribution["qoblib_symmetric_max_terms"],
        )

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 2
        @test incumbent["source_feasible"] === true
        @test incumbent["matches_qoblib_solution_record"] === true

        io = IOBuffer()
        QOBLibBirkhoffPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "birkhoff_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Birkhoff Reformulation Pilot", markdown)
        @test occursin("bhS-03-001.lp", markdown)
        @test occursin("Coefficient Range Attribution", markdown)
        @test occursin("Upstream verification", markdown)
        @test occursin("documentation-only", markdown)
        @test markdown == _normalized_file(report_path)

        report = QOBLibSteinerPilot.run_steiner_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["qoblib_class"] == "04-steiner"
        @test report["provenance"]["canonical_qubo_metrics_available"] === false
        @test report["provenance"]["source_solution_path"] ==
              "04-steiner/instances/stp_s003_l1_t2_h0_rs97531/sol.txt"
        @test report["instance"]["qoblib_id"] == "stp_s003_l1_t2_h0_rs97531"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test verification["metrics_line_ref"] ==
              "04-steiner/models/integer_linear/lp_files/metrics.csv:2"
        @test "04-steiner/instances/stp_s003_l1_t2_h0_rs97531/arcs.dat:11-34" in
              verification["instance_line_refs"]
        @test "04-steiner/instances/stp_s003_l1_t2_h0_rs97531/sol.txt:4-7" in
              verification["solution_line_refs"]

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 48
        @test source["generated_metrics"]["num_linear_constraints"] == 44
        @test source["generated_metrics"]["num_binding_constraints"] == 24
        @test source["qoblib_metrics"]["density"] == 0.056818181818181816

        target = report["toqubo"]["target"]
        @test target["num_variables"] == 80
        @test target["num_terms"] == 289
        @test target["num_quadratic_terms"] == 209
        @test target["density"] == 0.08919753086419753
        @test target["min_coeff"] == -100.0
        @test target["max_coeff"] == 75.0
        @test target["objective_offset"] == 250.0

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 48
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["slack_variable_count"] == 32
        @test metadata["constraint_penalty_count"] == 44
        @test metadata["constraint_penalties"] == [25.0]
        @test metadata["encoding_types"] == ["Binary"]

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === false
        @test comparison["target_variables_minus_source_integer_vars"] == 32

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 4
        @test incumbent["source_feasible"] === true
        @test incumbent["flow_feasible"] === true
        @test incumbent["disjointness_feasible"] === true
        @test incumbent["binding_feasible"] === true
        @test incumbent["qoblib_solution_cost"] == 4
        @test incumbent["active_flow_arcs"] == incumbent["active_selected_arcs"]
        @test incumbent["matches_qoblib_solution_artifact"] === true

        io = IOBuffer()
        QOBLibSteinerPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "steiner_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Steiner Reformulation Pilot", markdown)
        @test occursin("stp_s003_l1_t2_h0_rs97531.lp", markdown)
        @test occursin("Upstream Verification", markdown)
        @test occursin("sol.txt:4-7", markdown)
        @test occursin("Canonical QUBO metrics available for this instance: false", markdown)
        @test occursin("Distinct constraint penalties: 25.0", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)

        report = QOBLibSportsPilot.run_sports_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["qoblib_class"] == "05-sports"
        @test report["provenance"]["source_instance_path"] ==
              "05-sports/instances/Small/Addition_000_Small.xml.gz"
        @test report["provenance"]["canonical_qubo_metrics_csv_row"] ==
              "Addition_000_Small.qs,1737,0.12329035750036603,-497.0,88.0"
        @test report["instance"]["qoblib_id"] == "Addition_000_Small"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test "05-sports/instances/Small/Addition_000_Small.xml.gz:73-159" in
              verification["instance_line_refs"]
        @test "05-sports/misc/itc2mip.py:334-399" in
              verification["converter_line_refs"]

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 992
        @test source["generated_metrics"]["num_linear_constraints"] == 587
        @test source["generated_metrics"]["num_capacity_constraints"] == 85
        @test source["generated_metrics"]["num_game_constraints"] == 41
        @test source["generated_metrics"]["num_break_limit_constraints"] == 43
        @test source["qoblib_metrics"]["density"] == 0.027009946694510085

        target = report["toqubo"]["target"]
        @test target["num_variables"] == 1733
        @test target["num_terms"] == 186093
        @test target["num_quadratic_terms"] == 184360
        @test target["density"] == 0.12385466728696162
        @test target["min_coeff"] == -497.0
        @test target["max_coeff"] == 176.0
        @test target["qoblib_symmetric_min_coeff"] ==
              report["qoblib_qubo_metrics"]["min_coeff"]
        @test target["qoblib_symmetric_max_coeff"] ==
              report["qoblib_qubo_metrics"]["max_coeff"]
        @test target["objective_offset"] == 6084.0

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 992
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["slack_variable_count"] == 344
        @test metadata["constraint_penalty_count"] == 583
        @test metadata["constraint_penalties"] == [1.0]
        @test metadata["encoding_types"] == ["Binary"]

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === true
        @test comparison["target_variable_delta_vs_qoblib_qs"] == -4
        @test comparison["redundant_constraint_count"] == 4
        @test comparison["qoblib_symmetric_min_coeff_delta_vs_qoblib_qs"] == 0.0
        @test comparison["qoblib_symmetric_max_coeff_delta_vs_qoblib_qs"] == 0.0

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 0
        @test incumbent["source_feasible"] === true
        @test incumbent["active_game_count"] == 56
        @test incumbent["home_break_count"] == 13
        @test incumbent["away_break_count"] == 13
        @test incumbent["matches_qoblib_solution_artifact"] === true

        io = IOBuffer()
        QOBLibSportsPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "sports_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Sports Reformulation Pilot", markdown)
        @test occursin("Addition_000_Small.lp", markdown)
        @test occursin("QOBLIB-style coefficient range", markdown)
        @test occursin("Redundant source constraints detected", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)

        report = QOBLibNetworkPilot.run_network_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["qoblib_class"] == "08-network"
        @test report["provenance"]["source_model_path"] ==
              "08-network/models/integer_lp/d3ver0int.zpl"
        @test report["provenance"]["qoblib_model_license"] ==
              "Apache License, Version 2.0"
        @test report["provenance"]["penalty_scaling_follow_up"] ==
              "https://github.com/JuliaQUBO/ToQUBO.jl/issues/160"
        @test report["provenance"]["canonical_qubo_metrics_csv_row"] ==
              "network05.qs,3640,0.05271012974940467,-4.75713475713e+17,4.5260616934376417e+18"
        @test report["instance"]["qoblib_id"] == "network05"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test "08-network/models/integer_lp/d3ver0int.zpl:66-84" in
              verification["model_line_refs"]
        @test "08-network/solutions/network05.opt.sol:24-103" in
              verification["solution_line_refs"]

        converter = report["qoblib_converter_evidence"]
        @test converter["manual_verification"] === true
        @test converter["converter_path"] == "misc/convert_lp2qubo.py"
        @test "misc/convert_lp2qubo.py:55-65" in converter["converter_line_refs"]
        @test occursin(
            "QuadraticProgramToQubo() using the converter default penalty",
            converter["converter_convention"],
        )
        @test converter["network_metrics_line_ref"] ==
              "08-network/models/integer_lp/metrics_qs_files.csv:2"
        @test converter["reproduction_environment"]["qiskit_optimization"] == "0.7.0"
        @test converter["reproduction_environment"]["gurobipy"] == "13.0.2"
        @test converter["reproduced_converter_penalty"] == 1_000_001.0
        reproduced = converter["reproduced_network05_metrics"]
        @test reproduced["num_variables"] == 3_640
        @test reproduced["nonzero_entries"] == 349_290
        @test reproduced["density"] == 0.05271012974940467
        @test reproduced["min_coeff"] == -4.75713475713e17
        @test reproduced["max_coeff"] == 4.5260616934376417e18
        @test occursin(
            "match the pinned metrics row exactly",
            converter["local_reproduction_note"],
        )

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 101
        @test source["generated_metrics"]["num_linear_constraints"] == 130
        @test source["generated_metrics"]["num_flow_balance_constraints"] == 20
        @test source["generated_metrics"]["num_arc_linking_constraints"] == 80
        @test source["generated_metrics"]["num_edge_capacity_constraints"] == 20
        @test source["qoblib_metrics"]["density"] == 0.03351104341203351

        target = report["toqubo"]["target"]
        @test target["num_variables"] == 3661
        @test target["num_terms"] == 350272
        @test target["num_quadratic_terms"] == 346611
        @test isapprox(target["density"], 0.05225373626178544; rtol = 1e-14)
        @test isapprox(target["min_coeff"], -2.3688802611453573e26; rtol = 1e-14)
        @test isapprox(target["max_coeff"], 2.3688762012720738e26; rtol = 1e-14)
        @test isapprox(target["objective_offset"], 2.737918134653359e23; rtol = 1e-14)

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 101
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["auxiliary_variable_count"] == 2021
        @test metadata["slack_variable_count"] == 100
        @test metadata["constraint_penalty_count"] == 130
        @test length(metadata["constraint_penalties"]) == 23
        @test metadata["encoding_types"] == ["Binary"]

        source_encoding = metadata["source_encoding"]
        @test source_encoding["z_binary_variables"] == 20
        @test source_encoding["selected_arc_binary_variables"] == 20
        @test source_encoding["flow_binary_variables"] == 1600
        @test source_encoding["z_and_flow_binary_variables"] == 1620
        @test source_encoding["encoded_source_binary_variables"] == 1640

        penalty_diagnostics = report["toqubo"]["penalty_diagnostics"]
        @test penalty_diagnostics["heuristic"] ==
              "scale * sigma * (delta / epsilon + beta)"
        @test penalty_diagnostics["default_penalty_scale"] == 1.0
        @test penalty_diagnostics["default_penalty_offset"] == 1.0
        @test penalty_diagnostics["largest_applied_penalty_family"] == "flow_balance"
        @test isapprox(
            penalty_diagnostics["largest_applied_penalty"],
            5.2338627500000094e14;
            rtol = 1e-14,
        )
        @test penalty_diagnostics["largest_expanded_residual_scale_family"] ==
              "flow_balance"
        family_by_category = Dict(
            family["category"] => family for
            family in penalty_diagnostics["constraint_families"]
        )
        @test family_by_category["flow_balance"]["constraint_count"] == 20
        @test family_by_category["flow_balance"]["distinct_penalty_count"] == 15
        @test isapprox(
            family_by_category["flow_balance"]["max_penalty"],
            penalty_diagnostics["largest_applied_penalty"];
            rtol = 1e-14,
        )
        @test family_by_category["flow_balance"]["max_source_coefficient"] == 1.0
        @test family_by_category["flow_balance"]["max_expanded_residual_coefficient"] ==
              475_713.0
        @test family_by_category["arc_linking"]["constraint_count"] == 80
        @test family_by_category["arc_linking"]["max_source_coefficient"] == 1.0e6
        @test family_by_category["edge_capacity"]["constraint_count"] == 20

        scaling_diagnostics = report["toqubo"]["scaling_diagnostics"]
        @test scaling_diagnostics["largest_expanded_residual_scale_family"] ==
              "flow_balance"
        @test scaling_diagnostics["largest_expanded_residual_coefficient"] == 475_713.0
        @test isapprox(
            scaling_diagnostics["largest_penalty_times_expanded_residual_coefficient_squared"],
            1.1844381006360369e26;
            rtol = 1e-14,
        )
        @test isapprox(
            scaling_diagnostics["qoblib_symmetric_to_canonical_abs_ratio"],
            2.624386183067761e7;
            rtol = 1e-14,
        )
        @test isapprox(
            scaling_diagnostics["qoblib_symmetric_min_to_canonical_min_abs_ratio"],
            2.4898183277180412e8;
            rtol = 1e-14,
        )
        @test occursin(
            "default automatic penalty heuristic",
            scaling_diagnostics["assessment"],
        )

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === true
        @test comparison["target_variable_delta_vs_qoblib_qs"] == 21
        @test occursin(
            "explicit bounded integer max-load variable z",
            comparison["target_variable_delta_note"],
        )
        @test isapprox(
            comparison["density_delta_vs_qoblib_qs"],
            -0.0004563934876192291;
            rtol = 1e-14,
        )

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 65_500
        @test incumbent["source_feasible"] === true
        @test incumbent["flow_balance_feasible"] === true
        @test incumbent["edge_capacity_feasible"] === true
        @test incumbent["positive_flow_count"] == 17
        @test incumbent["max_aggregate_edge_load"] == 65_500
        @test incumbent["matches_qoblib_solution_artifact"] === true

        io = IOBuffer()
        QOBLibNetworkPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "network_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Network Reformulation Pilot", markdown)
        @test occursin("network05.lp", markdown)
        @test occursin("Canonical QUBO artifact available at pinned commit: false", markdown)
        @test occursin("QOBLIB Converter Evidence", markdown)
        @test occursin("QuadraticProgramToQubo() using the converter default penalty", markdown)
        @test occursin("qiskit-optimization 0.7.0", markdown)
        @test occursin("Reproduced converter penalty: 1.000001e6", markdown)
        @test occursin("match the pinned metrics row exactly", markdown)
        @test occursin("Model license: Apache License, Version 2.0", markdown)
        @test occursin("Penalty scaling follow-up: https://github.com/JuliaQUBO/ToQUBO.jl/issues/160", markdown)
        @test occursin("Target variable delta note", markdown)
        @test occursin("Source Variable Encoding", markdown)
        @test occursin("z and flow target binary variables: 1620", markdown)
        @test occursin("Penalty Scaling Diagnostics", markdown)
        @test occursin("Largest applied penalty family: flow-balance", markdown)
        @test occursin("Largest expanded residual scale family: flow-balance", markdown)
        @test occursin("QOBLIB-style minimum-coefficient absolute ratio", markdown)
        @test occursin("Flow-balance constraints: 20", markdown)
        @test occursin("major coefficient-scaling gap", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)

        report = QOBLibRoutingPilot.run_routing_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["qoblib_class"] == "09-routing"
        @test report["provenance"]["source_model_path"] ==
              "09-routing/models/integer_linear/cvrp_ilp.zpl"
        @test report["provenance"]["qoblib_model_license"] ==
              "Apache License, Version 2.0"
        @test report["provenance"]["penalty_scaling_follow_up"] ==
              "https://github.com/JuliaQUBO/ToQUBO.jl/issues/162"
        @test report["provenance"]["canonical_qubo_metrics_csv_row"] ==
              "XSH-n20-k4-01.qs,4527,0.011716313817136443,-12874612219.171257,7397605618.245156"
        @test report["instance"]["qoblib_id"] == "XSH-n20-k4-01"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test "09-routing/models/integer_linear/cvrp_ilp.zpl:49-84" in
              verification["model_line_refs"]
        @test "09-routing/solutions/XSH-n20-k4-01.opt.sol:1-5" in
              verification["solution_line_refs"]

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 441
        @test source["generated_metrics"]["num_linear_constraints"] == 483
        @test source["generated_metrics"]["num_customer_visited_once_constraints"] == 20
        @test source["generated_metrics"]["num_flow_conservation_constraints"] == 20
        @test source["generated_metrics"]["num_capacity_limit_constraints"] == 400
        @test source["qoblib_metrics"]["density"] == 0.011558522649915729

        target = report["toqubo"]["target"]
        @test target["num_variables"] == 4351
        @test target["num_terms"] == 117882
        @test target["num_quadratic_terms"] == 113531
        @test isapprox(target["density"], 0.012450864912731353; rtol = 1e-14)
        @test isapprox(target["min_coeff"], -1.4036904381157936e13; rtol = 1e-14)
        @test isapprox(target["max_coeff"], 2.793883852788166e13; rtol = 1e-14)
        @test isapprox(
            target["qoblib_symmetric_min_coeff"],
            -1.4036904364404846e13;
            rtol = 1e-14,
        )
        @test isapprox(
            target["qoblib_symmetric_max_coeff"],
            1.5646506544178379e13;
            rtol = 1e-14,
        )
        @test isapprox(target["objective_offset"], 1.5412343291804879e13; rtol = 1e-14)

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 441
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["auxiliary_variable_count"] == 3763
        @test metadata["slack_variable_count"] == 421
        @test metadata["constraint_penalty_count"] == 461
        @test length(metadata["constraint_penalties"]) == 3
        @test metadata["encoding_types"] == ["Binary"]

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === true
        @test comparison["target_variable_delta_vs_qoblib_qs"] == -176
        @test comparison["redundant_constraint_count"] == 22
        @test occursin("fewer binary variables", comparison["target_variable_delta_note"])
        @test isapprox(
            comparison["density_delta_vs_qoblib_qs"],
            0.0007345510955949104;
            rtol = 1e-14,
        )

        incumbent = report["known_incumbent"]
        @test isapprox(incumbent["source_objective"], 646.6703590218194; rtol = 1e-14)
        @test incumbent["rounded_route_cost"] == 646.0
        @test incumbent["qoblib_solution_cost"] == 646
        @test incumbent["source_feasible"] === true
        @test incumbent["capacity_tight"] === true
        @test incumbent["active_arc_count"] == 24
        @test incumbent["matches_qoblib_solution_artifact"] === true

        io = IOBuffer()
        QOBLibRoutingPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "routing_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Routing Reformulation Pilot", markdown)
        @test occursin("XSH-n20-k4-01.lp", markdown)
        @test occursin("Canonical QUBO artifact available at pinned commit: false", markdown)
        @test occursin("Model license: Apache License, Version 2.0", markdown)
        @test occursin("Penalty scaling follow-up: https://github.com/JuliaQUBO/ToQUBO.jl/issues/162", markdown)
        @test occursin("Rounded CVRPLIB route cost", markdown)
        @test occursin("Redundant source constraints detected: 22", markdown)
        @test occursin("major coefficient-scaling gap", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)

        report = QOBLibTopologyPilot.run_topology_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"
        @test report["provenance"]["qoblib_class"] == "10-topology"
        @test report["provenance"]["source_model_path"] ==
              "10-topology/models/seidel_linear/topology_seidel_linear.zpl"
        @test report["provenance"]["qoblib_model_license"] ==
              "Apache License, Version 2.0"
        @test report["provenance"]["canonical_qubo_metrics_csv_row"] ==
              "topology_15_4.qs,4831,0.002770805545312352,-7.0,49.0"
        @test report["instance"]["qoblib_id"] == "topology_15_4"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test "10-topology/models/seidel_linear/topology_seidel_linear.zpl:30-44" in
              verification["model_line_refs"]
        @test "10-topology/instances/bounds.csv:3" in
              verification["instance_line_refs"]
        @test "10-topology/solutions/topology_15_4.opt.gph:4-33" in
              verification["solution_line_refs"]

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 1576
        @test source["generated_metrics"]["num_linear_constraints"] == 2955
        @test source["generated_metrics"]["num_diameter_constraints"] == 105
        @test source["generated_metrics"]["num_distance_calculation_constraints"] == 105
        @test source["generated_metrics"]["num_linearization_constraints"] == 2730
        @test source["generated_metrics"]["num_degree_constraints"] == 15
        @test source["qoblib_metrics"]["density"] == 0.0016233347934757401

        target = report["toqubo"]["target"]
        @test target["num_variables"] == 4830
        @test target["num_terms"] == 32340
        @test target["num_quadratic_terms"] == 27615
        @test isapprox(target["density"], 0.0027719528768010942; rtol = 1e-14)
        @test target["min_coeff"] == -14.0
        @test target["max_coeff"] == 56.0
        @test target["qoblib_symmetric_min_coeff"] ==
              report["qoblib_qubo_metrics"]["min_coeff"]
        @test target["qoblib_symmetric_max_coeff"] ==
              report["qoblib_qubo_metrics"]["max_coeff"]
        @test target["objective_offset"] == 347.0

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 1576
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["auxiliary_variable_count"] == 3255
        @test metadata["slack_variable_count"] == 2940
        @test metadata["constraint_penalty_count"] == 2955
        @test metadata["constraint_penalties"] == [1.0]
        @test metadata["encoding_types"] == ["Binary"]

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === true
        @test comparison["target_variable_delta_vs_qoblib_qs"] == -1
        @test isapprox(
            comparison["density_delta_vs_qoblib_qs"],
            1.1473314887422252e-6;
            rtol = 1e-14,
        )
        @test comparison["qoblib_symmetric_min_coeff_delta_vs_qoblib_qs"] == 0.0
        @test comparison["qoblib_symmetric_max_coeff_delta_vs_qoblib_qs"] == 0.0

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 2
        @test incumbent["source_feasible"] === true
        @test incumbent["degree_feasible"] === true
        @test incumbent["diameter_constraints_feasible"] === true
        @test incumbent["distance_calculation_feasible"] === true
        @test incumbent["linearization_feasible"] === true
        @test incumbent["max_shortest_path_distance"] == 2
        @test incumbent["selected_edge_count"] == 30
        @test incumbent["distance_zero_count"] == 30
        @test incumbent["distance_one_count"] == 105
        @test incumbent["linearization_active_count"] == 90
        @test incumbent["matches_qoblib_solution_artifact"] === true

        io = IOBuffer()
        QOBLibTopologyPilot.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "qoblib",
            "reports",
            "topology_pilot.md",
        )

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Topology Reformulation Pilot", markdown)
        @test occursin("topology_15_4.lp", markdown)
        @test occursin("Canonical QUBO artifact available at pinned commit: false", markdown)
        @test occursin("Model license: Apache License, Version 2.0", markdown)
        @test occursin("Diameter constraints: 105", markdown)
        @test occursin("QOBLIB-style maximum coefficient", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)
    end

    return nothing
end
