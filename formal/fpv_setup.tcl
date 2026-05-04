# =============================================================
#  JasperGold FPV Setup Script
#  Project  : EE-5214 AMBA AHB-Lite RAM Verification
# =============================================================

analyze -sv ../dut/packages/ahb3lite_pkg.sv

analyze -sv \
    ../dut/rtl/mem.sv    \
    ../dut/rtl/design.sv

analyze -sv \
    ../checker/ahb_checker.sv     \
    ../checker/ahb_assumptions.sv \
    ../checker/ahb_cover.sv       \
    ../checker/bind_ahb.sv

elaborate -top ahb3liten      \
    -parameter MEM_SIZE   32  \
    -parameter MEM_DEPTH  256  \
    -parameter HADDR_SIZE  16 \
    -parameter HDATA_SIZE 32

clock HCLK
reset -expression {~HRESETn}

# prove runs assertions AND covers together
prove -all

report -all \
    -force \
    -file ../formal/jg_results/fpv_report.txt

puts "========================================================"
puts "  FPV Done — check jg_results/fpv_report.txt"
puts "========================================================"