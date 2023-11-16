const IEQ_ONE{T}  = MOI.Indicator{MOI.ACTIVATE_ON_ONE,EQ{T}}
const ILT_ONE{T}  = MOI.Indicator{MOI.ACTIVATE_ON_ONE,LT{T}}
const IEQ_ZERO{T} = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,EQ{T}}
const ILT_ZERO{T} = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,LT{T}}

MOIU.@model(
    PreQUBOModel,                # Name of model
    (MOI.Integer, MOI.ZeroOne),  # untyped scalar sets
    (EQ, LT, GT),                #   typed scalar sets
    (),                          # untyped vector sets
    (                            #   typed vector sets
        MOI.SOS1,
        IEQ_ONE,
        ILT_ONE,
        IEQ_ZERO,
        ILT_ZERO,
    ),
    (VI,),                       # untyped scalar functions
    (SAF, SQF),                  #   typed scalar functions
    (MOI.VectorOfVariables,),    # untyped vector functions
    (                            #   typed vector functions
        MOI.VectorAffineFunction,
        MOI.VectorQuadraticFunction,
    ), 
    false,                       # is optimizer?
)

# Drop Generic Constraint Support to trigger bridges
MOI.supports_constraint(::PreQUBOModel{T}, ::Type{SAF{T}}, ::Type{GT{T}}) where {T} = false
MOI.supports_constraint(::PreQUBOModel{T}, ::Type{SQF{T}}, ::Type{GT{T}}) where {T} = false
