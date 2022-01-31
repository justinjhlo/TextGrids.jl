function find_interval(tier::Tier, time::Real)
    throw_interval_class_error(tier)
    time < tier.xmin && return 0
    time > tier.xmax && return 0
    time == tier.xmax && return tier.size
    return findfirst(x -> x.xmin ≤ time < x.xmax, tier.contents)
end

find_interval(tg::TextGrid, num::Int, time::Real) = find_interval(tg[num], time)

function find_low_interval(tier::Tier, time::Real)
    index = find_interval(tier, time)
    if tier.contents[index].xmin == time
        index -= 1
    end
    return index
end

find_low_interval(tg::TextGrid, num::Int, time::Real) = find_low_interval(tg[num], time)

function find_high_interval(tier::Tier, time::Real)
    index = find_interval(tier, time)
    if tier.contents[index].xmax == time
        index += 1
    end
    return index
end

find_high_interval(tg::TextGrid, num::Int, time::Real) = find_high_interval(tg[num], time)

function find_interval_by_edge(tier::Tier, time::Real; inner::Bool = false)
    throw_interval_class_error(tier)

    if time == tier.xmax
        inner && return 0
        return tier.size
    end

    if time == tier.xmin
        inner && return 0
        return 1
    end

    index = findfirst(x -> time == x.xmin, tier.contents)
    return isnothing(index) ? 0 : index
end

find_interval_by_edge(tg::TextGrid, num::Int, time::Real; inner::Bool = false) = find_interval_by_edge(tg[num], time, inner = inner)

function find_low_point(tier::Tier, time::Real)
    throw_point_class_error(tier)
    time < tier.contents[1].xmin && return 0
    return findlast(x -> x.xmin ≤ time, tier.contents)
end

find_low_point(tg::TextGrid, num::Int, time::Real) = find_low_point(tg[num], time)

function find_high_point(tier::Tier, time::Real)
    throw_point_class_error(tier)
    time > tier.contents[end].xmax && return tier.size + 1
    return findfirst(x -> x.xmin ≥ time, tier.contents)
end

find_high_point(tg::TextGrid, num::Int, time::Real) = find_high_point(tg[num], time)

function find_nearest_point(tier::Tier, time::Real)
    throw_point_class_error(tier)
    return findmin([abs(x.xmin - time) for x in tier.contents])[2]
end

find_nearest_point(tg::TextGrid, num::Int, time::Real) = find_nearest_point(tg[num], time)

throw_interval_class_error(tier::Tier) = tier.class == "interval" || error("Cannot find intervals or boundaries in point tiers.")
throw_point_class_error(tier::Tier) = tier.class == "point" || error("Cannot find points in interval tiers.")