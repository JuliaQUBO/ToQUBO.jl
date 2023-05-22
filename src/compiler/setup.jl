function setup!(model::VirtualModel, arch::AbstractArchitecture)
    level = MOI.get(model, Attributes.Optimization())

    if level >= 1
                
    end

    return nothing
end