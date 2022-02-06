# module AnnealView

using RecipesBase

@recipe function func(s::SampleSet)

    fillcolor := :black
    fillalpha := 0.3
    linealpha := 0.3
    seriestype := :histogram

    x = [sample.energy for sample in s]
    y = [sample.amount for sample in s]
    
    x, y
end

# end # module
