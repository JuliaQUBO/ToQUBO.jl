abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

struct QUADRATIZE <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::QUADRATIZE)
    return get(model.compiler_settings, :quadratize, false)
end

function MOI.set(model::VirtualQUBOModel, ::QUADRATIZE, flag::Bool)
    model.compiler_settings[:quadratize] = flag

    return nothing
end

struct QUADRATIZATION_METHOD <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::QUADRATIZATION_METHOD)
    return get(model.compiler_settings, :quadratization_method, PBO.INFER)
end

function MOI.set(
    model::VirtualQUBOModel,
    ::QUADRATIZATION_METHOD,
    ::Type{method},
) where {method <: PBO.QuadratizationMethod}
    model.compiler_settings[:quadratization_method] = method

    return nothing
end

struct STABLE_QUADRATIZATION <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::STABLE_QUADRATIZATION)
    return get(model.compiler_settings, :stable_quadratization, false)
end

function MOI.set(model::VirtualQUBOModel, ::STABLE_QUADRATIZATION, flag::Bool)
    model.compiler_settings[:stable_quadratization] = flag

    return nothing
end

struct DISCRETIZE <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::DISCRETIZE)
    return get(model.compiler_settings, :discretize, false)
end

function MOI.set(model::VirtualQUBOModel, ::DISCRETIZE, flag::Bool)
    model.compiler_settings[:discretize] = flag

    return nothing
end

struct DEFAULT_VARIABLE_ENCODING <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::DEFAULT_VARIABLE_ENCODING)
    return get(model.compiler_settings, :default_variable_encoding, Binary())
end

function MOI.set(model::VirtualQUBOModel, ::DEFAULT_VARIABLE_ENCODING, e::Encoding)
    model.compiler_settings[:default_variable_encoding] = e

    return nothing
end

abstract type CompilerVariableAttribute <: CompilerAttribute end

struct VARIABLE_ENCODING <: CompilerVariableAttribute end

function MOI.get(model::VirtualQUBOModel, ::VARIABLE_ENCODING, vi::VI)
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DEFAULT_VARIABLE_ENCODING())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::VirtualQUBOModel, ::VARIABLE_ENCODING, vi::VI, e::Encoding)
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

struct VARIABLE_ENCODING_PENALTY <: CompilerVariableAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::VARIABLE_ENCODING_PENALTY, vi::VI) where {T}
    return model.θ[vi]::T
end

function MOI.set(
    model::VirtualQUBOModel{T},
    ::VARIABLE_ENCODING_PENALTY,
    vi::VI,
    θ::T,
) where {T}
    model.θ[vi] = θ

    return nothing
end

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

struct Tol <: MOI.AbstractOptimizerAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::Tol) where {T}
    return model.compiler_settings.atol[nothing]::T
end

function MOI.set(model::VirtualQUBOModel{T}, ::Tol, atol::T) where {T}
    @assert atol > zero(T)

    model.compiler_settings.atol[nothing] = atol
end

struct CONSTRAINT_PENALTY <: CompilerConstraintAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::CONSTRAINT_PENALTY, ci::CI) where {T}
    return model.ρ[ci]
end

function MOI.set(model::VirtualQUBOModel{T}, ::CONSTRAINT_PENALTY, ci::CI, ρ::T) where {T}
    model.ρ[ci] = ρ

    return nothing
end

# -*- MOI Attribute Forwarding -*- #
function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractOptimizerAttribute)
    return MOI.get(model.optimizer, attr)
end

function MOI.set(model::VirtualQUBOModel, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(model.optimizer, attr, value)

    return nothing
end

# function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractVariableAttribute, vi::VI)
#     return MOI.get(model.optimizer, attr, vi)
# end

# function MOI.set(
#     model::VirtualQUBOModel,
#     attr::MOI.AbstractVariableAttribute,
#     vi::VI,
#     value,
# )
#     MOI.set(model.optimizer, attr, vi, value)

#     return nothing
# end

# function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractConstraintAttribute, ci::CI)
#     return MOI.get(model.optimizer, attr, ci)
# end

# function MOI.set(
#     model::VirtualQUBOModel,
#     attr::MOI.AbstractConstraintAttribute,
#     ci::CI,
#     value,
# )
#     MOI.set(model.optimizer, attr, ci, value)

#     return nothing
# end