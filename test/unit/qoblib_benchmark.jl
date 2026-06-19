include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "birkhoff_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "steiner_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "sports_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "network_pilot.jl"))

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
        @test report["provenance"]["canonical_qubo_metrics_csv_row"] ==
              "network05.qs,3640,0.05271012974940467,-4.75713475713e+17,4.5260616934376417e+18"
        @test report["instance"]["qoblib_id"] == "network05"

        verification = report["upstream_verification"]
        @test verification["manual_verification"] === true
        @test "08-network/models/integer_lp/d3ver0int.zpl:66-84" in
              verification["model_line_refs"]
        @test "08-network/solutions/network05.opt.sol:24-103" in
              verification["solution_line_refs"]

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

        comparison = report["comparison"]
        @test comparison["canonical_qubo_metrics_available"] === true
        @test comparison["target_variable_delta_vs_qoblib_qs"] == 21
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
        @test occursin("Flow-balance constraints: 20", markdown)
        @test occursin("QOBLIB solution artifact consistency check: pass", markdown)
        @test markdown == _normalized_file(report_path)
    end

    return nothing
end
