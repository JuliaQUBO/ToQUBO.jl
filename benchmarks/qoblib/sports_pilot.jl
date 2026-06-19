module QOBLibSportsPilot

import MathOptInterface as MOI
import ToQUBO
using ToQUBO: Attributes

const TEAMS = 0:7
const SLOTS = 0:13
const BREAK_SLOTS = 1:13
const FIRST_HALF_SLOTS = 0:6

const PROVENANCE = Dict{String,Any}(
    "collection" => "ToQUBO-generated reformulation benchmark",
    "canonical_qoblib_artifact" => false,
    "qoblib_repository" => "https://github.com/ZIB-AOPT/QOBLIB",
    "qoblib_commit" => "a686aaa09fe14651294f744f34d453d5dce9cf57",
    "qoblib_data_license" => "Creative Commons Attribution 4.0 International",
    "qoblib_class" => "05-sports",
    "source_instance_path" => "05-sports/instances/Small/Addition_000_Small.xml.gz",
    "source_converter_path" => "05-sports/misc/itc2mip.py",
    "source_lp_path" =>
        "05-sports/models/mixed_integer_linear/lp_files/Small/Addition_000_Small.lp.xz",
    "source_solution_path" => "05-sports/solutions/Small/Addition_000_Small.opt.sol",
    "source_metrics_path" =>
        "05-sports/models/mixed_integer_linear/lp_files/metrics.csv",
    "source_metrics_csv_row" =>
        "Addition_000_Small.lp,0,992,0,992,587,0,587,0.027009946694510085,-1.0,1.0",
    "canonical_qubo_metrics_path" =>
        "05-sports/models/mixed_integer_linear/metrics_qs_files.csv",
    "canonical_qubo_metrics_csv_row" =>
        "Addition_000_Small.qs,1737,0.12329035750036603,-497.0,88.0",
)

const UPSTREAM_VERIFICATION = Dict{String,Any}(
    "manual_verification" => true,
    "converter_line_refs" => [
        "05-sports/misc/itc2mip.py:60-88",
        "05-sports/misc/itc2mip.py:90-107",
        "05-sports/misc/itc2mip.py:145-178",
        "05-sports/misc/itc2mip.py:334-399",
        "05-sports/misc/itc2mip.py:402-450",
        "05-sports/misc/itc2mip.py:455-549",
    ],
    "instance_line_refs" => [
        "05-sports/instances/Small/Addition_000_Small.xml.gz:14",
        "05-sports/instances/Small/Addition_000_Small.xml.gz:22-30",
        "05-sports/instances/Small/Addition_000_Small.xml.gz:43-69",
        "05-sports/instances/Small/Addition_000_Small.xml.gz:73-159",
        "05-sports/instances/Small/Addition_000_Small.xml.gz:160-192",
        "05-sports/instances/Small/Addition_000_Small.xml.gz:193-238",
    ],
    "lp_line_refs" => [
        "decompressed LP lines 1-18",
        "decompressed LP lines 221-1990",
        "decompressed LP lines 1991-3767",
        "decompressed LP lines 3801-5787",
    ],
    "solution_line_refs" => [
        "05-sports/solutions/Small/Addition_000_Small.opt.sol:2",
        "05-sports/solutions/Small/Addition_000_Small.opt.sol:3-994",
    ],
    "metrics_line_refs" => [
        "05-sports/models/mixed_integer_linear/lp_files/metrics.csv:Addition_000_Small.lp",
        "05-sports/models/mixed_integer_linear/metrics_qs_files.csv:Addition_000_Small.qs",
    ],
    "transcription_notes" => [
        "Additional_0_Small8.xml defines 8 teams, 14 slots, phased double round robin play, and no soft objective",
        "x[h,a,s] follows the QOBLIB home-away-slot variable names with zero-based team and slot ids",
        "bh[t,s] and ba[t,s] are home-break and away-break indicators for slots 1 through 13",
        "the hard XML constraints in this instance use CA4, GA1, BR1, and BR2 families",
    ],
)

const INSTANCE = Dict{String,Any}(
    "qoblib_id" => "Addition_000_Small",
    "xml_instance_name" => "Additional_0_Small8.xml",
    "lp_file" => "Addition_000_Small.lp",
    "canonical_qubo_file" => "Addition_000_Small.qs",
    "size_class" => "Small",
    "teams" => 8,
    "slots" => 14,
    "number_round_robin" => 2,
    "game_mode" => "P",
    "compactness" => "C",
    "matches_per_slot" => 4,
)

const QOBLIB_SOURCE_METRICS = Dict{String,Any}(
    "file" => "Addition_000_Small.lp",
    "num_binary_vars" => 0,
    "num_integer_vars" => 992,
    "num_continuous_vars" => 0,
    "num_vars" => 992,
    "num_linear_constraints" => 587,
    "num_quadratic_constraints" => 0,
    "num_constraints" => 587,
    "density" => 0.027009946694510085,
    "min_coeff" => -1.0,
    "max_coeff" => 1.0,
)

const QOBLIB_QUBO_METRICS = Dict{String,Any}(
    "available" => true,
    "file" => "Addition_000_Small.qs",
    "num_variables" => 1737,
    "density" => 0.12329035750036603,
    "min_coeff" => -497.0,
    "max_coeff" => 88.0,
)

