using Documenter
using SciMLLogging

# Copy project files if they exist
if isfile("Manifest.toml")
    cp("Manifest.toml", "src/assets/Manifest.toml", force = true)
end
if isfile("Project.toml")
    cp("Project.toml", "src/assets/Project.toml", force = true)
end

include("pages.jl")

makedocs(
    sitename = "SciMLLogging.jl",
    authors = "SciML",
    modules = [SciMLLogging],
    clean = true,
    doctest = false,
    linkcheck = true,
    checkdocs = :exports,
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
        canonical = "https://docs.sciml.ai/SciMLLogging/stable/",
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = pages
)

deploydocs(
    repo = "github.com/SciML/SciMLLogging.jl.git",
    devbranch = "main",
    push_preview = true
)