"""
    insert_point!(tier, time, label)
    insert_point!(tg, num, time, label)

Insert a point at `time` with `label` in a point `tier`, which can also be
specified by its number in a `TextGrid`.
"""
function insert_point!(tier::Tier, time::Real, label::AbstractString)
    nearest = findlast(x -> x.xmin ≤ time, tier.contents)
    tier.contents[nearest].xmin == time && error("Point already exists in Tier $(tier.num) at $(time)s.")

    insert!(tier.contents, nearest + 1, Interval(tier.num, nearest + 1, time, time, label))
    tier.size += 1
    reindex_intervals!(tier, from = nearest + 1)
end

insert_point!(tg::TextGrid, num::Int, time::Real, label::AbstractString) = insert_point!(tg[num], time, label)

function insert_points!(tier::Tier, times::Vector{<:Real}, labels::Vector{<:AbstractString})
    for (time, label) in zip(times, labels)
        insert_point!(tier, time, label)
    end
end

insert_points!(tg::TextGrid, num::Int, times::Vector{<:Real}, labels::Vector{<:AbstractString}) = insert_points!(tg[num], times, labels)

function insert_points!(tier::Tier, points...)
    for (time, label) in points
        if time isa AbstractFloat && label isa AbstractString
            insert_point!(tier, time, label)
        end
    end
end

"""
    remove_point!(tier, index)
    remove_point!(tg, num, index)

Remove the `index`-th point in a point `tier`.
"""
function remove_point!(tier::Tier, index::Int)
    tier.class == "point" || error("Cannot remove points from interval tiers.")

    delete!(tier.contents, index)
    tier.size -= 1
    reindex_intervals!(tier, from = index)
end

remove_point!(tg::TextGrid, num::Int, index::Int) = remove_point!(tg[num], index)

"""
    remove_point!(tier, time; tolerance = 0.0001)
    remove_point!(tg, num, time; tolerance = 0.0001)
    
Remove the point at, or nearest to (± `tolerance`), `time` from a point `tier`.
"""
function remove_point!(tier::Tier, time::AbstractFloat; tolerance::Real = 0.0001)
    index = find_nearest_point(tier, time)
    if abs(tier.contents[index].xmin - time) ≤ tolerance
        remove_point!(tier, index)
    end
    return tier
end

remove_point!(tg::TextGrid, num::Int, time::AbstractFloat; tolerance::Real = 0.0001) = remove_point!(tg[num], time, tolerance = tolerance)

function remove_points!(tier::Tier, times::Vector{<:AbstractFloat}; tolerance::Real = 0.0001)
    for time in times
        remove_point!(tier, time, tolerance = tolerance)
    end
end

remove_points!(tg::TextGrid, num::Int, times::Vector{<:AbstractFloat}; tolerance::Real = 0.0001) = remove_points!(tg[num], times, tolerance = tolerance)