function setup!(model::Virtual.Model, ::AbstractArchitecture)
    # level = MOI.get(model, Attributes.Optimization())

    # if level >= 1
    #
    # [Control other settings here]
    #
    # end

    # Call setup callback
    let setup_callback! = get(model.compiler_settings, :setup_callback, identity)
        setup_callback!(model)
    end

    return nothing
end