using Crayons

function print_right_side(b,x,y)
    #b[y][x] = string(Crayon(foreground = :white), "o")
    #b[y+1][x-1] = string(Crayon(foreground = :white), "/")
    #b[y-1][x-1] = string(Crayon(foreground = :white), "\\")
    b[y][x] = "o"
    b[y+1][x-1] = "/"
    b[y-1][x-1] = "\\"
end
function right_angle(b,x,y)
    horizontal(b,x-3,y)
    b[y+2][x+2] = "o"
    b[y+1][x+1] = "\\"
end

function add_resource_and_dice_value(board, tile, b, x, y)
    b[y+2][x+1] = string(string(board.tile_to_resource[tile])[1])
    number = string(board.tile_to_dicevalue[tile])
    if length(number) == 2
        b[y+2][x+2] = string(number[1])
        b[y+2][x+3] = string(number[2])

    else
        b[y+2][x+2] = string(number)
    end
end

function hexagon(board, tile, b,x,y, print_tile_sym)
    # Draw base shape
    left_angle(b,x,y)
    right_angle(b,x+3,y)
    upper_left_angle(b,x,y+4)
    upper_right_angle(b,x+3,y+4)

    # Add tile info
    if print_tile_sym
        b[y+2][x+1] = string(tile)
    else
        add_resource_and_dice_value(board, tile, b, x, y)
    end

    # Add coordinate info
    coords = cyclic_sort(collect(TILE_TO_COORDS[tile]))
    for (v,c) in zip(vertices(x,y),coords)
        if haskey(board.coord_to_building, c)
            building_str = print_building(board.coord_to_building[c])
            b[v[2]][v[1]] = building_str
        end
    end
    
    # Add edge info
    vertices_list = vertices(x,y)

    """
    e - 2-tuple of physical coordinates for hexagon edges
    c - 2-tuple of logical coordinates for hexagon vertices

    We iterate through coords, and see if any roads have *both* endpoints on the current hexagon
    """
    for (i,(e,c)) in enumerate(zip(edges(x,y),coords))
        if haskey(board.coord_to_roads, c)
            roads = board.coord_to_roads[c]
            for road in roads
                c2 = road.coord1 == c ? road.coord2 : road.coord1
                
                # We check that this road lies on the current edge.  We rely on the correct ordering of vertices_list
                # so we can simply check that c2 is the next element in coords (with wraparound to coords[1] if needed
                if (i < length(vertices_list) && c2 == coords[i+1]) || (i == length(vertices_list) && c2 == coords[1])
                    road_str = print_road(road, b[e[2]][e[1]])
                    b[e[2]][e[1]] = road_str
                    if b[e[2]][e[1]-1] == "-"
                        b[e[2]][e[1]-1] = road_str
                    elseif b[e[2]][e[1]+1] == "-"
                        b[e[2]][e[1]+1] = road_str
                    end
                end
            end
        end
    end
end
#  vertices:
#    5--4
#   /    \
#  6      3
#   \    /
#    1--2
# edges:
#    o-6o
#   5    3
#  o      o
#   4    2
#    o1-o
#
#
test = [(1,1),(1,2),(1,3),(2,2),(2,3),(2,4)]
function cyclic_sort(coords)
    minx = minimum([c[1] for c in coords])
    bottom = sort([c for c in coords if c[1] == minx])
    top = sort([c for c in coords if c[1] != minx], by= x -> -x[2])
    append!(bottom,top)
    return bottom
end
function vertices_to_edge(x1,y1,x2,y2)
return (Int((x1 + x2) / 2),Int((y1 + y2) / 2))
end
function vertices(x,y)
    # Ordering is important so that it's compatible with the sort of TILE_TO_COORDS[tile]
    return [(x,y+4),(x+3,y+4),(x+5,y+2),(x+3,y),(x,y),(x-2,y+2)]
end
function edges(x,y)
    # Ordering is important so that it's compatible with the sort of TILE_TO_COORDS[tile]
    return [
    (x+1,y+4),
    (x+4,y+3),
    (x+4,y+1),
    (x+2,y),
    (x-1,y+1),
    (x-1,y+3)
    ]
end

function horizontal(b,x,y)
    b[y][x] = "o"
    b[y][x+3] = "o"
    b[y][x+1] = "-"
    b[y][x+2] = "-"
end
function upper_left_angle(b,x,y)
    horizontal(b,x,y)
    b[y-1][x-1] = "\\"
    b[y-2][x-2] = "o"
end
function upper_right_angle(b,x,y)
    horizontal(b,x-3,y)
    b[y-1][x+1] = "/"
    b[y-2][x+2] = "o"
end

function left_angle(b,x,y)
    horizontal(b,x,y)
    b[y+2][x-2] = "o"
    b[y+1][x-1] = "/"
end
function double_left_angle(b,x,y)
    left_angle(b,x,y)
    b[y-1][x-1] = "\\"
end
function double_right_angle(b,x,y)
    right_angle(b,x,y)
    b[y-1][x+1] = "/"
end

function print_board(board::Board, print_tile_sym = false)
    X = 48
    Y = 34
    b = repeat([repeat([" "], X)], Y)
    for (i,r) in enumerate(b)
        b[i] = copy(r)
    end 
    
    hexagon(board,:S,b,23,1, print_tile_sym)
    hexagon(board,:R,b,18,3, print_tile_sym)
    hexagon(board,:Q,b,13,5, print_tile_sym)
    
    hexagon(board,:P,b,28,3, print_tile_sym)
    hexagon(board,:O,b,23,5, print_tile_sym)
    hexagon(board,:N,b,18,7, print_tile_sym)
    hexagon(board,:M,b,13,9, print_tile_sym)
    
    hexagon(board,:L,b,33,5, print_tile_sym)
    hexagon(board,:K,b,28,7, print_tile_sym)
    hexagon(board,:J,b,23,9, print_tile_sym)
    hexagon(board,:I,b,18,11, print_tile_sym)
    hexagon(board,:H,b,13,13, print_tile_sym)
    
    hexagon(board,:G,b,33,9, print_tile_sym)
    hexagon(board,:F,b,28,11, print_tile_sym)
    hexagon(board,:E,b,23,13, print_tile_sym)
    hexagon(board,:D,b,18,15, print_tile_sym)
    
    hexagon(board,:C,b,33,13, print_tile_sym) # (2,4),(2,5),(1,5),(1,4),(1,3),(2,3)
    hexagon(board,:B,b,28,15, print_tile_sym) # (2,4),(2,5),(1,5),(1,4),(1,3),(2,3)
    hexagon(board,:A,b,23,17, print_tile_sym) # (2,3),(2,4),(1,3),(1,2),(1,1),(2,2)
    for (i,r) in enumerate(b)
        for rr in r
            print(rr)
            # TODO: should somehow identify terminal color if this is possible
            # Print empty white string to reset color
            print(string(Crayon(foreground=:white)))
        end
        println()
    end
    return b
end

function print_building(building)::String
    name = string(string(building.team)[1])
    team_color = Symbol(lowercase(string(building.team)))
    if building.type == :Settlement
        return string(Crayon(foreground = team_color), lowercase(name))
    else
        return string(Crayon(foreground = team_color), uppercase(name))
    end
end

function print_road(road, road_char)::String
    team_color = Symbol(lowercase(string(road.team)))
    return lowercase(string(Crayon(foreground = team_color), road_char))
    #return lowercase(string(Crayon(foreground = road.team), string(road.team)[1]))
end


