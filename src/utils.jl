function extrema(tg::TextGrid)
    xmins = map(x -> x.xmin, tg)
    xmaxs = map(x -> x.xmax, tg)
    Base.extrema(vcat(xmins, xmaxs))
end

function reindex(interval::Interval, num::Int)
    interval_new = interval
    interval_new.index = num
    interval_new
end