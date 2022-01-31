mutable struct Interval
    tier::Int
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

TextGrid = Vector{Tier}

# reading functions

"""
    read_TextGrid(file; intervals = true, points = true, nonempty = false)

Read a Praat TextGrid file and return a `TextGrid` object, which is equivalent
to a Vector of the type `Tier`. Supports both full and short text formats.

Each `Tier` has a number of attributes:
- `num`: index
- `class`: either "interval" or "point"
- `name`
- `size`
- `xmin`, `xmax`: time domain
- `contents`: a Vector of `Interval`s containing all annotations. Intervals
    also apply to point annotations.

# Keyword arguments:
- `intervals::Bool = true`: Determines if Interval Tiers are read.
- `points::Bool = true`: Determines if Point Tiers are read.
- `nonempty::Bool = false`: Determines if only nonempty annotations are parsed.
    If `true`, the output `Tier` will not contain any empty intervals or points.
    Any empty points or boundaries between successive empty intervals from the
    input file are not preserved, and the size of the `Tier` will be recalculated
    to account for the lost annotations.
"""
function read_TextGrid(file::AbstractString; intervals::Bool = true, points::Bool = true, nonempty::Bool = false)
    isfile(file) || error("$file does not exist")

    f = readlines(file)
    f = join(f, " ")

    tg = TextGrid()
    # TBD: trim !-headed comments
    
    # tg_quotes = findall(r"(?<=^|\s|\t)(\".*?[^\"]\"|\"\")(?=\t|\s|$)", f) # match free-standing text enclosed within double quotes
    tg_quotes = findall(r"(?<=^|\s|\t)\".*?\"(?=\t|\s|$)", f)
    tg_nums = findall(r"(?<=^|\s|\t)\d+(\.\d+)?(?=\t|\s|$)", f) # match free-standing numbers
    tg_flags = findall(r"(?<=^|\s|\t)<.*?>(?=\t|\s|$)", f) # match free-standing flags

    deleteat!(tg_nums, findall(x -> in_quotes(x, tg_quotes), tg_nums))
    deleteat!(tg_flags, findall(x -> in_quotes(x, tg_quotes), tg_flags))

    tg_raw = SubString.(f, sort!(vcat(tg_quotes, tg_nums, tg_flags)))
    is_TextGrid(tg_raw) || error("$file is not a valid TextGrid")
    tg_raw[5] == "<exists>" || return tg

    n_tier = parse(Int, tg_raw[6])
    tier_start = 7
    for i = 1:n_tier
        tier = build_tier(tg_raw, i, tier_start)
        step = tier.class == "interval" ? 3 : 2
        tier_start += tier.size * step + 5
        
        if nonempty
            deleteat!(tier.contents, findall(x -> strip(x.label) == "", tier.contents))
            resize_tier!(tier)
        end

        if tier.class == "interval" && intervals
            push!(tg, tier)
        end
        
        if tier.class == "point" && points
            push!(tg, tier)
        end
    end
    return renumber_tiers!(tg)
end

in_quotes(urange, quote_ranges) = reduce(|, map(x -> (urange.start ∈ x) & (urange.stop ∈ x), quote_ranges))

is_TextGrid(TG_raw) = (TG_raw[1] == "\"ooTextFile\"" && TG_raw[2] == "\"TextGrid\"")

function build_tier(TG_raw, num::Int, tier_start::Int)
    (class, name, xmin, xmax, size) = read_tier_preamble(TG_raw, tier_start)
    tier = Tier(num, class, name, size, xmin, xmax, Vector{Interval}())
    read_tier_contents!(tier, TG_raw, tier_start + 5)
    return tier
end

function read_tier_preamble(TG_raw, start::Int)
    class = chop(TG_raw[start], head = 1, tail = 1) == "IntervalTier" ? "interval" : "point"
    name = chop(TG_raw[start+1], head = 1, tail = 1)
    xmin = parse(Float64, TG_raw[start+2])
    xmax = parse(Float64, TG_raw[start+3])
    size = parse(Int, TG_raw[start+4])
    return class, name, xmin, xmax, size
