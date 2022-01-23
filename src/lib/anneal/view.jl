# module AnnealView

using RecipesBase

@recipe function f(set::SampleSet)

    fillcolor := :black
    fillalpha := 0.3
    linealpha := 0.3
    seriestype := :histogram

    x = [sample.energy for sample in set]
    y = [sample.amount for sample in set]
    x, y
end

# end # module
