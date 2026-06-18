include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "birkhoff_pilot.jl"))

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
        @test attribution["source_lp_comparison"]["matches_qoblib_lp_after_column_renaming"] ===
              true
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
        @test occursin("documentation-only", markdown)
        @test markdown == _normalized_file(report_path)
    end

    return nothing
end
