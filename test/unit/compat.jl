function test_compat()
    @testset "Compatibility and CI" begin
        root = normpath(joinpath(@__DIR__, "..", ".."))
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        docs_project = TOML.parsefile(joinpath(root, "docs", "Project.toml"))
        test_project = TOML.parsefile(joinpath(root, "test", "Project.toml"))
        compat = project["compat"]
        docs_compat = docs_project["compat"]
        test_compat = test_project["compat"]

        @test compat["julia"] == "1.10"
        @test occursin(r"(^|,\s*)0\.11(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.13(\s*(,|$))", compat["QUBOTools"])
        @test docs_compat["PySA"] == "0.3.4, 0.4"
        @test occursin(r"(^|,\s*)0\.4(\s*(,|$))", docs_compat["QUBODrivers"])
        @test occursin(r"(^|,\s*)0\.6(\s*(,|$))", docs_compat["QUBODrivers"])
        @test docs_compat["QUBOTools"] == "0.12, 0.13"
        @test docs_compat["ToQUBO"] == "0.4.1"
        @test occursin(r"(^|,\s*)0\.11(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.13(\s*(,|$))", test_compat["QUBOTools"])

        ci = replace(
            read(joinpath(root, ".github", "workflows", "ci.yml"), String),
            "\r\n" => "\n",
        )
        docs = replace(
            read(joinpath(root, ".github", "workflows", "documentation.yml"), String),
            "\r\n" => "\n",
        )
        dependabot = replace(
            read(joinpath(root, ".github", "dependabot.yml"), String),
            "\r\n" => "\n",
        )

        @test occursin(r"(?m)^\s*-\s*version:\s*'1\.10'\s*$", ci)
        @test occursin(r"(?m)^\s*-\s*version:\s*'1'\s*$", ci)
        @test occursin(r"(?m)^\s*version:\s*'1'\s*$", docs)
        @test !occursin(r"(?m)^\s*version:\s*'1\.9'\s*$", docs)
        @test occursin(
            """
              - package-ecosystem: "julia"
                directory: "/"
                schedule:
                  interval: "weekly"
            """,
            dependabot,
        )
        @test occursin(
            """
              - package-ecosystem: "julia"
                directory: "/docs"
                schedule:
                  interval: "weekly"
            """,
            dependabot,
        )
        @test occursin(
            """
              - package-ecosystem: "julia"
                directory: "/test"
                schedule:
                  interval: "weekly"
            """,
            dependabot,
        )
        @test occursin(
            """
              - package-ecosystem: "github-actions"
                directory: "/"
                schedule:
                  interval: "monthly"
            """,
            dependabot,
        )
    end

    return nothing
end
