# insert functions

"""
    insert_boundary!(tier, time; split_at = 0)
    insert_boundary!(tg, num, time; split_at = 0)

Insert a boundary at `time` in an interval `tier`, which can also be specified
by its number in a `TextGrid`. This action splits an existing interval and
increases the size of the tier by 1.

The keyword argument `split_at` indicates the starting position in the label of
the interval being split that belongs to the right interval. The remaining part
of the label belongs to the left interval. A value outside any valid index for
the label (i.e. the default value 0, any negative integer, or any positive
integer greater than its length) means that the whole original label belongs to
the left interval.
"""
function insert_boundary!(tier::Tier, time::Real; split_at::Int = 0)
    tier.class == "interval" || error("Cannot insert boundaries in point tiers.")
    index = findfirst(x -> x.xmin ≤ time ≤ x.xmax, tier.contents)
    isnothing(index) && error("Time out of bounds of tier.")
    if tier.contents[index].xmin == time || tier.contents[index].xmax == time
        error("Boundary already exists in Tier $tier at $(time)s.")
    end

    label_length = length(tier.contents[index].label)
    split_at ∈ 1:label_length || (split_at = label_length + 1)
    insert!(tier.contents, index + 1, Interval(tier.num, index + 1, time, tier.contents[index].xmax, tier.contents[index].label[split_at:end]))
    tier.contents[index].xmax = time
    tier.contents[index].label = tier.contents[index].label[1:(split_at - 1)]
    tier.size += 1
    reindex_intervals!(tier, from = index + 1)
end

insert_boundary!(tg::TextGrid, num::Int, time::Real; split_at::Int = 0) = insert_boundary!(tg[num], time, split_at = split_at)

"""
    insert_interval!(tier, start, stop, label; split_at = 0)
    insert_interval!(tg, num, start, stop, label; split_at = 0)

Insert an interval from `start` to `stop` in an interval `tier`. Inserted
intervals must not straddle an existing boundary, but if either `start` or
`stop` coincides with an existing edge of an interval, then the other boundary
is added to split the original interval.

The keyword argument `split_at` indicates the starting position in the label of
the interval being split that belongs to the interval immediately to the right
of the inserted interval. Note that if either `start` or `stop` coincides with
an existing edge, `split_at` is automatically overridden and the whole original
label goes to the split interval. See also `insert_boundary!`.
"""
function insert_interval!(tier::Tier, start::Real, stop::Real, label::AbstractString; split_at::Int = 0)
    tier.class == "interval" || error("Cannot insert intervals in point tiers.")

    start_index, stop_index = is_interval_insertable(tier, start, stop)

    if start == tier.contents[start_index].xmin
        # If only left edge already exists, insert new right edge and force original label to the right
        insert_boundary!(tier, stop, split_at = 1)
        relabel!(tier, start_index, label)
    elseif stop == tier.contents[stop_index].xmax
        # If only right edge already exists, insert new left edge and force original label to the left
        insert_boundary!(tier, start)
        relabel!(tier, start_index + 1, label)
    else
        insert_boundary!(tier, stop, split_at = split_at)
        insert_boundary!(tier, start)
        relabel!(tier, start_index + 1, label)
    end
    return tier
end

insert_interval!(tg::TextGrid, num::Int, start::Real, stop::Real, label::AbstractString; split_at::Int = 0) = insert_interval!(tg[num], start, stop, label, split_at = split_at)

"""
    copy_interval!(tier, source_tier, index; split_at = 0)
    copy_interval!(tg, num, source_num, index; split_at = 0)

Copy the `index`-th interval from `source_tier` to `tier`.

See also `insert_interval!`.
"""
copy_interval!(tier::Tier, source_tier::Tier, index::Int; split_at::Int = 0) = insert_interval!(tier, source_tier.contents[index].xmin, source_tier.contents[index].xmax, source_tier.contents[index].label, split_at = split_at)
copy_interval!(tg::TextGrid, num::Int, source_num::Int, index::Int; split_at::Int = 0) = copy_interval!(tg[num], tg[source_num], index, split_at = split_at)

"""
Insert multiple intervals to an interval `tier`, with boundaries and labels
defined by `starts`, `stops` and `labels`. The keyword argument `split_at` can
be either a single integer if constant across inserted intervals or a vector of
integers if custom per interval.

Intervals are inserted in the specified order, and intervals that cannot be
inserted are simply discarded rather than throw an error.

See also `insert_interval!`
"""
function insert_intervals!(tier::Tier, starts::Vector{<:Real}, stops::Vector{<:Real}, labels::Vector{<:AbstractString}; split_at::Union{Int, Vector{Int}} = 0)
    num_added = minimum(length, [starts, stops, labels])
    if split_at isa Vector
        length(split_at) < num_added && error("`split_at must not be shorter than `starts`, `stops` and `labels`.")
        for (start, stop, label, split_at_i) in zip(starts, stops, labels, split_at)
            try
                insert_interval!(tier, start, stop, label, split_at = split_at_i)
            catch
                continue
            end
        end
    else    
        for (start, stop, label) in zip(starts, stops, labels)
            try
                insert_interval!(tier, start, stop, label, split_at = split_at)
            catch
                continue
            end
        end
    end
    return tier