end

function read_tier_contents!(tier::Tier, TG_raw, start::Int)
    curr = start
    step = tier.class == "interval" ? 3 : 2
    for i = 1:tier.size
        xmin = parse(Float64, TG_raw[curr])
        if tier.class == "point"
            xmax = xmin
            label = parse_TG_label(TG_raw[curr+1])
        else
            xmax = parse(Float64, TG_raw[curr+1])
            label = parse_TG_label(TG_raw[curr+2])
        end
        curr += step
        push!(tier.contents, Interval(tier.num, i, xmin, xmax, label))
    end
    tier
end

function parse_TG_label(text::AbstractString)
    label = chop(text, head = 1, tail = 1)
    replace(label, "\"\"" => "\"")
end

function unparse_TG_label(text::AbstractString)
    label = replace(text, "\"" => "\"\"")
    "\"" * label * "\""
end

# writing functions

"""
    write_TextGrid(file, tg)

Write the TextGrid object `tg` to a TextGrid file. Currently only writes in
full and not short text file format.
"""
function write_TextGrid(file::AbstractString, tg::TextGrid)
    f = Base.open(file, "w")

    write_TextGrid_preamble(f, tg)
    
    for tier in tg
        tmp = resize_tier(tier)
        write_tier_preamble(f, tmp)
        write_tier_contents(f, tmp)
    end
    
    close(f)
end

function write_TextGrid_preamble(f::IOStream, tg::TextGrid)
    tg_xmin, tg_xmax = extrema(tg)
    writeln(f, "File type = \"ooTextFile\"")
    writeln(f, "Object class = \"TextGrid\"")
    writeln(f, "")
    writeln(f, "xmin = $tg_xmin")
    writeln(f, "xmax = $tg_xmax")
    writeln(f, "tiers? <exists>")
    writeln(f, "size = $(length(tg))")
    writeln(f, "item []:")
end

function write_tier_preamble(f::IOStream, tier::Tier)
    tclass = tier.class == "interval" ? "IntervalTier" : "TextTier"
    writeln(f, "item [$(tier.num)]:", depth = 1)
    writeln(f, "class = \"$tclass\"", depth = 2)
    writeln(f, "name = \"$(tier.name)\"", depth = 2)
    writeln(f, "xmin = $(tier.xmin)", depth = 2)
    writeln(f, "xmax = $(tier.xmax)", depth = 2)
    writeln(f, "$(tier.class)s: size = $(tier.size)", depth = 2)
end

function write_tier_contents(f::IOStream, tier::Tier)
    if tier.class == "interval"
        write_interval_tier(f, tier)
    else
        write_point_tier(f, tier)
    end
end

function write_interval_tier(f::IOStream, tier::Tier)
    t = 0.0
    total = 0
    for interval in tier.contents
        if t < interval.xmin
            total += 1
            write_interval(f, Interval(0, total, t, interval.xmin, ""))
        end

        total += 1
        write_interval(f, reindex(interval, total))
        t = interval.xmax
    end

    if t < tier.xmax
        total += 1
        write_interval(f, Interval(0, total, t, tier.xmax, ""))
    end
end

function write_point_tier(f::IOStream, tier::Tier)
    for point in tier.contents
        write_point(f, point)
    end
end

function write_interval(f::IOStream, interval::Interval)
    writeln(f, "intervals [$(interval.index)]:", depth = 2)
    writeln(f, "xmin = $(interval.xmin)", depth = 3)
    writeln(f, "xmax = $(interval.xmax)", depth = 3)
    writeln(f, "text = " * unparse_TG_label(interval.label), depth = 3)
end

function write_point(f::IOStream, point::Interval)
    writeln(f, "points [$(point.index)]:", depth = 2)
    writeln(f, "number = $(point.xmin)", depth = 3)
    writeln(f, "mark = " * unparse_TG_label(point.label), depth = 3)
end

function writeln(f, x; depth = 0)
    write(f, repeat("\t", depth) * x * "\n")
end