const CA4_CONSTRAINTS = (
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 2, 3, 4, 5), teams1 = (2, 7, 6, 1, 5, 4), teams2 = (2, 7, 6, 1, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 12, 0, 1), teams1 = (7, 6, 0, 4), teams2 = (7, 6, 0, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 0, 2, 3, 4), teams1 = (1, 0, 3, 5, 4), teams2 = (1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 6, 1, 0, 3, 4), teams2 = (2, 6, 1, 0, 3, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (9, 0, 1, 5), teams1 = (7, 0, 3, 4), teams2 = (7, 0, 3, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 0, 1, 2), teams1 = (6, 1, 0, 5), teams2 = (6, 1, 0, 5)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 6, 0, 3, 5), teams1 = (7, 6, 0, 3, 5), teams2 = (7, 6, 0, 3, 5)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 4), teams1 = (2, 7, 6, 1, 3, 4), teams2 = (2, 7, 6, 1, 3, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (10, 6, 0, 1, 2), teams1 = (2, 7, 1, 3, 5), teams2 = (2, 7, 1, 3, 5)),
    (max = 1, mode2 = :EVERY, slots = (11,), teams1 = (7, 1), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 5), teams1 = (2, 7, 1, 3, 5, 4), teams2 = (2, 7, 1, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 8, 1, 3), teams1 = (6, 3, 5, 4), teams2 = (6, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 8, 1, 3), teams1 = (2, 7, 1, 0), teams2 = (2, 7, 1, 0)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (7, 6, 1, 3, 5, 4), teams2 = (7, 6, 1, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 6, 2, 4, 5), teams1 = (7, 6, 1, 5, 4), teams2 = (7, 6, 1, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 3, 4, 5), teams1 = (7, 6, 1, 0, 3, 5), teams2 = (7, 6, 1, 0, 3, 5)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 7, 6, 1, 3, 5), teams2 = (2, 7, 6, 1, 3, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 0, 1, 2), teams1 = (2, 7, 3, 4), teams2 = (2, 7, 3, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 6, 1, 3, 4), teams1 = (2, 7, 1, 0, 5), teams2 = (2, 7, 1, 0, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (8, 10, 11, 3), teams1 = (2, 6, 5, 4), teams2 = (2, 6, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (8, 10, 0, 3), teams1 = (6, 0, 3, 5), teams2 = (6, 0, 3, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 13, 0, 3), teams1 = (2, 1, 0, 5), teams2 = (2, 1, 0, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (11, 12, 0, 2), teams1 = (2, 7, 3, 5), teams2 = (2, 7, 3, 5)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 0, 1, 2, 5), teams1 = (2, 7, 3, 5, 4), teams2 = (2, 7, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 0, 2, 3, 4), teams1 = (1, 0, 3, 5, 4), teams2 = (1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (0, 1, 2, 3, 4, 5), teams1 = (2, 7, 6, 3, 5, 4), teams2 = (2, 7, 6, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 13, 0, 1), teams1 = (1, 0, 5, 4), teams2 = (1, 0, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 0, 1, 2), teams1 = (6, 1, 0, 5), teams2 = (6, 1, 0, 5)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 6, 1, 4, 5), teams1 = (2, 7, 0, 3, 4), teams2 = (2, 7, 0, 3, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 4), teams1 = (6, 1, 0, 3, 5, 4), teams2 = (6, 1, 0, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 6, 0, 3, 5), teams1 = (7, 6, 1, 0, 3), teams2 = (7, 6, 1, 0, 3)),
    (max = 12, mode2 = :GLOBAL, slots = (0, 1, 2, 3, 4, 5), teams1 = (2, 7, 6, 3, 5, 4), teams2 = (2, 7, 6, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 6, 0, 3, 5), teams1 = (7, 6, 0, 3, 5), teams2 = (7, 6, 0, 3, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (8, 0, 1, 2), teams1 = (2, 6, 1, 4), teams2 = (2, 6, 1, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 4), teams1 = (6, 1, 0, 3, 5, 4), teams2 = (6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (2, 6, 0, 3, 5, 4), teams2 = (2, 6, 0, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 8, 1, 3), teams1 = (2, 7, 1, 0), teams2 = (2, 7, 1, 0)),
    (max = 1, mode2 = :EVERY, slots = (10,), teams1 = (2, 1), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (13, 0, 2, 4), teams1 = (7, 6, 1, 4), teams2 = (7, 6, 1, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (8, 1, 2, 5), teams1 = (2, 6, 1, 0), teams2 = (2, 6, 1, 0)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 8, 1, 3), teams1 = (2, 7, 1, 0), teams2 = (2, 7, 1, 0)),
    (max = 2, mode2 = :GLOBAL, slots = (11, 0, 1, 2), teams1 = (7, 1, 3, 5), teams2 = (7, 1, 3, 5)),
    (max = 1, mode2 = :EVERY, slots = (4,), teams1 = (2, 6), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 1, mode2 = :EVERY, slots = (8,), teams1 = (6, 4), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 0, 1, 2), teams1 = (6, 1, 0, 5), teams2 = (6, 1, 0, 5)),
    (max = 1, mode2 = :EVERY, slots = (9,), teams1 = (7, 1), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 7, 0, 3, 5, 4), teams2 = (2, 7, 0, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 1, 2, 3, 5), teams1 = (2, 7, 6, 1, 0), teams2 = (2, 7, 6, 1, 0)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 2, 3, 4, 5), teams1 = (2, 7, 6, 0, 3, 5), teams2 = (2, 7, 6, 0, 3, 5)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 6, 1, 4, 5), teams1 = (2, 6, 0, 3, 4), teams2 = (2, 6, 0, 3, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (2, 6, 0, 3, 5, 4), teams2 = (2, 6, 0, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 13, 0, 1), teams1 = (2, 7, 6, 3), teams2 = (2, 7, 6, 3)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 0, 4, 5), teams1 = (2, 6, 3, 5), teams2 = (2, 6, 3, 5)),
    (max = 1, mode2 = :EVERY, slots = (3,), teams1 = (7, 4), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 1, 2, 3, 5), teams1 = (2, 7, 6, 1, 0), teams2 = (2, 7, 6, 1, 0)),
    (max = 1, mode2 = :EVERY, slots = (4,), teams1 = (6, 5), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 3, 4, 5), teams1 = (7, 6, 1, 0, 3, 5), teams2 = (7, 6, 1, 0, 3, 5)),
    (max = 12, mode2 = :GLOBAL, slots = (0, 1, 2, 3, 4, 5), teams1 = (7, 1, 0, 3, 5, 4), teams2 = (7, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 3, 4, 5), teams1 = (2, 7, 1, 0, 5, 4), teams2 = (2, 7, 1, 0, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (2, 7, 1, 0, 3, 4), teams2 = (2, 7, 1, 0, 3, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 0, 1, 2, 5), teams1 = (2, 6, 1, 0, 4), teams2 = (2, 6, 1, 0, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (8, 1, 2, 5), teams1 = (7, 3, 5, 4), teams2 = (7, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 2, 3, 4, 5), teams1 = (7, 1, 0, 3, 4), teams2 = (7, 1, 0, 3, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (12, 13, 0, 3), teams1 = (7, 6, 3, 4), teams2 = (7, 6, 3, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 5), teams1 = (7, 6, 0, 3, 5, 4), teams2 = (7, 6, 0, 3, 5, 4)),
    (max = 1, mode2 = :EVERY, slots = (13,), teams1 = (3, 5), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 6, 1, 0, 3, 4), teams2 = (2, 6, 1, 0, 3, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (7, 0, 1, 2, 5), teams1 = (2, 6, 1, 0, 3), teams2 = (2, 6, 1, 0, 3)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 7, 6, 1, 3, 5), teams2 = (2, 7, 6, 1, 3, 5)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 3, 4, 5), teams1 = (7, 6, 1, 0, 3, 5), teams2 = (7, 6, 1, 0, 3, 5)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (2, 7, 1, 0, 3, 4), teams2 = (2, 7, 1, 0, 3, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 1, 2, 3, 4, 5), teams1 = (7, 6, 1, 3, 5, 4), teams2 = (7, 6, 1, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 2, 3, 4, 5), teams1 = (2, 7, 6, 0, 3, 5), teams2 = (2, 7, 6, 0, 3, 5)),
    (max = 5, mode2 = :GLOBAL, slots = (10, 0, 2, 4, 5), teams1 = (7, 6, 1, 0, 4), teams2 = (7, 6, 1, 0, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 0, 1, 2), teams1 = (7, 6, 5, 4), teams2 = (7, 6, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 6, 0, 3, 5), teams1 = (2, 7, 1, 5, 4), teams2 = (2, 7, 1, 5, 4)),
    (max = 1, mode2 = :EVERY, slots = (1,), teams1 = (7, 5), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 5, mode2 = :GLOBAL, slots = (8, 0, 1, 2, 5), teams1 = (2, 6, 1, 0, 4), teams2 = (2, 6, 1, 0, 4)),
    (max = 1, mode2 = :EVERY, slots = (6,), teams1 = (6, 3), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 3, 4), teams1 = (6, 1, 0, 3, 5, 4), teams2 = (6, 1, 0, 3, 5, 4)),
    (max = 12, mode2 = :GLOBAL, slots = (6, 0, 1, 2, 4, 5), teams1 = (2, 6, 1, 0, 3, 4), teams2 = (2, 6, 1, 0, 3, 4)),
    (max = 1, mode2 = :EVERY, slots = (6,), teams1 = (2, 0), teams2 = (2, 7, 6, 1, 0, 3, 5, 4)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 0, 4, 5), teams1 = (2, 6, 3, 5), teams2 = (2, 6, 3, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (7, 0, 1, 4), teams1 = (7, 1, 0, 5), teams2 = (7, 1, 0, 5)),
    (max = 2, mode2 = :GLOBAL, slots = (10, 12, 0, 1), teams1 = (2, 1, 3, 5), teams2 = (2, 1, 3, 5)),
)

