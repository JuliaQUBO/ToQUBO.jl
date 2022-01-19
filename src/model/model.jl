module QUBO
    # -*- Imports: MathOptInterface -*-
    import MathOptInterface
    const MOI = MathOptInterface

    const MOI_ZO = MOI.ZeroOne
    const MOI_VI = MOI.VariableIndex
    const MOI_INT = MOI.Integer

    const MOI_EQ{T} = MOI.EqualTo{T}
    const MOI_LT{T} = MOI.LessThan{T}

    const MOI_SAF{T} = MOI.ScalarAffineFunction{T}
    const MOI_SQF{T} = MOI.ScalarQuadraticFunction{T}

    export Model

    # -*- Model: PreQUBOModel -*-
    MOI.@model(
        PreQUBOModel,                                               # Name of model
        (MOI_INT, MOI_ZO),                                          # untyped scalar sets
        (MOI_EQ, MOI_LT),                                           #   typed scalar sets
        (),                                                         # untyped vector sets
        (),                                                         #   typed vector sets
        (MOI_VI),                                                   # untyped scalar functions
        (MOI_SAF, MOI_SQF),                                         #   typed scalar functions
        (),                                                         # untyped vector functions
        (),                                                         #   typed vector functions
        false
    )

    MOI.@model(
        QUBOModel,
        (MOI_ZO),                                                   # untyped scalar sets
        (),                                                         #   typed scalar sets
        (),                                                         # untyped vector sets
        (),                                                         #   typed vector sets
        (MOI_VI),                                                   # untyped scalar functions
        (MOI_SAF, MOI_SQF),                                         #   typed scalar functions
        (),                                                         # untyped vector functions
        (),                                                         #   typed vector functions
        false

    )

    struct Model{T <: Any} <: MOI.AbstractModelLike
        model::QUBOModel{T}

        ℍ₀::PBF{MOI_VI, }
    end

    function toqubo(T::Type{<: Any}, model::MOI.ModelLike)

        # -*- Bridges: PreModel -*-
        pre_model = PreQUBOModel{T}()
        MOI.copy_to(pre_model, model)

        
        return toqubo(pre_model)
    end

    function toqubo(model::MOI.ModelLike)
        return toqubo(Float64, model)
    end

    function toqubo(model::PreQUBOModel{T}) where {T}

    end
end # module