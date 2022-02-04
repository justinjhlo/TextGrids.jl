# TextGrids

[![Build Status](https://github.com/justinjhlo/TextGrids.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/justinjhlo/TextGrids.jl/actions/workflows/CI.yml?query=branch%3Amain)

Reading, writing and manipulating [Praat](https://www.fon.hum.uva.nl/praat/) TextGrids in Julia.

## Status

The package currently suppports the reading of full and short forms of TextGrids (`read_TextGrid`), the writing of full form TextGrids (`write_TextGrid`) and a range of functions that come under hood of *Modify* and *Query* in Praat. Function names here generally (deliberately) do not match up with the corresponding commands in Praat.

This package is still experimental and under active development, so there may well be breaking changes to come.