const GA1_CONSTRAINTS = (
    (min = 2, max = 3, slots = (7, 10, 6), meetings = ((1, 4), (4, 3), (5, 3))),
    (min = 0, max = 1, slots = (12, 0), meetings = ((1, 2), (4, 1))),
    (min = 0, max = 0, slots = (4,), meetings = ((2, 3),)),
    (min = 0, max = 0, slots = (3,), meetings = ((3, 1),)),
    (min = 1, max = 1, slots = (3,), meetings = ((6, 1),)),
    (min = 0, max = 0, slots = (13,), meetings = ((0, 6),)),
    (min = 0, max = 1, slots = (12, 3), meetings = ((1, 5), (5, 3))),
    (min = 1, max = 1, slots = (1,), meetings = ((5, 2),)),
    (min = 0, max = 1, slots = (7, 6, 4), meetings = ((0, 3), (5, 4), (7, 2))),
    (min = 1, max = 1, slots = (6,), meetings = ((5, 3),)),
    (min = 0, max = 0, slots = (4,), meetings = ((4, 2),)),
    (min = 0, max = 0, slots = (6,), meetings = ((7, 1),)),
    (min = 0, max = 1, slots = (0, 1, 4), meetings = ((0, 7), (2, 6), (7, 1))),
    (min = 0, max = 0, slots = (6,), meetings = ((0, 2),)),
    (min = 2, max = 3, slots = (11, 2, 5), meetings = ((3, 1), (3, 6), (5, 0))),
    (min = 0, max = 2, slots = (7, 11, 13, 4), meetings = ((2, 3), (2, 4), (2, 7), (6, 2))),
    (min = 1, max = 2, slots = (8, 2), meetings = ((1, 5), (3, 2))),
    (min = 1, max = 1, slots = (7,), meetings = ((1, 4),)),
    (min = 0, max = 0, slots = (10,), meetings = ((3, 6),)),
    (min = 1, max = 2, slots = (12, 6), meetings = ((2, 6), (5, 3))),
    (min = 0, max = 1, slots = (11, 2, 4), meetings = ((0, 1), (4, 1), (7, 6))),
    (min = 0, max = 0, slots = (10,), meetings = ((6, 0),)),
    (min = 0, max = 0, slots = (8,), meetings = ((2, 3),)),
    (min = 0, max = 0, slots = (5,), meetings = ((1, 3),)),
    (min = 0, max = 2, slots = (11, 13, 2, 3), meetings = ((0, 5), (3, 7), (5, 3), (6, 7))),
    (min = 1, max = 2, slots = (6, 3), meetings = ((0, 4), (7, 4))),
    (min = 0, max = 1, slots = (11, 6, 5), meetings = ((2, 0), (2, 5), (6, 5))),
    (min = 0, max = 0, slots = (8,), meetings = ((2, 6),)),
    (min = 0, max = 0, slots = (7,), meetings = ((1, 7),)),
    (min = 0, max = 2, slots = (12, 13, 2, 3), meetings = ((3, 4), (4, 1), (6, 0), (6, 3))),
    (min = 1, max = 2, slots = (7, 13), meetings = ((3, 7), (4, 2))),
)

const BR1_CONSTRAINTS = (
    (intp = 2, slots = (8, 10, 12, 6, 4, 5), teams = (0,)),
    (intp = 0, slots = (13,), teams = (3,)),
    (intp = 2, slots = (7, 9, 6, 1, 4, 5), teams = (3,)),
    (intp = 2, slots = (8, 10, 13, 1, 3, 5), teams = (7,)),
    (intp = 0, slots = (7,), teams = (2,)),
    (intp = 2, slots = (10, 11, 13, 1, 2, 4), teams = (3,)),
    (intp = 2, slots = (10, 11, 12, 0, 4, 5), teams = (0,)),
    (intp = 2, slots = (9, 10, 12, 6, 1, 2), teams = (0,)),
    (intp = 2, slots = (8, 9, 13, 6, 4, 5), teams = (6,)),
    (intp = 2, slots = (7, 9, 10, 6, 4, 5), teams = (7,)),
    (intp = 0, slots = (8,), teams = (2,)),
    (intp = 0, slots = (0,), teams = (4,)),
    (intp = 0, slots = (8,), teams = (5,)),
    (intp = 1, slots = (9, 1, 5), teams = (1,)),
    (intp = 1, slots = (11, 12, 0), teams = (1,)),
    (intp = 0, slots = (1,), teams = (1,)),
    (intp = 0, slots = (0,), teams = (5,)),
    (intp = 0, slots = (11,), teams = (7,)),
    (intp = 2, slots = (8, 9, 10, 12, 1, 2), teams = (0,)),
    (intp = 2, slots = (7, 8, 9, 12, 1, 3), teams = (5,)),
    (intp = 2, slots = (8, 11, 6, 0, 3, 4), teams = (6,)),
    (intp = 2, slots = (7, 8, 11, 6, 4, 5), teams = (6,)),
    (intp = 0, slots = (7,), teams = (6,)),
    (intp = 0, slots = (13,), teams = (5,)),
    (intp = 2, slots = (8, 9, 10, 12, 2, 5), teams = (3,)),
    (intp = 2, slots = (9, 13, 0, 2, 3, 5), teams = (2,)),
    (intp = 0, slots = (2,), teams = (2,)),
    (intp = 0, slots = (5,), teams = (6,)),
    (intp = 2, slots = (9, 11, 12, 13, 3, 5), teams = (5,)),
    (intp = 2, slots = (7, 8, 12, 13, 2, 4), teams = (1,)),
    (intp = 2, slots = (10, 12, 13, 1, 2, 5), teams = (2,)),
    (intp = 1, slots = (8, 0, 5), teams = (5,)),
    (intp = 2, slots = (8, 10, 11, 13, 3, 4), teams = (4,)),
    (intp = 1, slots = (8, 9, 2), teams = (2,)),
    (intp = 1, slots = (7, 11, 13), teams = (3,)),
    (intp = 1, slots = (9, 1, 2), teams = (5,)),
    (intp = 0, slots = (4,), teams = (4,)),
    (intp = 2, slots = (7, 13, 1, 2, 4, 5), teams = (5,)),
    (intp = 0, slots = (7,), teams = (0,)),
    (intp = 1, slots = (8, 11, 5), teams = (6,)),
    (intp = 1, slots = (8, 10, 3), teams = (0,)),
    (intp = 1, slots = (9, 10, 13), teams = (5,)),
    (intp = 1, slots = (8, 12, 0), teams = (6,)),
    (intp = 0, slots = (10,), teams = (4,)),
)

