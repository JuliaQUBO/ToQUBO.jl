@doc raw"""
    Model{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct Model{T,O} <: MOI.AbstractOptimizer
    # Underlying Optimizer
    optimizer::O

    # MathOptInterface Bridges
    bridge_model::MOIB.LazyBridgeOptimizer{PreQUBOModel{T}}

    # Virtual Model Interface
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    variables::Vector{Variable{T}}
    source::Dict{VI,Variable{T}}
    target::Dict{VI,Variable{T}}
    slack::Dict{CI,Variable{T}}

    # PBO/PBF IR
    f::PBO.PBF{VI,T}          # Objective Function
    g::Dict{CI,PBO.PBF{VI,T}} # Constraint Penalty Functions
    ρ::Dict{CI,T}             # Constraint Penalty Factors
    h::Dict{VI,PBO.PBF{VI,T}} # Variable Penalty Functions
    θ::Dict{VI,T}             # Variable Penalty Factors
    s::Dict{CI,PBO.PBF{VI,T}} # Slack Penalty Functions
    η::Dict{CI,T}             # Slack Penalty Factors
    H::PBO.PBF{VI,T}          # Final Objective Function

    # Settings 
    compiler_settings::Dict{Symbol,Any}
    variable_settings::Dict{Symbol,Dict{VI,Any}}
    constraint_settings::Dict{Symbol,Dict{CI,Any}}
    moi_settings::Dict{Symbol,Any}

    function Model{T}(constructor::Any; kws...) where {T}
        optimizer = constructor()::MOI.AbstractOptimizer

        return Model{T,typeof(optimizer)}(optimizer; kws...)
    end

    function Model{T}(::Nothing = nothing; kws...) where {T}
        return Model{T,Nothing}(nothing; kws...)
    end

    function Model{T,O}(
        optimizer::O = nothing;
        kws...,
    ) where {T,O<:Union{MOI.AbstractOptimizer,Nothing}}
        source_model = PreQUBOModel{T}()
        target_model = QUBOModel{T}()
        bridge_model = MOIB.full_bridge_optimizer(source_model, T)

        new{T,O}(
            # Underlying Optimizer
            optimizer,

            # MathOptInterface Bridges
            bridge_model,

            # Virtual Model Interface 
            source_model,
            target_model,
            Vector{Variable{T}}(),  # variables
            Dict{VI,Variable{T}}(), # source
            Dict{VI,Variable{T}}(), # target
            Dict{CI,Variable{T}}(), # slack

            # PBO/PBF IR 
            PBO.PBF{VI,T}(),          # Objective Function
            Dict{CI,PBO.PBF{VI,T}}(), # Constraint Penalty Functions
            Dict{CI,T}(),             # Constraint Penalty Factors
            Dict{VI,PBO.PBF{VI,T}}(), # Variable Penalty Functions
            Dict{VI,T}(),             # Variable Penalty Factors
            Dict{CI,PBO.PBF{VI,T}}(), # Slack Penalty Functions
            Dict{CI,T}(),             # Slack Penalty Factors
            PBO.PBF{VI,T}(),          # Final Objective Function

            # Settings 
            Dict{Symbol,Any}(),
            Dict{Symbol,Dict{VI,Any}}(),
            Dict{Symbol,Dict{CI,Any}}(),
            Dict{Symbol,Any}(),
        )
    end
end

Model(args...; kws...) = Model{Float64}(args...; kws...)
