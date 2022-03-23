using Documenter
using Pkg
Pkg.develop(path=joinpath(@__DIR__, ".."))
Pkg.develop(path=joinpath(@__DIR__, "..", "src", "Anneal.jl"))
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
    authors="Pedro Xavier and Tiago Andrade and Joaquim Garcia and David Bernal",
    pages=[
        "Home" => "index.md",
        "manual.md",
        "examples.md",
        "Booklet" => "booklet.md"
    ],
    workdir="."
)

deploydocs(
    repo=raw"github.com/psrenergy/ToQUBO.jl.git",
    push_preview = true
)