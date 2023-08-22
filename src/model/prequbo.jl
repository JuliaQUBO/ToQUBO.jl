MOIU.@model(PreQUBOModel,       # Name of model
    (MOI.Integer, MOI.ZeroOne), # untyped scalar sets
    (EQ, LT, GT),               #   typed scalar sets
    (),                         # untyped vector sets
    (MOI.SOS1,),                #   typed vector sets
    (VI,),                      # untyped scalar functions
    (SAF, SQF),                 #   typed scalar functions
    (MOI.VectorOfVariables,),   # untyped vector functions
    (),                         #   typed vector functions
    false,                      # is optimizer?
)

# Drop Generic Constraint Support
MOI.supports_constraint(::PreQUBOModel{T}, ::Type{SAF{T}}, ::Type{GT{T}}) where {T} = false
MOI.supports_constraint(::PreQUBOModel{T}, ::Type{SQF{T}}, ::Type{GT{T}}) where {T} = false