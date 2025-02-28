import PowerModels

"""
"""
function test_opf(; path=joinpath(@__DIR__, "opf.m"), optimizer = nothing)
    power_model = PowerModels.instantiate_model(path, PowerModels.ACRPowerModel, PowerModels.build_opf)
        
    JuMP.set_optimizer(power_model.model, () -> ToQUBO.Optimizer(optimizer))

    JuMP.optimize!(power_model.model)

    return power_model.model

    # #set_attribute(model, ToQUBO.Attributes.Discretize(), true)

    # #=set_attribute.(
    #     JuMP.all_constraints(model; include_variable_in_set_constraints = false),
    #     ToQUBO.Attributes.ConstraintEncodingPenaltyHint(),
    #     500
    # )=#

    # optimize!(model)
end