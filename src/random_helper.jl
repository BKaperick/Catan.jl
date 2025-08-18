function has_any_elements(sym_dict::Dict{Symbol, T}) where {T<:Integer}
    @debug "has any elements? $sym_dict"
    return sum(values(sym_dict)) > 0
end

function unsafe_random_sample_one_resource(resources::Dict{Symbol, T}, replace=false)::Symbol where {T<:Integer}
    items = Vector{Symbol}()
    for (r,c) in resources
        if c > 0
            append!(items, repeat([r], c))
        end
    end
    return sample(items, 1, replace=replace)[1]
end

function random_sample_resources(resources::Dict{Symbol, Int}, count, replace=false)::Vector{Symbol}
    items = Vector{Symbol}()
    for (r,c) in resources
        if c > 0
            append!(items, repeat([r], c))
        end
    end
    @debug resources
    real_count = min(count, length(items))
    return sample(items, real_count, replace=replace)
end

function get_random_tile(board)::Symbol
    candidates = [keys(board.map.tile_to_dicevalue)...]
    return sample(candidates, 1)[1]
end

#TODO unused
function get_random_empty_coord(board)
    return sample(BoardApi.get_empty_spaces(board), 1)[1]
end

function get_random_resource()
    return sample([RESOURCES...])
end
