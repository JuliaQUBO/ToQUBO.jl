function _json_compatible(value)
    if value === nothing ||
       value isa String ||
       value isa Bool ||
       value isa Integer
        return true
    elseif value isa AbstractFloat
        return isfinite(value)
    elseif value isa AbstractVector
        return all(_json_compatible, value)
    elseif value isa AbstractDict
        return all(key isa String && _json_compatible(val) for (key, val) in value)
    else
        return false
    end
end

function _reformulation_test_model()
    model = ToQUBO.Optimizer{Float64}()
    x = MOI.add_variable(model)
    MOI.add_constraint(model, x, MOI.Integer())
    MOI.add_constraint(model, x, MOI.Interval(0.0, 3.0))
    y, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

    c = MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(
            MOI.ScalarAffineTerm{Float64}[
                MOI.ScalarAffineTerm{Float64}(1.0, x),
                MOI.ScalarAffineTerm{Float64}(1.0, y),
            ],
            0.0,
        ),
        MOI.LessThan(2.0),
    )

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}[], 0.0),
    )

    MOI.optimize!(model)

    return model, x, y, c
end

function _target_state(model, x, y)
    n = MOI.get(model.target_model, MOI.NumberOfVariables())
    state = zeros(Int, n)

    for vi in (x, y)
        for target in MOI.get(model, Attributes.VariableTargetVariables(), vi)
            state[target.value] = 1
        end
    end

    return state
end

function test_reformulation_metadata()
    @testset "→ Reformulation Metadata" begin
        model, x, y, c = _reformulation_test_model()
        metadata = ToQUBO.reformulation_metadata(model)

        @test _json_compatible(metadata)
        @test metadata["schema_version"] == 1
        @test metadata["source"]["variable_order"] == [x.value, y.value]
        @test metadata["target"]["num_variables"] ==
              MOI.get(model.target_model, MOI.NumberOfVariables())

        x_entry = only(entry for entry in metadata["original_variables"] if entry["id"] == x.value)
        y_entry = only(entry for entry in metadata["original_variables"] if entry["id"] == y.value)
        @test x_entry["expansion_variables"] == x_entry["target_variables"]
        @test y_entry["expansion_variables"] == y_entry["target_variables"]
        @test x_entry["encoded"] === true
        @test y_entry["encoded"] === true
        @test !_json_compatible(Dict{String,Any}("value" => Inf))

        @test ToQUBO.original_variables(model) == VI[x, y]
        @test ToQUBO.original_variables(metadata) == [x.value, y.value]

        auxiliary = ToQUBO.auxiliary_variables(metadata)
        @test !isempty(auxiliary)
        @test auxiliary == [entry["id"] for entry in metadata["auxiliary_variables"]]
        @test any(
            entry -> entry["owner"]["type"] == "constraint",
            metadata["auxiliary_variables"],
        )
        @test any(
            entry -> entry["constraint"]["id"] == c.value,
            metadata["constraint_encodings"],
        )
        @test any(
            entry -> entry["constraint"]["id"] == c.value,
            metadata["slack_variables"],
        )

        state = _target_state(model, x, y)
        projected = ToQUBO.project_original_state(model, state)
        @test projected[x] == 3.0
        @test projected[y] == 1.0

        serialized_projected = ToQUBO.project_original_state(metadata, state)
        @test serialized_projected[x.value] == 3.0
        @test serialized_projected[y.value] == 1.0

        unencoded_metadata = deepcopy(metadata)
        unencoded_entry = only(
            entry for entry in unencoded_metadata["original_variables"] if entry["id"] == x.value
        )
        unencoded_entry["encoded"] = false
        unencoded_entry["expansion_variables"] = Int[]
        unencoded_entry["expansion_terms"] = Dict{String,Any}[]
        @test_throws ErrorException ToQUBO.project_original_state(unencoded_metadata, state)

        dict_state = Dict(VI(i) => state[i] for i = 1:length(state))
        dict_projected = ToQUBO.project_original_state(model, dict_state)
        @test dict_projected[x] == 3.0
        @test dict_projected[y] == 1.0

        backend = QUBOTools.backend(model)
        @test_throws ErrorException ToQUBO.reformulation_metadata(backend)

        backend = QUBOTools.backend(model; full_metadata = true)
        backend_metadata = QUBOTools.metadata(backend)
        backend_reformulation = ToQUBO.reformulation_metadata(backend)

        @test _json_compatible(backend_metadata)
        @test backend_reformulation["source"]["variable_order"] == [x.value, y.value]
        @test ToQUBO.original_variables(backend) == [x.value, y.value]
        @test ToQUBO.auxiliary_variables(backend) == auxiliary

        backend_projected = ToQUBO.project_original_state(backend, state)
        @test backend_projected[x.value] == 3.0
        @test backend_projected[y.value] == 1.0
    end

    return nothing
end
