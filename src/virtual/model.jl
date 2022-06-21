@doc raw"""
    abstract type AbstractVirtualModel{T} <: MOI.AbstractOptimizer end
"""
abstract type AbstractVirtualModel{T} <: MOI.AbstractOptimizer end

struct Source <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Source) end
function MOI.get(::AbstractVirtualModel, ::Source, ::VI) end
function MOI.set(::AbstractVirtualModel, ::Source, ::VI, ::VV) end

struct Target <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Target) end
function MOI.get(::AbstractVirtualModel, ::Target, ::VI) end
function MOI.set(::AbstractVirtualModel, ::Target, ::VI, ::VV) end

struct Variables <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Variables) end

struct SourceModel <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::SourceModel) end

struct TargetModel <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::TargetModel) end