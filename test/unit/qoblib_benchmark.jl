include(joinpath(@__DIR__, "..", "..", "benchmarks", "qoblib", "birkhoff_pilot.jl"))

function test_qoblib_benchmark_pilot()
    @testset "QOBLib benchmark pilot" begin
        report = QOBLibBirkhoffPilot.run_birkhoff_pilot()

        @test report["provenance"]["canonical_qoblib_artifact"] === false
        @test report["provenance"]["collection"] ==
              "ToQUBO-generated reformulation benchmark"

        source = report["source"]
        @test source["generated_metrics"]["num_vars"] == 12
        @test source["qoblib_metrics"]["num_linear_constraints"] == 16

        target = report["toqubo"]["target"]
        @test target["num_variables"] == report["qoblib_qubo_metrics"]["num_variables"]
        @test target["num_terms"] > 0
        @test target["num_quadratic_terms"] > 0
        @test target["density"] > 0

        metadata = report["toqubo"]["metadata"]
        @test metadata["source_variable_count"] == 12
        @test metadata["target_variable_count"] == target["num_variables"]
        @test metadata["constraint_penalty_count"] > 0
        @test !isempty(metadata["encoding_types"])

        incumbent = report["known_incumbent"]
        @test incumbent["source_objective"] == 2
        @test incumbent["source_feasible"] === true
        @test incumbent["matches_qoblib_solution_record"] === true

        io = IOBuffer()
        QOBLibBirkhoffPilot.write_markdown_report(io, report)
        markdown = String(take!(io))

        @test occursin("not a canonical QOBLIB artifact", markdown)
        @test occursin("QOBLib Birkhoff Reformulation Pilot", markdown)
        @test occursin("bhS-03-001.lp", markdown)
    end

    return nothing
end
