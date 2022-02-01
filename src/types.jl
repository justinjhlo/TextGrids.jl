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

TextGrid = Vector{Tier}
