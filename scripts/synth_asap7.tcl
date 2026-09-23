# synth_asap7.tcl -- map the flattened RV32IM core onto ASAP7 7.5T and report area.
#
# Driven by `make area`, which first builds build/cpu_full.v (sv2v output) and
# pins the NLDM libraries with `make asap7-libs`.
#
#   yosys -c scripts/synth_asap7.tcl
#
# Flow:
#   1. read build/cpu_full.v
#   2. elaborate cpu_top (cacheless, no SRAM macros)
#   3. synth -flatten -noabc
#   4. dfflibmap against the SEQ library
#   5. let Yosys extract combinatorial cones and map them with ABC, using all
#      four combinatorial ASAP7 groups
#   6. check -assert -mapped
#   7. stat -liberty with all five libraries, and write the mapped netlist
#   8. re-read the *written* netlist and re-assert the absence of unmapped
#      cells, so that the report describes the artifact rather than just the
#      in-memory design
#
# Two toolchain workarounds are needed, both documented in the README:
#
#   * Every projected cell library is loaded into Yosys before synthesis.  This
#     Yosys build (0.33) otherwise maps the gates in ABC but cannot recover their
#     pin directions while importing ABC's BLIF, leaving the cone outputs
#     undriven.  Preloading the cell definitions makes the normal `abc` pass
#     import the mapped cones correctly and, unlike a whole-design BLIF round
#     trip, keeps sequential cells outside ABC.
#
#   * ABC is given the folded combinatorial library rather than the five group
#     libraries one by one.  This ABC build mis-classifies ASAP7 cells when a
#     second `read_lib` is performed (it then reports "genlib library reader
#     cannot detect the buffer gate" and its mapper aborts with "Cannot find
#     buffer gate in the library"), and it discards the INVBUF group outright
#     because that group exposes only two gate classes.  The folded library is
#     the projection of the four combinatorial groups, so all of ASAP7's
#     combinatorial cells remain available; SEQ is still used for dfflibmap and
#     all five groups are still used for the area report.

set lib_dir "build/asap7"
set slim_dir "$lib_dir/slim"
set work_dir "build/mapped"
set rpt_dir "build/reports"
set verilog "build/cpu_full.v"

proc env_or_default {name fallback} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $fallback
}

set top [env_or_default "AREA_TOP" "cpu_top"]
set label [env_or_default "AREA_LABEL" $top]
set area_params [env_or_default "AREA_PARAMS" ""]
if {![regexp {^[A-Za-z_][A-Za-z0-9_]*$} $top]} {
  error "AREA_TOP must be a Verilog module identifier: $top"
}
if {![regexp {^[A-Za-z_][A-Za-z0-9_]*$} $label]} {
  error "AREA_LABEL must contain only letters, digits, and underscores: $label"
}
if {$label eq "cpu_top"} {
  set report "$rpt_dir/area.md"
} else {
  set report "$rpt_dir/area_${label}.md"
}

# --- library inventory -------------------------------------------------------
# Group libraries: used for dfflibmap, for read_liberty, and for stat -liberty.
set lib_seq [list \
  "$slim_dir/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib"]
set lib_comb_groups [list \
  "$slim_dir/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib" \
  "$slim_dir/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib" \
  "$slim_dir/asap7sc7p5t_OA_RVT_TT_nldm_211120.lib" \
  "$slim_dir/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib"]
set lib_all [concat $lib_comb_groups $lib_seq]
# The single library handed to the ABC mapper: all four combinational groups
# folded into one. Sequential cells remain in the design as cone boundaries.
set lib_comb "$slim_dir/asap7sc7p5t_COMB_RVT_TT.lib"

proc liberty_args {libs} {
  set out {}
  foreach lib $libs { lappend out -liberty $lib }
  return $out
}

foreach path [concat $lib_all [list $lib_comb $verilog]] {
  if {![file exists $path]} {
    error "missing $path -- run `make asap7-libs` for the libraries and `make build/cpu_full.v` for the netlist"
  }
}

