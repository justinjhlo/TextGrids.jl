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
    tg
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

function write_TextGrid(tg::TextGrid, file::AbstractString)
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

# function read_TextGrid_alt(file::AbstractString; intervals::Bool = true, points::Bool = true, nonempty::Bool = true)
#     # check if file exists
#     if !isfile(file)
#         error("$file does not exist")
#     end

#     f = Base.open(file)
#     # check if file is a TextGrid
#     if !is_TextGrid(f)
#         Base.close(f)
#         error("$file is not a TextGrid")
#     end

#     n_tier = read_TextGrid_preamble(f)

#     # initialise
#     tg = TextGrid()

#     # read TextGrid data from each tier
#     for i = 1:n_tier
#         tier = read_tier(f, i, intervals = intervals, points = points, nonempty = nonempty)
#         if !isnothing(tier)
#             push!(tg, tier)
#         end
#     end
#     Base.close(f)

#     tg
# end

# function is_TextGrid(f::IOStream)
#     line1 = readline(f)
#     line2 = readline(f)

#     contains(line1, "ooTextFile") & contains(line2, "TextGrid")
# end

# function read_TextGrid_preamble(f::IOStream)
#     # ignore 4 lines (empty, xmin, xmax, tiers?) and get size
#     for i = 1:4
#         line = readline(f)
#     end
#     line = readline(f)
#     n_tier = parse(Int, split(line, " = ")[2])
    
#     # ignore container line
#     line = readline(f)

#     n_tier
# end

# function read_tier(f::IOStream, tier::Int; intervals::Bool = true, points::Bool = true, nonempty::Bool = true)
#     (num, class, name, xmin, xmax, size) = read_tier_preamble(f)

#     if size == 0
#         return nothing
#     else
#         contents = read_tier_contents(f, tier, class, size, nonempty = nonempty)
#     end

#     if (class == "interval") & !intervals
#         return nothing
#     end

#     if (class == "point") & !points
#         return nothing
#     end

#     Tier(num, class, name, size, xmin, xmax, contents)
# end

# function read_tier_preamble(f::IOStream)
#         # num
#         line = readline(f)
#         num = parse(Int, split(line, r"\[|\]")[2])
    
#         # class
#         line = readline(f)
#         class = split(line, "\"")[2] == "IntervalTier" ? "interval" : "point"
    
#         # name
#         line = readline(f)
#         name = split(line, "\"")[2]
    
#         # xmin, xmax
#         line = readline(f)
#         xmin = parse(Float64, split(line, " = ")[2])
    
#         line = readline(f)
#         xmax = parse(Float64, split(line, " = ")[2])
    
#         # size of tier
#         line = readline(f)
#         size = parse(Int, split(line, " = ")[2])

#         num, class, name, xmin, xmax, size
# end

# function read_tier_contents(f::IOStream, tier::Int, class::AbstractString, size::Int; nonempty::Bool = true)
#     contents = Vector{Interval}(undef, size)
#     for i = 1:size
#         # index
#         line = readline(f)
#         index = parse(Int, split(line, r"\[|\]")[2])
    
#         # xmin, xmax
#         line = readline(f)
#         xmin = parse(Float64, split(line, " = ")[2])

#         # if interval tier, read line for xmax
#         # if point tier, xmax = xmin
#         if class == "interval"
#             line = readline(f)
#             xmax = parse(Float64, split(line, " = ")[2])
#         else
#             xmax = xmin
#         end

#         # label
#         line = readline(f)
#         label = parse_TG_label(strip(split(line, " = ", limit = 2)[2]))

#         contents[i] = Interval(tier, index, xmin, xmax, label)
#     end

#     # delete intervals/points with empty labels if nonempty is true, then recalculate size
#     if nonempty
#         deleteat!(contents, findall(x -> length(x.label) == 0, contents))
#     end
#     # size = length(contents)

#     # size, contents
#     contents
# end