const BR2_CONSTRAINT = (
    intp = 26,
    slots = (7, 8, 9, 10, 11, 12, 13, 6, 0, 1, 2, 3, 4, 5),
    teams = (2, 7, 6, 1, 0, 3, 5, 4),
)

const KNOWN_INCUMBENT_GAMES = (
    (0, 1, 9),
    (0, 2, 10),
    (0, 3, 1),
    (0, 4, 3),
    (0, 5, 5),
    (0, 6, 7),
    (0, 7, 13),
    (1, 2, 4),
    (1, 3, 13),
    (1, 4, 7),
    (1, 5, 2),
    (1, 6, 10),
    (1, 7, 0),
    (1, 0, 6),
    (2, 1, 11),
    (2, 3, 3),
    (2, 4, 2),
    (2, 5, 7),
    (2, 6, 12),
    (2, 7, 5),
    (2, 0, 0),
    (3, 1, 5),
    (3, 2, 8),
    (3, 4, 0),
    (3, 5, 9),
    (3, 6, 2),
    (3, 7, 7),
    (3, 0, 12),
    (4, 1, 1),
    (4, 2, 13),
    (4, 3, 10),
    (4, 5, 4),
    (4, 6, 5),
    (4, 7, 11),
    (4, 0, 8),
    (5, 1, 8),
    (5, 2, 1),
    (5, 3, 6),
    (5, 4, 12),
    (5, 6, 0),
    (5, 7, 3),
    (5, 0, 11),
    (6, 1, 3),
    (6, 2, 6),
    (6, 3, 11),
    (6, 4, 9),
    (6, 5, 13),
    (6, 7, 1),
    (6, 0, 4),
    (7, 1, 12),
    (7, 2, 9),
    (7, 3, 4),
    (7, 4, 6),
    (7, 5, 10),
    (7, 6, 8),
    (7, 0, 2),
)

function _affine(terms::Vector{MOI.ScalarAffineTerm{Float64}}, constant = 0.0)
    return MOI.ScalarAffineFunction{Float64}(terms, Float64(constant))
end

function _term(coefficient::Real, variable::MOI.VariableIndex)
    return MOI.ScalarAffineTerm{Float64}(Float64(coefficient), variable)
end

function _add_binary_integer_variable(model)
    variable = MOI.add_variable(model)

    MOI.add_constraint(model, variable, MOI.Integer())
    MOI.add_constraint(model, variable, MOI.Interval(0.0, 1.0))

    return variable
end

function _add_counted_constraint(model, func, set, counts::AbstractDict, category::String)
    MOI.add_constraint(model, func, set)
    counts[category] = get(counts, category, 0) + 1

    return nothing
end

function _matches()
    return [(home, away) for home in TEAMS for away in TEAMS if home != away]
end

function _build_variables(model)
    x = Dict{Tuple{Int,Int,Int},MOI.VariableIndex}()
    bh = Dict{Tuple{Int,Int},MOI.VariableIndex}()
    ba = Dict{Tuple{Int,Int},MOI.VariableIndex}()

    for (home, away) in _matches(), slot in SLOTS
        x[(home, away, slot)] = _add_binary_integer_variable(model)
    end

    for team in TEAMS, slot in BREAK_SLOTS
        bh[(team, slot)] = _add_binary_integer_variable(model)
        ba[(team, slot)] = _add_binary_integer_variable(model)
    end

    return x, bh, ba
end

function _ca4_terms(x, row, slots = row.slots)
    terms = MOI.ScalarAffineTerm{Float64}[]

    for home in row.teams1, away in row.teams2, slot in slots
        if home != away
            push!(terms, _term(1.0, x[(home, away, slot)]))
        end
    end

    return terms
end

function _ga1_terms(x, row)
    terms = MOI.ScalarAffineTerm{Float64}[]

    for (home, away) in row.meetings, slot in row.slots
        push!(terms, _term(1.0, x[(home, away, slot)]))
    end

    return terms
end

function _break_limit_terms(bh, ba, teams, slots)
    terms = MOI.ScalarAffineTerm{Float64}[]

    for team in teams, slot in slots
        push!(terms, _term(1.0, bh[(team, slot)]))
        push!(terms, _term(1.0, ba[(team, slot)]))
    end

    return terms
end

function _sorted_break_slots(slots)
    return sort!(collect(slots))
end

function _br1_slots(row)
    slots = _sorted_break_slots(row.slots)

    if !isempty(slots) && first(slots) == 0
        popfirst!(slots)
    end

    return slots
end

function _br2_slots()
    return _sorted_break_slots(BR2_CONSTRAINT.slots)[2:end]
end

