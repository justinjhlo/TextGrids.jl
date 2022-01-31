module TextGrids

export
    # readwrite
    read_TextGrid, write_TextGrid,

    # tiers
    rename!, relabel!,
    extract_tier,
    remove_tier!, remove_empty_tiers!,
    is_empty,

    # query
    find_interval,
    find_low_interval,
    find_high_interval,
    find_interval_by_edge,

    find_low_point,
    find_high_point,
    find_nearest_point,

    # boundaries
    insert_boundary!,
    insert_interval!,
    insert_intervals!

    remove_boundary!,
    remove_left_boundary!,
    remove_right_boundary!,
    remove_interval!,

    # points
    insert_point!,
    insert_points!,

    remove_point!,
    remove_points!

include("readwrite.jl")
include("tiers.jl")
include("query.jl")
include("boundaries.jl")
include("points.jl")
include("utils.jl")

end
