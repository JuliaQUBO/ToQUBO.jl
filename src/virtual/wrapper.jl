function MOI.is_empty(model::AbstractVirtualModel)
    all(MOI.is_empty.(MOI.get.(model, [SourceModel(), TargetModel()]))) && isempty(MOI.get(model, Variables()))
end