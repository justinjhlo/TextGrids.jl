mutable struct Interval
    index::Int
    xmin::Float64
    xmax::Float64
    label::AbstractString
end

mutable struct Tier
    num::Int
    class::AbstractString
    name::AbstractString
    size::Int
    xmin::Float64
    xmax::Float64
    contents::Vector{Interval}
end

duration(interval::Interval) = interval.xmax - interval.xmin
duration(tier::Tier) = tier.xmax - tier.xmin

TextGrid = Vector{Tier}

function Base.show(io::IO, ::MIME"text/plain", tg::TextGrid)
    xmin, xmax = round.(extrema(tg), digits = 3)
    println("$(length(tg))-tier TextGrid ($(xmin)-$(xmax)s)")

    if length(tg) > 1
        print("Tiers:")
    elseif length(tg) == 1
        print("Tier:")
    end

    for tier in tg
        print(" ($(tier.num)) $(tier.name)")
    end
    length(tg) > 0 && print_tiers(io, tg)
end

function print_tiers(io::IO, tg::TextGrid, width = 75)
    println(io)
    println(io, "   +" * '-'^width * "+")
    for tier in tg
        print(io, rpad(tier.num, 3, ' ') * "|")

        chunk_width = duration(tier) / width
        chunk = fill(' ', width)
        if length(tier.contents) > 1
            in_chunk = unique([ceil(Int, (x.xmin - tier.xmin) / chunk_width) for x in tier.contents[2:end]])
            chunk[in_chunk] .= '|'
        end
        print(io, String(chunk))

        println(io, "|")
    end
    print(io, "   +" * '-'^width * "+")
end