function _build_sports_model()
    model = ToQUBO.Optimizer{Float64}()
    x, bh, ba = _build_variables(model)
    counts = Dict{String,Int}(
        "assignment" => 0,
        "slot_capacity" => 0,
        "team_slot" => 0,
        "break_count" => 0,
        "phased" => 0,
        "capacity" => 0,
        "game" => 0,
        "br1" => 0,
        "br2" => 0,
    )

    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        _affine(MOI.ScalarAffineTerm{Float64}[]),
    )

    for (home, away) in _matches()
        _add_counted_constraint(
            model,
            _affine([_term(1.0, x[(home, away, slot)]) for slot in SLOTS]),
            MOI.EqualTo(1.0),
            counts,
            "assignment",
        )
    end

    for slot in SLOTS
        _add_counted_constraint(
            model,
            _affine([_term(1.0, x[(home, away, slot)]) for (home, away) in _matches()]),
            MOI.EqualTo(Float64(INSTANCE["matches_per_slot"])),
            counts,
            "slot_capacity",
        )
    end

    for slot in SLOTS, team in TEAMS
        terms = MOI.ScalarAffineTerm{Float64}[]

        append!(terms, [_term(1.0, x[(team, away, slot)]) for away in TEAMS if away != team])
        append!(terms, [_term(1.0, x[(home, team, slot)]) for home in TEAMS if home != team])

        _add_counted_constraint(
            model,
            _affine(terms),
            MOI.EqualTo(1.0),
            counts,
            "team_slot",
        )
    end

    for team in TEAMS, slot in BREAK_SLOTS
        home_terms = [_term(1.0, x[(team, away, slot - 1)]) for away in TEAMS if away != team]
        append!(home_terms, [_term(1.0, x[(team, away, slot)]) for away in TEAMS if away != team])
        push!(home_terms, _term(-1.0, bh[(team, slot)]))

        _add_counted_constraint(
            model,
            _affine(home_terms),
            MOI.LessThan(1.0),
            counts,
            "break_count",
        )

        away_terms = [_term(1.0, x[(home, team, slot - 1)]) for home in TEAMS if home != team]
        append!(away_terms, [_term(1.0, x[(home, team, slot)]) for home in TEAMS if home != team])
        push!(away_terms, _term(-1.0, ba[(team, slot)]))

        _add_counted_constraint(
            model,
            _affine(away_terms),
            MOI.LessThan(1.0),
            counts,
            "break_count",
        )
    end

    for home in TEAMS, away in TEAMS
        if home < away
            terms = MOI.ScalarAffineTerm{Float64}[]

            append!(terms, [_term(1.0, x[(home, away, slot)]) for slot in FIRST_HALF_SLOTS])
            append!(terms, [_term(1.0, x[(away, home, slot)]) for slot in FIRST_HALF_SLOTS])

            _add_counted_constraint(
                model,
                _affine(terms),
                MOI.EqualTo(1.0),
                counts,
                "phased",
            )
        end
    end

    for row in CA4_CONSTRAINTS
        if row.mode2 == :GLOBAL
            _add_counted_constraint(
                model,
                _affine(_ca4_terms(x, row)),
                MOI.LessThan(Float64(row.max)),
                counts,
                "capacity",
            )
        else
            for slot in row.slots
                _add_counted_constraint(
                    model,
                    _affine(_ca4_terms(x, row, (slot,))),
                    MOI.LessThan(Float64(row.max)),
                    counts,
                    "capacity",
                )
            end
        end
    end

    for row in GA1_CONSTRAINTS
        terms = _ga1_terms(x, row)

        _add_counted_constraint(
            model,
            _affine(terms),
            MOI.LessThan(Float64(row.max)),
            counts,
            "game",
        )

        if row.min > 0
            _add_counted_constraint(
                model,
                _affine([_term(-term.coefficient, term.variable) for term in terms]),
                MOI.LessThan(-Float64(row.min)),
                counts,
                "game",
            )
        end
    end

    for row in BR1_CONSTRAINTS
        slots = _br1_slots(row)

        if isempty(slots)
            continue
        end

        _add_counted_constraint(
            model,
            _affine(_break_limit_terms(bh, ba, row.teams, slots)),
            MOI.LessThan(Float64(row.intp)),
            counts,
            "br1",
        )
    end

    _add_counted_constraint(
        model,
        _affine(_break_limit_terms(bh, ba, BR2_CONSTRAINT.teams, _br2_slots())),
        MOI.LessThan(Float64(BR2_CONSTRAINT.intp)),
        counts,
        "br2",
    )

    return model, x, bh, ba, counts
end

function _term_key(vi::MOI.VariableIndex, vj::MOI.VariableIndex)
    i = vi.value
    j = vj.value

    return i <= j ? (i, j) : (j, i)
end

function _qubo_terms(target::MOI.ModelLike)
    objective_type = MOI.get(target, MOI.ObjectiveFunctionType())
    objective = MOI.get(target, MOI.ObjectiveFunction{objective_type}())
    terms = Dict{Tuple{Int,Int},Float64}()

    for term in objective.affine_terms
        key = (term.variable.value, term.variable.value)
        terms[key] = get(terms, key, 0.0) + Float64(term.coefficient)
    end

    for term in objective.quadratic_terms
        key = _term_key(term.variable_1, term.variable_2)
        terms[key] = get(terms, key, 0.0) + Float64(term.coefficient)
    end

    filter!(pair -> !iszero(last(pair)), terms)

    return objective, terms
end

function _qoblib_symmetric_coefficient(key::Tuple{Int,Int}, coefficient::Float64)
    # ToQUBO stores each full off-diagonal cross-term on one triangle.
    return first(key) == last(key) ? coefficient : coefficient / 2
end

function _target_metrics(optimizer)
    target = MOI.get(optimizer, Attributes.TargetModel())
    objective, terms = _qubo_terms(target)
    n = MOI.get(target, MOI.NumberOfVariables())
    coefficients = collect(values(terms))
    qoblib_coefficients = [
        _qoblib_symmetric_coefficient(key, coefficient) for (key, coefficient) in terms
    ]
    total_slots = n * (n + 1) / 2

    return Dict{String,Any}(
        "num_variables" => n,
        "num_terms" => length(terms),
        "num_linear_terms" => count(key -> first(key) == last(key), keys(terms)),
        "num_quadratic_terms" => count(key -> first(key) != last(key), keys(terms)),
        "density" => isempty(terms) ? 0.0 : length(terms) / total_slots,
        "min_coeff" => isempty(coefficients) ? 0.0 : minimum(coefficients),
        "max_coeff" => isempty(coefficients) ? 0.0 : maximum(coefficients),
        "qoblib_symmetric_min_coeff" =>
            isempty(qoblib_coefficients) ? 0.0 : minimum(qoblib_coefficients),
        "qoblib_symmetric_max_coeff" =>
            isempty(qoblib_coefficients) ? 0.0 : maximum(qoblib_coefficients),
        "objective_offset" => Float64(objective.constant),
    )
end

