#!/usr/bin/env julia

using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))

function release_line_compat(version::VersionNumber)
    if version.major == 0
        return version.minor == 0 ? "0.0.$(version.patch)" : "0.$(version.minor)"
    end

    return string(version.major)
end

function check!(failures::Vector{String}, condition::Bool, message::String)
    condition || push!(failures, message)
    return nothing
end

function project_file(parts...)
    return joinpath(ROOT, parts...)
end

function read_toml(parts...)
    return TOML.parsefile(project_file(parts...))
end

function release_section(news::String, version::VersionNumber)
    heading = "## v$(version) - "
    lines = split(news, '\n')
    start = findfirst(line -> startswith(line, heading), lines)
    start === nothing && return nothing

    next_heading = findnext(line -> startswith(line, "## "), lines, start + 1)
    stop = next_heading === nothing ? lastindex(lines) : next_heading - 1
    return join(lines[start:stop], "\n")
end

function main()
    failures = String[]
    warnings = String[]

    project = read_toml("Project.toml")
    docs_project = read_toml("docs", "Project.toml")
    test_project = read_toml("test", "Project.toml")

    version = VersionNumber(project["version"])
    expected_self_compat = release_line_compat(version)

    check!(failures, project["name"] == "ToQUBO", "Project.toml name is not ToQUBO.")

    docs_deps = docs_project["deps"]
    docs_compat = docs_project["compat"]
    test_compat = test_project["compat"]
    project_compat = project["compat"]

    check!(
        failures,
        get(docs_deps, "ToQUBO", nothing) == project["uuid"],
        "docs/Project.toml must depend on this package UUID for ToQUBO.",
    )
    check!(
        failures,
        get(docs_compat, "ToQUBO", nothing) == expected_self_compat,
        "docs/Project.toml compat for ToQUBO must be \"$expected_self_compat\" for version $version.",
    )
    check!(
        failures,
        get(docs_compat, "julia", nothing) == project_compat["julia"],
        "docs/Project.toml Julia compat must match Project.toml.",
    )
    check!(
        failures,
        get(test_compat, "julia", nothing) == project_compat["julia"],
        "test/Project.toml Julia compat must match Project.toml.",
    )
    check!(
        failures,
        get(test_compat, "QUBOTools", nothing) == project_compat["QUBOTools"],
        "test/Project.toml QUBOTools compat must match Project.toml.",
    )

    news = read(project_file("NEWS.md"), String)
    section = release_section(news, version)
    check!(
        failures,
        section !== nothing,
        "NEWS.md must contain a release heading like `## v$(version) - YYYY-MM-DD`.",
    )

    if section !== nothing && !occursin(r"(?i)\b(breaking|changelog)\b", section)
        push!(
            warnings,
            "NEWS.md section for v$version does not mention `breaking` or `changelog`; General AutoMerge may require one of those words if the registry labels the release BREAKING.",
        )
    end

    if isempty(failures)
        println("Release preflight passed for ToQUBO v$version.")
        println("Expected docs self-compat: ToQUBO = \"$expected_self_compat\".")
    else
        println(stderr, "Release preflight failed:")
        foreach(message -> println(stderr, "- ", message), failures)
    end

    if !isempty(warnings)
        println(stderr, "\nWarnings:")
        foreach(message -> println(stderr, "- ", message), warnings)
    end

    return isempty(failures) ? 0 : 1
end

exit(main())
