function Base.show(io::IO, model::AbstractVirtualModel)
    print(io, 
    """
    Virtual Model
    with source:
    $(MOI.get(model, SourceModel()))
    with target:
    $(MOI.get(model, TargetModel()))
    """
    )
end