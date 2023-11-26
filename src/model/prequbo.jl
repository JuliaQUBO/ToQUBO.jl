MOIU.@model(
    PreQUBOModel,       # Name of model
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

