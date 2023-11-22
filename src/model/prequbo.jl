const INDICATOR_EQ_ONE{T}        = MOI.Indicator{MOI.ACTIVATE_ON_ONE,EQ{T}}
const INDICATOR_LT_ONE{T}        = MOI.Indicator{MOI.ACTIVATE_ON_ONE,LT{T}}
const INDICATOR_GT_ONE{T}        = MOI.Indicator{MOI.ACTIVATE_ON_ONE,GT{T}}
const INDICATOR_Interval_ONE{T}  = MOI.Indicator{MOI.ACTIVATE_ON_ONE,MOI.Interval{T}}
const INDICATOR_EQ_ZERO{T}       = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,EQ{T}}
const INDICATOR_LT_ZERO{T}       = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,LT{T}}
const INDICATOR_GT_ZERO{T}       = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,GT{T}}
const INDICATOR_Interval_ZERO{T} = MOI.Indicator{MOI.ACTIVATE_ON_ZERO,MOI.Interval{T}}

MOIU.@model(
    PreQUBOModel,                # Name of model
    (MOI.Integer, MOI.ZeroOne),  # untyped scalar sets
    (EQ, LT, GT),                #   typed scalar sets
    (),                          # untyped vector sets
    (                            #   typed vector sets
        MOI.SOS1,
        INDICATOR_EQ_ONE,
        INDICATOR_LT_ONE,
        INDICATOR_GT_ONE,
        INDICATOR_Interval_ONE,
        INDICATOR_EQ_ZERO,
        INDICATOR_LT_ZERO,
        INDICATOR_GT_ZERO,
        INDICATOR_Interval_ZERO,
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