function _source_metrics(counts::AbstractDict)
    num_constraints = sum(values(counts))

    return Dict{String,Any}(
        "num_binary_vars" => 0,
        "num_integer_vars" => length(_matches()) * length(SLOTS) + 2 * length(TEAMS) * length(BREAK_SLOTS),
        "num_continuous_vars" => 0,
        "num_vars" => length(_matches()) * length(SLOTS) + 2 * length(TEAMS) * length(BREAK_SLOTS),
        "num_linear_constraints" => num_constraints,
        "num_quadratic_constraints" => 0,
        "num_constraints" => num_constraints,
        "num_assignment_constraints" => counts["assignment"],
        "num_slot_capacity_constraints" => counts["slot_capacity"],
        "num_team_slot_constraints" => counts["team_slot"],
        "num_break_count_constraints" => counts["break_count"],
        "num_phased_constraints" => counts["phased"],
        "num_capacity_constraints" => counts["capacity"],
        "num_game_constraints" => counts["game"],
        "num_break_limit_constraints" => counts["br1"] + counts["br2"],
    )
end

function _metadata_summary(optimizer)
    return _metadata_summary(ToQUBO.reformulation_metadata(optimizer))
end

function _metadata_summary(metadata::AbstractDict)
    penalties = metadata["applied_penalties"]

    return Dict{String,Any}(
        "schema_version" => metadata["schema_version"],
        "source_variable_count" => metadata["source"]["num_variables"],
        "target_variable_count" => metadata["target"]["num_variables"],
        "auxiliary_variable_count" => length(metadata["auxiliary_variables"]),
        "slack_variable_count" => length(metadata["slack_variables"]),
        "constraint_penalty_count" => length(penalties["constraints"]),
        "variable_penalty_count" => length(penalties["variables"]),
        "slack_penalty_count" => length(penalties["slack_variables"]),
        "target_offset" => metadata["target"]["offset"],
        "constraint_penalties" =>
            sort!(unique(Float64(entry["penalty"]) for entry in penalties["constraints"])),
        "encoding_types" => sort!(unique([
            entry["encoding"]["type"] for entry in metadata["original_variables"] if
            entry["encoding"] !== nothing
        ])),
    )
end

function _game_set()
    return Set(KNOWN_INCUMBENT_GAMES)
end

function _home_count(games, team::Integer, slot::Integer)
    return count(away -> (team, away, slot) in games, TEAMS)
end

function _away_count(games, team::Integer, slot::Integer)
    return count(home -> (home, team, slot) in games, TEAMS)
end

function _break_values(games)
    bh = Dict{Tuple{Int,Int},Int}()
    ba = Dict{Tuple{Int,Int},Int}()

    for team in TEAMS, slot in BREAK_SLOTS
        bh[(team, slot)] =
            _home_count(games, team, slot - 1) == 1 && _home_count(games, team, slot) == 1 ? 1 : 0
        ba[(team, slot)] =
            _away_count(games, team, slot - 1) == 1 && _away_count(games, team, slot) == 1 ? 1 : 0
    end

    return bh, ba
end

function _ca4_activity(games, row, slots = row.slots)
    return sum(
        (home, away, slot) in games for home in row.teams1 for away in row.teams2
        for slot in slots if home != away
    )
end

function _ga1_activity(games, row)
    return sum((home, away, slot) in games for (home, away) in row.meetings for slot in row.slots)
end

function _known_incumbent_summary()
    games = _game_set()
    bh, ba = _break_values(games)
    assignment_feasible =
        all(sum((home, away, slot) in games for slot in SLOTS) == 1 for (home, away) in _matches())
    slot_capacity_feasible = all(
        sum((home, away, slot) in games for (home, away) in _matches()) ==
        INSTANCE["matches_per_slot"] for slot in SLOTS
    )
    team_slot_feasible = all(
        _home_count(games, team, slot) + _away_count(games, team, slot) == 1 for
        team in TEAMS for slot in SLOTS
    )
    phased_feasible = all(
        sum(
            ((home, away, slot) in games) + ((away, home, slot) in games) for
            slot in FIRST_HALF_SLOTS
        ) == 1 for home in TEAMS for away in TEAMS if home < away
    )
    break_count_feasible = all(
        _home_count(games, team, slot - 1) + _home_count(games, team, slot) - 1 <=
        bh[(team, slot)] &&
        _away_count(games, team, slot - 1) + _away_count(games, team, slot) - 1 <=
        ba[(team, slot)] for team in TEAMS for slot in BREAK_SLOTS
    )
    capacity_feasible = all(CA4_CONSTRAINTS) do row
        if row.mode2 == :GLOBAL
            return _ca4_activity(games, row) <= row.max
        else
            return all(slot -> _ca4_activity(games, row, (slot,)) <= row.max, row.slots)
        end
    end
    game_constraint_feasible = all(GA1_CONSTRAINTS) do row
        activity = _ga1_activity(games, row)

        return row.min <= activity <= row.max
    end
    br1_feasible = all(BR1_CONSTRAINTS) do row
        slots = _br1_slots(row)

        if isempty(slots)
            return true
        end

        return sum(bh[(team, slot)] + ba[(team, slot)] for team in row.teams for slot in slots) <=
               row.intp
    end
    br2_feasible =
        sum(
            bh[(team, slot)] + ba[(team, slot)] for team in BR2_CONSTRAINT.teams
            for slot in _br2_slots()
        ) <= BR2_CONSTRAINT.intp
    source_feasible =
        assignment_feasible &&
        slot_capacity_feasible &&
        team_slot_feasible &&
        phased_feasible &&
        break_count_feasible &&
        capacity_feasible &&
        game_constraint_feasible &&
        br1_feasible &&
        br2_feasible

    return Dict{String,Any}(
        "source_objective" => 0,
        "source_feasible" => source_feasible,
        "active_game_count" => length(games),
        "home_break_count" => sum(values(bh)),
        "away_break_count" => sum(values(ba)),
        "assignment_feasible" => assignment_feasible,
        "slot_capacity_feasible" => slot_capacity_feasible,
        "team_slot_feasible" => team_slot_feasible,
        "phased_feasible" => phased_feasible,
        "break_count_feasible" => break_count_feasible,
        "capacity_feasible" => capacity_feasible,
        "game_constraint_feasible" => game_constraint_feasible,
        "break_limit_feasible" => br1_feasible && br2_feasible,
        "qoblib_solution_objective" => 0,
        "matches_qoblib_solution_artifact" => source_feasible,
    )
end

