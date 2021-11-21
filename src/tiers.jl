function rename!(tier::Tier, name::AbstractString)
    tier.name = name
    tier
end

function rename!(tg::TextGrid, num::Int, name::AbstractString)
    tier_num = findfirst(x -> x.num == num, tg)
    tg[tier_num].name = name
    tg
end

function rename!(tg::TextGrid, name_orig::AbstractString, name::AbstractString)
    tier_num = findfirst(x -> x.name == name_orig, tg)
    tg[tier_num].name = name
    tg
end

function relabel!(interval::Interval, label::AbstractString)
    interval.label = label
    interval
end

function relabel!(tier::Tier, index::Int, label::AbstractString)
    interval_num = findfirst(x -> x.index == index, tier.contents)
    tier.contents[interval_num].label = label
    tier
end

function relabel!(tier::Tier, indices, labels)
    for (index, label) in zip(indices, labels)
        relabel!(tier, index, label)
    end
end

function relabel!(tier::Tier, labels)
    for (index, label) in enumerate(labels)
        relabel!(tier.contents[index], label)
    end
    tier
end

function extract_tier(tg::TextGrid, tiers...)
    tg_new = TextGrid()
    for tier in tiers
        if tier isa Integer
            tier_num = findfirst(x -> x.num == tier, tg)
        elseif tier isa String
            tier_num = findfirst(x -> x.name == tier, tg)
        else
            tier_num = nothing
        end

        if !isnothing(tier_num)
            push!(tg_new, Tier(length(tg_new) + 1, tg[tier_num].class, tg[tier_num].name, tg[tier_num].size, tg[tier_num].xmin, tg[tier_num].xmax, tg[tier_num].contents))
        end
    end
    tg_new
end

function remove_tier!(tg::TextGrid, tiers...)
    for tier in tiers
        if tier isa Integer
            deleteat!(tg, findfirst(x -> x.num == tier, tg))
        elseif tier isa String
            deleteat!(tg, findfirst(x -> x.name == tier, tg))
        end
    end
    for (i, tier) in enumerate(tg)
        tier.num = i
    end
    tg
end

function remove_empty_tiers!(tg::TextGrid; empty_labels::Bool = true)
    tiers = findall(x -> is_empty(x, empty_labels = empty_labels), tg)
    remove_tier!(tg, tiers...)
end

function is_empty(tier::Tier; empty_labels::Bool = true)
    if tier.class == "point"
        tier.size == 0 && return true
    else
        if tier.size == 1
            length(tier.contents) == 0 && return true
            strip(tier.contents[1].label) == "" && return true
        end
    end

    if !empty_labels
        for interval in tier.contents
            strip(interval.label) == "" || return false
        end
        return true
    end
    return false
end

function resize_tier!(tier::Tier)
    if tier.class == "point"
        return length(tier.contents)
    end

    t = 0.0
    size = 0
    for interval in tier.contents
        if t < interval.xmin
            size += 1
        end
        size += 1
        interval.index = size
        t = interval.xmax
    end
    if t < tier.xmax
        size += 1
    end
    tier.size = size
    tier
end

resize_tier(tier::Tier) = resize_tier!(deepcopy(tier))