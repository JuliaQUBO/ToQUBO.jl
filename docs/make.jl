using Documenter
using ToQUBO

# Set up to run docstrings with jldoctest
DocMeta.setdocmeta!(
    ToQUBO, :DocTestSetup, :(using ToQUBO); recursive=true
)

makedocs(;
    modules=[ToQUBO],
    doctest=true,
    clean=true,
    format=Documenter.HTML(
        assets = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine=Documenter.MathJax2(),
        sidebar_sitename=false,
    ),
    sitename="ToQUBO.jl",
    authors="Pedro Xavier, Tiago Andrade, and Joaquim Garcia",
    pages=[
        "Home" => "index.md",
        "manual.md",
        "examples.md",
    ],
)

deploydocs(
        repo=raw"https://github.com/psrenergy/ToQUBO.jl.git",
        push_preview = true
    )