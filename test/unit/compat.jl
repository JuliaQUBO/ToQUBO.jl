function test_compat()
    @testset "Compatibility and CI" begin
        root = normpath(joinpath(@__DIR__, "..", ".."))
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        compat = project["compat"]

        @test compat["julia"] == "1.10"
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", compat["QUBOTools"])

        ci = replace(
            read(joinpath(root, ".github", "workflows", "ci.yml"), String),
            "\r\n" => "\n",
        )
        docs = replace(
            read(joinpath(root, ".github", "workflows", "documentation.yml"), String),
            "\r\n" => "\n",
        )

        @test occursin(r"(?m)^\s*-\s*version:\s*'1\.10'\s*$", ci)
        @test occursin(r"(?m)^\s*-\s*version:\s*'1'\s*$", ci)
        @test occursin(r"(?m)^\s*version:\s*'1'\s*$", docs)
        @test !occursin(r"(?m)^\s*version:\s*'1\.9'\s*$", docs)
    end

    return nothing
end
