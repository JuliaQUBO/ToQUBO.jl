module Analysis
    using ToQUBO: VirtualQUBOModel, PBO

    function objective_function(model::VirtualQUBOModel)
        model.H
    end

    function qubo_normal_form(model::VirtualQUBOModel)
        PBO.qubo_normal_form(Array, objective_function(model))
    end

    function virtual_qubo_model(model)
        if model isa VirtualQUBOModel
            return model
        end
        
        if hasfield(typeof(model), :model)
            inner = virtual_qubo_model(model.model)

            if !isnothing(inner)
                return inner
            end
        end

        if hasfield(typeof(model), :optimizer)
            inner = virtual_qubo_model(model.optimizer)

            if !isnothing(inner)
                return inner
            end
        end

        return nothing
    end
end