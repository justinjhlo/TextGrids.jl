extrema(tg::TextGrid) = (minimum(x -> x.xmin, tg), maximum(x -> x.xmax, tg))

function reindex(interval::Interval, num::Int)
    interval_new = interval
    interval_new.index = num
    interval_new
end