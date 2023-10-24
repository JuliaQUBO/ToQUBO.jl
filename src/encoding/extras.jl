function integer_interval((a, b)::Tuple{T,T}) where {T}
    if a < b
        return (ceil(a), floor(b))
    else
        return (ceil(b), floor(a))
    end
end
