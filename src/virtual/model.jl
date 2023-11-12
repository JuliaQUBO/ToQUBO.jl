@doc raw"""
    Model{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
mutable struct Model{T} <: MOI.AbstractOptimizer
    # Underlying Optimizer  #
    optimizer::Union{MOI.AbstractOptimizer,Nothing}

    # MathOptInterface Bridges  #
    bridge_model::MOIB.LazyBridgeOptimizer{PreQUBOModel{T}}

    # Virtual Model Interface  #
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    variables::Vector{Variable{T}}
    source::Dict{VI,Variable{T}}
    target::Dict{VI,Variable{T}}

    # PBO/PBF IR  #
    f::PBO.PBF{VI,T}          # Objective Function
    g::Dict{CI,PBO.PBF{VI,T}} # Constraint Functions
    h::Dict{VI,PBO.PBF{VI,T}} # Variable Functions
    ρ::Dict{CI,T}             # Constraint Penalties
    θ::Dict{VI,T}             # Variable Penalties
    H::PBO.PBF{VI,T}          # Final Objective Function

    # Settings 
    compiler_settings::Dict{Symbol,Any}
    variable_settings::Dict{Symbol,Dict{VI,Any}}
    constraint_settings::Dict{Symbol,Dict{CI,Any}}

    function Model{T}(
        constructor::Union{Type{O},Function};
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        optimizer = constructor()

        return Model{T}(optimizer; kws...)
    end

    function Model{T}(
        optimizer::Union{O,Nothing} = nothing;
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        source_model = PreQUBOModel{T}()
        target_model = QUBOModel{T}()
        bridge_model = MOIB.full_bridge_optimizer(source_model, T)

        new{T}(
            # Underlying Optimizer  #
            optimizer,

            # MathOptInterface Bridges  #
            bridge_model,

            # Virtual Model Interface 
            source_model,
            target_model,
            Vector{Variable{T}}(),
            Dict{VI,Variable{T}}(),
            Dict{VI,Variable{T}}(),

            # PBO/PBF IR 
            PBO.PBF{VI,T}(),          # Objective Function
            Dict{CI,PBO.PBF{VI,T}}(), # Constraint Functions
            Dict{VI,PBO.PBF{VI,T}}(), # Variable Functions
            Dict{CI,T}(),             # Constraint Penalties
            Dict{VI,T}(),             # Variable Penalties
            PBO.PBF{VI,T}(),          # Final Objective Function

            # Settings 
            Dict{Symbol,Any}(),
            Dict{Symbol,Dict{VI,Any}}(),
            Dict{Symbol,Dict{CI,Any}}(),
        )
    end
end

Model(args...; kws...) = Model{Float64}(args...; kws...)
