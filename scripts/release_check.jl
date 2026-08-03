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

compat_entries(value::AbstractString) = Set(strip.(split(value, ',')))

function release_section(news::String, version::VersionNumber)
    heading = "## v$(version) - "
    lines = split(news, '\n')
    start = findfirst(line -> startswith(line, heading), lines)
    start === nothing && return nothing

    next_heading = findnext(line -> startswith(line, "## "), lines, start + 1)
    stop = next_heading === nothing ? lastindex(lines) : next_heading - 1
    return join(lines[start:stop], "\n")
end

function release_date(news::String, version::VersionNumber)
    heading = "## v$(version) - "
    line = findfirst(line -> startswith(line, heading), split(news, '\n'))
    line === nothing && return nothing

    heading_line = split(news, '\n')[line]
    return strip(replace(heading_line, heading => ""; count = 1))
end

function marked_section(document::String, start_marker::String, end_marker::String)
    start_parts = split(document, start_marker; limit = 2)
    length(start_parts) == 2 || return nothing

    end_parts = split(start_parts[2], end_marker; limit = 2)
    length(end_parts) == 2 || return nothing

    return strip(end_parts[1])
end

function quoted_cff_value(citation::String, key::String)
    result = match(Regex("(?m)^$(key):\\s*\"([^\"]+)\"\\s*\$"), citation)
    return result === nothing ? nothing : only(result.captures)
end

function cff_version_doi(citation::String)
    result = match(
        r"(?ms)value:\s*\"(10\.5281/zenodo\.\d+)\"\s*\n\s*description:\s*\"Zenodo DOI for version",
        citation,
    )
    return result === nothing ? nothing : only(result.captures)
end

function preferred_citation_title(citation::String)
    parts = split(citation, "preferred-citation:"; limit = 2)
    length(parts) == 2 || return nothing

    result = match(r"(?m)^\s+title:\s*\"([^\"]+)\"\s*$", parts[2])
    return result === nothing ? nothing : only(result.captures)
end

function bibtex_entry(bib::AbstractString, entry_type::AbstractString)
    result = match(Regex("(?ms)^@$(entry_type)\\{.*?^\\}"), bib)
    return result === nothing ? nothing : result.match
end

function bibtex_field(entry::AbstractString, field::AbstractString)
    result = match(Regex("(?m)^\\s*$(field)\\s*=\\s*\\{(.*)\\},?\\s*\$"), entry)
    return result === nothing ? nothing : strip(only(result.captures))
end

function bibtex_block(section::AbstractString)
    result = match(r"(?ms)```bibtex\s*\n(.*?)\n```", section)
    return result === nothing ? nothing : strip(only(result.captures))
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
        issubset(
            compat_entries(test_compat["QUBOTools"]),
            compat_entries(project_compat["QUBOTools"]),
        ),
        "test/Project.toml QUBOTools compat must be supported by Project.toml.",
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

    citation = read(project_file("CITATION.cff"), String)
    citation_bib = strip(read(project_file("CITATION.bib"), String))
    readme = read(project_file("README.md"), String)
    docs_index = read(project_file("docs", "src", "index.md"), String)
    release_docs = read(project_file("docs", "dev", "release.md"), String)

    concept_doi = "10.5281/zenodo.21763525"
    historical_concept_doi = "10.5281/zenodo.6387591"
    obsolete_version_doi = "10.5281/zenodo.7644291"
    article_doi = "10.1080/10556788.2026.2702926"
    version_doi = cff_version_doi(citation)
    news_date = release_date(news, version)

    check!(
        failures,
        quoted_cff_value(citation, "version") == string(version),
        "CITATION.cff version must match Project.toml version $version.",
    )
    check!(
        failures,
        quoted_cff_value(citation, "doi") == concept_doi,
        "CITATION.cff must use the successor concept DOI $concept_doi as its evergreen DOI.",
    )
    check!(
        failures,
        news_date !== nothing && occursin("date-released: $news_date", citation),
        "CITATION.cff date-released must match the NEWS.md date for v$version.",
    )
    check!(
        failures,
        version_doi !== nothing && version_doi != concept_doi,
        "CITATION.cff must identify a distinct Zenodo version DOI.",
    )
    check!(
        failures,
        occursin("description: \"Zenodo DOI for version $version\"", citation),
        "CITATION.cff version DOI description must match Project.toml version $version.",
    )
    check!(
        failures,
        occursin(article_doi, citation),
        "CITATION.cff preferred citation must identify the published QUBO.jl article.",
    )

    article_title = preferred_citation_title(citation)
    check!(
        failures,
        article_title !== nothing && occursin(article_title, citation_bib),
        "CITATION.bib must spell the article title exactly as CITATION.cff preferred-citation does.",
    )

    article_entry = bibtex_entry(citation_bib, "article")
    software_entry = bibtex_entry(citation_bib, "software")

    for (entry, label, doi) in (
        (article_entry, "@article", article_doi),
        (software_entry, "@software", version_doi),
    )
        check!(
            failures,
            entry !== nothing && doi !== nothing && bibtex_field(entry, "doi") == doi,
            "The CITATION.bib $label entry must set doi = {$doi}.",
        )
        check!(
            failures,
            entry !== nothing && doi !== nothing &&
                bibtex_field(entry, "url") == "https://doi.org/$doi",
            "The CITATION.bib $label entry must set url = {https://doi.org/$doi}.",
        )
    end

    check!(
        failures,
        software_entry !== nothing && occursin(concept_doi, software_entry),
        "The CITATION.bib @software entry must name the evergreen concept DOI $concept_doi.",
    )

    citation_start = "<!-- citation-policy:start -->"
    citation_end = "<!-- citation-policy:end -->"
    readme_citation = marked_section(readme, citation_start, citation_end)
    docs_citation = marked_section(docs_index, citation_start, citation_end)

    check!(
        failures,
        readme_citation !== nothing && readme_citation == docs_citation,
        "README.md and docs/src/index.md citation sections must remain synchronized.",
    )

    if readme_citation !== nothing
        check!(
            failures,
            bibtex_block(readme_citation) == citation_bib,
            "The README/docs BibTeX example must match CITATION.bib.",
        )
        for doi in (concept_doi, historical_concept_doi, article_doi)
            check!(
                failures,
                occursin(doi, readme_citation),
                "The synchronized citation section must document DOI $doi.",
            )
        end
        check!(
            failures,
            version_doi !== nothing && occursin(version_doi, readme_citation),
            "The synchronized citation section must document the current version DOI.",
        )
        check!(
            failures,
            occursin("`v$version`", readme_citation),
            "The synchronized citation section must name current version v$version.",
        )
    end

    maintained_citations = join((citation, citation_bib, readme, docs_index), "\n")
    check!(
        failures,
        !occursin(obsolete_version_doi, maintained_citations),
        "Historical version DOI $obsolete_version_doi must not be used by maintained citation metadata.",
    )
    check!(
        failures,
        occursin("new version", lowercase(release_docs)) && occursin(concept_doi, release_docs),
        "Release documentation must say to create a new version under concept DOI $concept_doi.",
    )

    if isempty(failures)
        println("Release preflight passed for ToQUBO v$version.")
        println("Expected docs self-compat: ToQUBO = \"$expected_self_compat\".")
        println("Citation concept DOI: $concept_doi.")
        println("Citation version DOI: $version_doi.")
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