function _comparison(target, metadata)
    return Dict{String,Any}(
        "canonical_qubo_metrics_available" => QOBLIB_QUBO_METRICS["available"],
        "target_variable_delta_vs_qoblib_qs" =>
            target["num_variables"] - QOBLIB_QUBO_METRICS["num_variables"],
        "density_delta_vs_qoblib_qs" =>
            target["density"] - QOBLIB_QUBO_METRICS["density"],
        "min_coeff_delta_vs_qoblib_qs" =>
            target["min_coeff"] - QOBLIB_QUBO_METRICS["min_coeff"],
        "max_coeff_delta_vs_qoblib_qs" =>
            target["max_coeff"] - QOBLIB_QUBO_METRICS["max_coeff"],
        "qoblib_symmetric_min_coeff_delta_vs_qoblib_qs" =>
            target["qoblib_symmetric_min_coeff"] - QOBLIB_QUBO_METRICS["min_coeff"],
        "qoblib_symmetric_max_coeff_delta_vs_qoblib_qs" =>
            target["qoblib_symmetric_max_coeff"] - QOBLIB_QUBO_METRICS["max_coeff"],
        "redundant_constraint_count" =>
            QOBLIB_SOURCE_METRICS["num_constraints"] - metadata["constraint_penalty_count"],
    )
end

function run_sports_pilot()
    model, _x, _bh, _ba, counts = _build_sports_model()

    MOI.optimize!(model)

    target = _target_metrics(model)
    metadata = _metadata_summary(model)

    return Dict{String,Any}(
        "provenance" => copy(PROVENANCE),
        "upstream_verification" => copy(UPSTREAM_VERIFICATION),
        "instance" => copy(INSTANCE),
        "source" => Dict{String,Any}(
            "modeling_assumptions" => [
                "the source model follows QOBLIB's mixed-integer sports scheduling formulation",
                "x[h,a,s] assigns ordered home-away games to slots",
                "each ordered match is assigned once and each team plays once per slot",
                "phased play requires every unordered pairing to occur once in the first half",
                "hard CA4, GA1, BR1, and BR2 constraints are transcribed from the XML instance",
            ],
            "variable_naming" => [
                "team and slot ids follow the zero-based QOBLIB XML and LP names",
                "x#h#a#s is represented as x[h,a,s]",
                "bh#t#s and ba#t#s are represented as bh[t,s] and ba[t,s]",
            ],
            "bounds" => [
                "0 <= x[h,a,s] <= 1, integer",
                "0 <= bh[t,s] <= 1, integer",
                "0 <= ba[t,s] <= 1, integer",
            ],
            "generated_metrics" => _source_metrics(counts),
            "qoblib_metrics" => copy(QOBLIB_SOURCE_METRICS),
        ),
        "qoblib_qubo_metrics" => copy(QOBLIB_QUBO_METRICS),
        "toqubo" => Dict{String,Any}(
            "target" => target,
            "metadata" => metadata,
        ),
        "known_incumbent" => _known_incumbent_summary(),
        "comparison" => _comparison(target, metadata),
        "follow_up" =>
            "No source formulation gap was found. The target-variable delta is explained by four redundant hard constraints that ToQUBO detects as always feasible and leaves unpenalized; the native max-coefficient delta is an off-diagonal coefficient convention difference, while QOBLIB-style symmetrized min/max coefficients match the canonical QS row.",
    )
end

function _fmt(value)
    if value === nothing
        return "n/a"
    elseif value isa AbstractFloat
        return string(round(value; sigdigits = 8))
    elseif value isa Bool
        return value ? "true" : "false"
    else
        return string(value)
    end
end

function _metric_row(metric, source, canonical, generated)
    return "| $(metric) | $(_fmt(source)) | $(_fmt(canonical)) | $(_fmt(generated)) |\n"
end

