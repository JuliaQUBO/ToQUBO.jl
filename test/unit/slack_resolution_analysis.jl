include(joinpath(@__DIR__, "..", "..", "benchmarks", "slack_resolution_analysis.jl"))

function test_slack_resolution_analysis()
    @testset "Slack-resolution analysis" begin
        @test SlackResolutionAnalysis.binary_grid_spacing(1.0, 2) ≈ 1 / 3
        @test_throws ArgumentError SlackResolutionAnalysis.binary_grid_spacing(1.0, 0)
        @test SlackResolutionAnalysis.maximum_squared_residual_floor(0.2) ≈ 0.01
        @test SlackResolutionAnalysis.required_penalty(1.0, 0.01, 0.05) ≈ 25.0
        @test isinf(SlackResolutionAnalysis.required_penalty(1.0, 0.05, 0.01))

        report = SlackResolutionAnalysis.run_analysis()
        rows = report.public_fixture

        @test length(rows) == 6
        @test [row.bits for row in rows] == collect(1:6)
        @test all(row.target_bits == row.bits for row in rows)
        @test all(row.grid_points == 2^row.bits for row in rows)
        @test all(row.feasible_floor <= row.maximum_floor + 1.0e-12 for row in rows)

        one_bit = rows[1]
        @test one_bit.feasible_floor ≈ 0.16
        @test one_bit.infeasible_penalty ≈ 0.04
        @test one_bit.contrast < 0
        @test isinf(one_bit.required_penalty)
        @test one_bit.inferred_prefers_feasible === false

        four_bits = rows[4]
        @test four_bits.feasible_floor ≈ 0.0 atol = 1.0e-12
        @test four_bits.required_penalty ≈ 25.0
        @test four_bits.inferred_prefers_feasible === true

        equality_families = Set(["level_select", "logic", "logic_t1"])
        equality_audit =
            filter(row -> row.family in equality_families, report.canonical_compilation)
        @test length(equality_audit) == 3
        @test all(row.slacks == 0 for row in equality_audit)
        @test all(
            row.integral == "yes" for row in report.canonical_compilation if row.slacks > 0
        )

        default =
            only(row for row in report.canonical_neal if row.configuration == "default")
        scaled = only(
            row for row in report.canonical_neal if row.configuration == "c2-c4 scale 400"
        )
        inequality_scaled = only(
            row for row in report.canonical_neal if
            row.configuration == "inequalities scale 400"
        )
        @test default.feasible_rate == 0.0
        @test scaled.feasible_rate == 0.00156
        @test scaled.level_select < default.level_select
        @test inequality_scaled.feasible_rate == 0.0

        io = IOBuffer()
        SlackResolutionAnalysis.write_markdown_report(io, report)
        markdown = replace(String(take!(io)), "\r\n" => "\n")
        report_path = joinpath(
            @__DIR__,
            "..",
            "..",
            "benchmarks",
            "reports",
            "slack_resolution_analysis.md",
        )
        committed = replace(read(report_path, String), "\r\n" => "\n")

        @test markdown == committed
        @test occursin("continuous-slack residual floor is absent model-wide", markdown)
        @test occursin("rho (p_I - p_F) > B", markdown)
        @test occursin("does not explain #205", markdown)
    end

    return nothing
end
