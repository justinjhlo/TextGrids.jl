module TextGrids

export
    # readwrite
    read_TextGrid, write_TextGrid,

    # tiers
    rename!, relabel!,
    extract_tier,
    remove_tier!, remove_empty_tiers!,
    is_empty

include("readwrite.jl")
include("tiers.jl")
include("utils.jl")

end
