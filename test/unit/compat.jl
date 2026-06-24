function _release_line_compat(version::VersionNumber)
    if version.major == 0
        return version.minor == 0 ? "0.0.$(version.patch)" : "0.$(version.minor)"
    end

    return string(version.major)
end

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
        @test occursin(r"(^|,\s*)0\.2\.6(\s*(,|$))", compat["PseudoBooleanOptimization"])
        @test occursin(r"(^|,\s*)0\.3(\s*(,|$))", compat["PseudoBooleanOptimization"])
        @test occursin(r"(^|,\s*)0\.11(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.13(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.14(\s*(,|$))", compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.15(\s*(,|$))", compat["QUBOTools"])
        @test !haskey(docs_project["deps"], "PySA")
        @test !haskey(docs_compat, "PySA")
        @test occursin(r"(^|,\s*)0\.4(\s*(,|$))", docs_compat["QUBODrivers"])
        @test occursin(r"(^|,\s*)0\.6(\s*(,|$))", docs_compat["QUBODrivers"])
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", docs_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.15(\s*(,|$))", docs_compat["QUBOTools"])
        @test docs_compat["ToQUBO"] == _release_line_compat(VersionNumber(project["version"]))
        @test occursin(r"(^|,\s*)0\.2\.6(\s*(,|$))", test_compat["PseudoBooleanOptimization"])
        @test occursin(r"(^|,\s*)0\.3(\s*(,|$))", test_compat["PseudoBooleanOptimization"])
        @test occursin(r"(^|,\s*)0\.11(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.12(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.13(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.14(\s*(,|$))", test_compat["QUBOTools"])
        @test occursin(r"(^|,\s*)0\.15(\s*(,|$))", test_compat["QUBOTools"])

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