end

insert_intervals!(tg::TextGrid, num::Int, starts::Vector{<:Real}, stops::Vector{<:Real}, labels::Vector{<:AbstractString}; split_at::Union{Int, Vector{Int}} = 0) = insert_intervals!(tg[num], starts, stops, labels, split_at = split_at)

function is_interval_insertable(tier::Tier, start::Real, stop::Real)
    start ≥ stop && error("Start time must come before stop time.")
    start_index = find_interval(tier, start)
    stop_index = find_low_interval(tier, stop)
    start_index * stop_index == 0 && error("Time out of bounds of tier.")
    start_index != stop_index && error("Cannot insert interval that straddles a boundary.")
    start == tier.contents[start_index].xmin && stop == tier.contents[stop_index].xmax && error("Interval already exists with the same boundaries.")
    return start_index, stop_index
end

# remove functions

"""
    remove_left_boundary!(tier, index; delim = "")
    remove_left_boundary!(tg, num, index; delim = "")

Remove the left boundary of the `index`-th interval in a `tier`.

The keyword argument `delim` defines the string used to join the labels from
the two intervals being combined.
"""
function remove_left_boundary!(tier::Tier, index::Int; delim::AbstractString = "")
    tier.class == "interval" || error("Cannot remove boundaries from point tiers.")
    index == 1 && error("Cannot remove left edge of tier.")

    tier.contents[index - 1].xmax = tier.contents[index].xmax
    relabel!(tier, index - 1, tier.contents[index - 1].label * delim * tier.contents[index].label)
    deleteat!(tier.contents, index)
    tier.size -= 1
    reindex_intervals!(tier, from = index)
end

remove_left_boundary!(tg::TextGrid, num::Int, index::Int; delim::AbstractString = "") = remove_left_boundary!(tg[num], index, delim = delim)

"""
    remove_right_boundary!(tier, index; delim = "")
    remove_right_boundary!(tg, num, index; delim = "")

Remove the right boundary of the `index`-th interval in an interval `tier`.

The keyword argument `delim` defines the string used to join the labels from
the two intervals being combined.
"""
function remove_right_boundary!(tier::Tier, index::Int; delim::AbstractString = "")
    tier.class == "interval" || error("Cannot remove boundaries from point tiers.")
    index == tier.size && error("Cannot remove right edge of tier.")

    remove_left_boundary!(tier, index + 1, delim = delim)
end

remove_right_boundary!(tg::TextGrid, num::Int, index::Int; delim::AbstractString = "") = remove_right_boundary!(tg[num], index, delim = delim)

"""
    remove_boundary!(tier, time; delim = "", tolerance = 0.0001)
    remove_boundary!(tier, num, time; delim = "", tolerance = 0.0001)

Remove the boundary at `time` (± `tolerance`) from an interval `tier`.

The keyword argument `delim` defines the string used to join the labels from
the two intervals being combined.
"""
function remove_boundary!(tier::Tier, time::AbstractFloat; delim::AbstractString = "", tolerance::Real = 0.0001)
    index = findlast(x -> abs(x.xmin - time) ≤ tolerance, tier.contents)
    if !isnothing(index)
        remove_left_boundary!(tier, index, delim)
    end
end

remove_boundary!(tg::TextGrid, num::Int, time::AbstractFloat; delim::AbstractString = "", tolerance::Real = 0.0001) = remove_boundary!(tg[num], time, delim = delim, tolerance = tolerance)

"""
    remove_boundary!(tier, index, edge; delim = "")
    remove_boundary!(tier, num, index, edge; delim = "")

Remove left and/or right boundaries of the `index`-th interval in `tier`.
Depending on value of `edge`, equivalent to:
- `"left"`: `remove_left_boundary!`
- `"right"`: `remove_right_boundary!`
- `"both"`: a combination of the two

The keyword argument `delim` defines the string used to join the labels from
the two intervals being combined.
"""
function remove_boundary!(tier::Tier, index::Int, edge::AbstractString; delim::AbstractString = "")
    edge ∈ ("left", "right", "both") || error("`edge` must be `left`, `right` or `both`.")
    edge != "left" && remove_right_boundary!(tier, index, delim = delim)
    edge != "right" && remove_left_boundary!(tier, index, delim = delim)
    return tier
end

remove_boundary!(tg::TextGrid, num::Int, index::Int, edge::AbstractString; delim::AbstractString = "") = remove_boundary!(tg[num], index, edge, delim = delim)

function remove_interval!(tier::Tier, index::Int)
    tier.xmin == tier.contents[index].xmin && tier.xmax == tier.contents[index].xmax && error("Cannot remove only interval in tier $tier.")

    relabel!(tier, index, "")
    edge = if tier.contents[index].xmin == tier.xmin
        "right"
    elseif tier.contents[index].xmax == tier.xmax
        "left"
    else
        "both"
    end

    remove_boundary!(tier, index, edge)
end

remove_interval!(tg::TextGrid, num::Int, index::Int) = remove_interval!(tg[num], index)