# -*- Model: PreQUBOModel -*- #
MOIU.@model(PreQUBOModel,       # Name of model
    (MOI.Integer, MOI.ZeroOne), # untyped scalar sets
    (EQ, LT, GT),               #   typed scalar sets
    (),                         # untyped vector sets
    (),                         #   typed vector sets
    (VI,),                      # untyped scalar functions
    (SAF, SQF),                 #   typed scalar functions
    (),                         # untyped vector functions
    (),                         #   typed vector functions
    false,                      # is optimizer?
)

# :: Drop Automatic Constraint Support :: #
MOI.supports_constraint(
    ::PreQUBOModel{T},
    ::Type{<:Union{SAF, SQF}},
    ::Type{<:Union{MOI.Integer, MOI.ZeroOne, GT}},
) where {T} = false

# -*- Model: QUBOModel -*-
MOIU.@model(QUBOModel,
    (MOI.ZeroOne,),             # untyped scalar sets
    (),                         #   typed scalar sets
    (),                         # untyped vector sets
    (),                         #   typed vector sets
    (VI,),                         # untyped scalar functions
    (SQF,),                     #   typed scalar functions
    (),                         # untyped vector functions
    (),                         #   typed vector functions
    false,                      # is optimizer?
)

# :: Reset Constraint Support :: #
MOI.supports_constraint(
    ::QUBOModel{T},
    ::Type{<:SQF},
    ::Type{<:MOI.ZeroOne},
) where {T} = false