file mkdir $work_dir
file mkdir $rpt_dir

proc read_text {path} {
  set fh [open $path r]
  set text [read $fh]
  close $fh
  return $text
}

proc require_number {label text pattern} {
  if {![regexp $pattern $text -> value]} {
    error "could not parse $label"
  }
  return $value
}

proc chip_area {path} {
  return [require_number "chip area in $path" [read_text $path] \
            {Chip area for module '\\?[^']*':[ \t]*([0-9.]+)}]
}

proc chip_cells {path} {
  return [require_number "cell count in $path" [read_text $path] \
            {Number of cells:[ \t]*([0-9]+)}]
}

# --- synthesis ---------------------------------------------------------------
puts "=== ASAP7 mapping: $top ==="

yosys design -reset
# The old Yosys ABC importer needs the mapped cells' pin directions in the
# design before it reads ABC's BLIF back.
foreach lib $lib_all { yosys read_liberty -lib $lib }
yosys read_verilog $verilog
set hierarchy_args [list -top $top]
if {$area_params ne ""} {
  foreach binding [split $area_params ","] {
    if {![regexp {^([A-Za-z_][A-Za-z0-9_]*)=([0-9]+)$} $binding -> name value]} {
      error "AREA_PARAMS must be comma-separated NAME=UNSIGNED_INTEGER pairs: $area_params"
    }
    lappend hierarchy_args -chparam $name $value
  }
}
yosys hierarchy {*}$hierarchy_args
yosys synth -flatten -noabc
yosys dfflibmap {*}[liberty_args $lib_seq]

set abc_log  "$rpt_dir/${label}.abc.log"
puts "--- mapping combinatorial cones with Yosys/ABC (log: $abc_log)"
yosys tee -o $abc_log abc -liberty $lib_comb
yosys clean
yosys check -assert -mapped

set stat_rpt "$rpt_dir/synth_asap7_${label}.rpt"
yosys tee -o $stat_rpt stat {*}[liberty_args $lib_all]
set netlist "$work_dir/${label}.mapped.v"
yosys write_verilog -noattr $netlist

# The written artifact must contain no unmapped cell.
yosys design -reset
foreach lib $lib_all { yosys read_liberty -lib $lib }
yosys read_verilog $netlist
yosys hierarchy -top $top
yosys select -assert-none {t:$*}
yosys select -assert-none {t:$_*}

# --- report ------------------------------------------------------------------
set a_core [chip_area $stat_rpt]
set cells  [chip_cells $stat_rpt]

set fh [open $report w]
puts $fh "# ASAP7 area"
puts $fh ""
puts $fh "> Generated by \`scripts/synth_asap7.tcl\` for \`$top\` (label \`$label\`). ASAP7 7.5T RVT/TT"
puts $fh "> NLDM from OpenROAD-flow-scripts \`3dd5892cd1d7559b1c9a1efadd25adde5b6c2820\`,"
puts $fh "> \`synth -flatten -noabc\`, \`dfflibmap\` against the SEQ library, then ABC"
puts $fh "> over the four combinatorial groups."
puts $fh ""
puts $fh "| quantity | value |"
puts $fh "| --- | ---: |"
puts $fh "| A_core (\`$top\`, standard cells) | $a_core um^2 |"
puts $fh "| mapped cells | $cells |"
puts $fh "| report label | \`$label\` |"
if {$area_params ne ""} {
  puts $fh "| elaboration parameters | \`$area_params\` |"
}
puts $fh ""
puts $fh "| top | mapped netlist | stat report | ABC log |"
puts $fh "| --- | --- | --- | --- |"
puts $fh "| $top | \`$netlist\` | \`$stat_rpt\` | \`$abc_log\` |"
puts $fh ""
puts $fh "The mapped netlist was re-read afterwards and re-checked: it contains no"
puts $fh "unmapped cell. \`$top\` is cacheless, so no SRAM macro is involved."
close $fh

puts ""
puts "AREA_RESULT top=$top label=$label area=$a_core cells=$cells"
puts "report written to $report"
