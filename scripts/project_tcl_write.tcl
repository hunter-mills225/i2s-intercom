# For DFX projects, remove nocattrs.txt from project prior to TCL export
# This file automatically gets added locally, and needs to be removed for recreation TCL to work
remove_files "*nocattrs.dat*"

# Remove design checkpoint files which are local
remove_files -fileset utils_1 "*.dcp"

# Export project recreation TCL script that includes the block diagram
set file_name [get_property NAME [current_project]].tcl
write_project_tcl -target_proj_dir ./output -force $file_name

# Edit generated TCL file to replace quotes with braces for the steps.synth_design.args.more options parameters
set m_str {"-generic DATE_CODE=\$datecode -generic TIME_CODE=\$timecode -generic HASH_CODE=\$git_hash_id"}
set r_str {{-generic DATE_CODE=$datecode -generic TIME_CODE=$timecode -generic HASH_CODE=$git_hash_id}}

set fp [open "$file_name" r]
set fp_tmp [open "$file_name.tmp" w+]

set file_data [read $fp]

regsub -- $m_str $file_data $r_str file_data

puts $fp_tmp $file_data

close $fp
close $fp_tmp

file rename -force $file_name.tmp $file_name
file delete -force $file_name.tmp

