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
    authors="Pedro Xavier and Tiago Andrade and Joaquim Garcia and David Bernal",
    pages=[
        "Home" => "index.md",
        "Manual" => "manual.md",
        "Examples" => [
            "Knapsack" =>"examples/knapsack.md",
            "Prime Factorization" => "examples/prime_factorization.md",
        ],
        "Booklet" => "booklet.md"
    ],
    workdir="."
)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploydocs(
        repo=raw"github.com/psrenergy/ToQUBO.jl.git",
        push_preview = true
    )
end