function test_slack_resolution_docs()
    root = normpath(joinpath(@__DIR__, "..", ".."))
    settings = replace(
        read(joinpath(root, "docs", "src", "manual", "4-settings.md"), String),
        "\r\n" => "\n",
    )
    booklet = replace(
        read(joinpath(root, "docs", "src", "booklet", "4-encoding.md"), String),
        "\r\n" => "\n",
    )

    @testset "Slack-resolution guidance" begin
        @test occursin("### Slack Resolution and Penalty Contrast", settings)
        @test occursin("`Discretize(true)`", settings)
        @test occursin("`Discretize(false)`", settings)
        @test occursin("zero generated constraint penalty", settings)
        @test occursin("reformulation_metadata", settings)
        @test occursin("metadata[\"slack_variables\"]", settings)
        @test occursin("p_I - p_F", settings)
        @test occursin("no positive `rho`", settings)
        @test occursin("exact-model energy ordering", settings)
        @test occursin("finite-run sampler behavior", settings)
        @test occursin("does not currently relax a residual", settings)
        @test occursin("Slack-resolution penalty analysis", settings)
        @test occursin("[Slack Resolution and Penalty Contrast](@ref)", booklet)
    end

    return nothing
end
