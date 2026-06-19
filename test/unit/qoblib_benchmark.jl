include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "birkhoff_pilot.jl"))
include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "steiner_pilot.jl"))

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
    end

    return nothing
end
