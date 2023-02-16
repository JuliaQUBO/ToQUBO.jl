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
        "Manual" => [
            "Getting Started"   => "manual/1-start.md",
            "Running a Model"   => "manual/2-model.md",
            "Gathering Results" => "manual/3-results.md",
            "Compiler Settings" => "manual/4-settings.md",
        ],
        "Examples" => [
            "Knapsack" =>"examples/knapsack.md",
            "Prime Factorization" => "examples/prime_factorization.md",
        ],
        "Booklet" => [
            "Introduction"    => "booklet/1-intro.md",
            "QUBO"            => "booklet/2-qubo.md",
            "PBO"             => "booklet/3-pbo.md",
            "Encoding"        => "booklet/4-encoding.md",
            "Virtual Mapping" => "booklet/5-virtual.md",
            "Solvers"         => "booklet/6-solvers.md",
        ]
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