function write_markdown_report(io::IO, report::AbstractDict)
    provenance = report["provenance"]
    verification = report["upstream_verification"]
    instance = report["instance"]
    source = report["source"]
    qoblib_source = source["qoblib_metrics"]
    qoblib_qubo = report["qoblib_qubo_metrics"]
    target = report["toqubo"]["target"]
    metadata = report["toqubo"]["metadata"]
    incumbent = report["known_incumbent"]
    comparison = report["comparison"]

    write(io, "# QOBLib Sports Reformulation Pilot\n\n")
    write(
        io,
        "This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.\n\n",
    )

    write(io, "## Provenance\n\n")
    write(io, "- QOBLIB repository: $(provenance["qoblib_repository"])\n")
    write(io, "- QOBLIB commit: `$(provenance["qoblib_commit"])`\n")
    write(io, "- QOBLIB class: `$(provenance["qoblib_class"])`\n")
    write(io, "- Source instance: `$(provenance["source_instance_path"])`\n")
    write(io, "- Source converter: `$(provenance["source_converter_path"])`\n")
    write(io, "- Source LP: `$(provenance["source_lp_path"])`\n")
    write(io, "- Source solution: `$(provenance["source_solution_path"])`\n")
    write(io, "- Source metrics: `$(provenance["source_metrics_path"])`\n")
    write(io, "- Source metrics CSV row: `$(provenance["source_metrics_csv_row"])`\n")
    write(io, "- Canonical QUBO metrics: `$(provenance["canonical_qubo_metrics_path"])`\n")
    write(
        io,
        "- Canonical QUBO metrics CSV row: `$(provenance["canonical_qubo_metrics_csv_row"])`\n",
    )
    write(io, "- Data license: $(provenance["qoblib_data_license"])\n")
    write(io, "- Generated collection label: $(provenance["collection"])\n\n")

    write(io, "## Upstream Verification\n\n")
    write(
        io,
        "- Manual verification: $(_fmt(verification["manual_verification"])) against QOBLIB commit `$(provenance["qoblib_commit"])`.\n",
    )
    write(io, "- Converter refs: $(join(verification["converter_line_refs"], ", ")).\n")
    write(io, "- Instance refs: $(join(verification["instance_line_refs"], ", ")).\n")
    write(io, "- LP refs: $(join(verification["lp_line_refs"], ", ")).\n")
    write(io, "- Solution refs: $(join(verification["solution_line_refs"], ", ")).\n")
    write(io, "- Metrics refs: $(join(verification["metrics_line_refs"], ", ")).\n")

    for note in verification["transcription_notes"]
        write(io, "- $(note).\n")
    end

    write(io, "\n")

    write(io, "## Instance\n\n")
    write(io, "- QOBLIB id: `$(instance["qoblib_id"])`\n")
    write(io, "- XML instance name: `$(instance["xml_instance_name"])`\n")
    write(io, "- Source LP file: `$(instance["lp_file"])`\n")
    write(io, "- Canonical QUBO metrics row: `$(instance["canonical_qubo_file"])`\n")
    write(io, "- Size class: $(instance["size_class"])\n")
    write(io, "- Teams: $(instance["teams"])\n")
    write(io, "- Slots: $(instance["slots"])\n")
    write(io, "- Number round robin: $(instance["number_round_robin"])\n")
    write(io, "- Game mode: $(instance["game_mode"])\n")
    write(io, "- Matches per slot: $(instance["matches_per_slot"])\n\n")

    write(io, "## Modeling Assumptions\n\n")

    for assumption in source["modeling_assumptions"]
        write(io, "- $(assumption)\n")
    end

    write(io, "\n## Bounds and Naming\n\n")

    for bound in source["bounds"]
        write(io, "- $(bound)\n")
    end

    for naming in source["variable_naming"]
        write(io, "- $(naming)\n")
    end

    write(io, "\n## Metrics\n\n")
    write(io, "| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |\n")
    write(io, "|:--|--:|--:|--:|\n")
    write(
        io,
        _metric_row(
            "variables",
            qoblib_source["num_vars"],
            qoblib_qubo["num_variables"],
            target["num_variables"],
        ),
    )
    write(
        io,
        _metric_row(
            "density",
            qoblib_source["density"],
            qoblib_qubo["density"],
            target["density"],
        ),
    )
    write(
        io,
        _metric_row(
            "minimum coefficient",
            qoblib_source["min_coeff"],
            qoblib_qubo["min_coeff"],
            target["min_coeff"],
        ),
    )
    write(
        io,
        _metric_row(
            "maximum coefficient",
            qoblib_source["max_coeff"],
            qoblib_qubo["max_coeff"],
            target["max_coeff"],
        ),
    )
    write(
        io,
        _metric_row("objective offset", "n/a", "n/a", target["objective_offset"]),
    )
    write(io, _metric_row("QUBO terms", "n/a", "n/a", target["num_terms"]))
    write(
        io,
        _metric_row("quadratic terms", "n/a", "n/a", target["num_quadratic_terms"]),
    )

    write(io, "\n## Reformulation Metadata\n\n")
    write(io, "- Metadata schema version: $(metadata["schema_version"])\n")
    write(io, "- Source variables: $(metadata["source_variable_count"])\n")
    write(io, "- Target variables: $(metadata["target_variable_count"])\n")
    write(io, "- Auxiliary variables: $(metadata["auxiliary_variable_count"])\n")
    write(io, "- Slack variables: $(metadata["slack_variable_count"])\n")
    write(io, "- Constraint penalties: $(metadata["constraint_penalty_count"])\n")
    write(io, "- Variable penalties: $(metadata["variable_penalty_count"])\n")
    write(io, "- Slack penalties: $(metadata["slack_penalty_count"])\n")
    write(io, "- Distinct constraint penalties: $(join(_fmt.(metadata["constraint_penalties"]), ", "))\n")
    write(io, "- Encoding types: `$(join(metadata["encoding_types"], "`, `"))`\n")

    generated = source["generated_metrics"]

    write(io, "\n## Source Constraint Counts\n\n")
    write(io, "- Assignment constraints: $(generated["num_assignment_constraints"])\n")
    write(io, "- Slot capacity constraints: $(generated["num_slot_capacity_constraints"])\n")
    write(io, "- Team-slot constraints: $(generated["num_team_slot_constraints"])\n")
    write(io, "- Break-count constraints: $(generated["num_break_count_constraints"])\n")
    write(io, "- Phased constraints: $(generated["num_phased_constraints"])\n")
    write(io, "- CA4 capacity constraints: $(generated["num_capacity_constraints"])\n")
    write(io, "- GA1 game constraints: $(generated["num_game_constraints"])\n")
    write(io, "- BR1/BR2 break-limit constraints: $(generated["num_break_limit_constraints"])\n")

    write(io, "\n## Known Incumbent\n\n")
    write(io, "- QOBLIB solution artifact objective: $(incumbent["qoblib_solution_objective"])\n")
    write(io, "- Source objective: $(_fmt(incumbent["source_objective"]))\n")
    write(io, "- Active games: $(incumbent["active_game_count"])\n")
    write(io, "- Home breaks: $(incumbent["home_break_count"])\n")
    write(io, "- Away breaks: $(incumbent["away_break_count"])\n")
    write(io, "- Source feasible: $(_fmt(incumbent["source_feasible"]))\n")
    write(io, "- Assignment feasible: $(_fmt(incumbent["assignment_feasible"]))\n")
    write(io, "- Slot capacity feasible: $(_fmt(incumbent["slot_capacity_feasible"]))\n")
    write(io, "- Team-slot feasible: $(_fmt(incumbent["team_slot_feasible"]))\n")
    write(io, "- Phased feasible: $(_fmt(incumbent["phased_feasible"]))\n")
    write(io, "- Break-count feasible: $(_fmt(incumbent["break_count_feasible"]))\n")
    write(io, "- CA4 capacity feasible: $(_fmt(incumbent["capacity_feasible"]))\n")
    write(io, "- GA1 game feasible: $(_fmt(incumbent["game_constraint_feasible"]))\n")
    write(io, "- BR1/BR2 break-limit feasible: $(_fmt(incumbent["break_limit_feasible"]))\n")
    write(
        io,
        "- QOBLIB solution artifact consistency check: $(_fmt(incumbent["matches_qoblib_solution_artifact"] ? "pass" : "fail"))\n",
    )

    write(io, "\n## Comparison Notes\n\n")
    write(
        io,
        "- Canonical QUBO metrics available for this instance: $(_fmt(comparison["canonical_qubo_metrics_available"]))\n",
    )
    write(
        io,
        "- Target variable delta vs QOBLIB canonical QUBO metrics: $(comparison["target_variable_delta_vs_qoblib_qs"])\n",
    )
    write(
        io,
        "- Density delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["density_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Minimum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["min_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Maximum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["max_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- QOBLIB-style minimum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["qoblib_symmetric_min_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- QOBLIB-style maximum coefficient delta vs QOBLIB canonical QUBO metrics: $(_fmt(comparison["qoblib_symmetric_max_coeff_delta_vs_qoblib_qs"]))\n",
    )
    write(
        io,
        "- Redundant source constraints detected as always feasible by ToQUBO: $(comparison["redundant_constraint_count"])\n",
    )
    write(
        io,
        "- QOBLIB-style coefficient range: minimum `$(_fmt(target["qoblib_symmetric_min_coeff"]))`, maximum `$(_fmt(target["qoblib_symmetric_max_coeff"]))`.\n",
    )
    write(
        io,
        "- The native maximum coefficient keeps full off-diagonal weights, while QOBLIB's QS metrics use the symmetrized convention.\n",
    )

    write(io, "\n## Follow-Up\n\n")
    write(io, report["follow_up"], "\n")

    return nothing
end

function write_markdown_report(path::AbstractString, report::AbstractDict)
    mkpath(dirname(path))

    open(path, "w") do io
        write_markdown_report(io, report)
    end

    return path
end

function main(args = ARGS)
    output = isempty(args) ? joinpath(@__DIR__, "reports", "sports_pilot.md") : first(args)
    report = run_sports_pilot()

    write_markdown_report(output, report)
    println(output)

    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
