# ============================================================
#  JasperGold FPV Setup Script
#  Project : AMBA AHB-Lite RAM Verification
#  Role    : B (Formal)
# ============================================================

# ------------------------------------------------------------
# 1. ANALYZE  
# ------------------------------------------------------------

# Package  
analyze -sv \
    ../dut/packages/ahb3lite_pkg.sv

# DUT
analyze -sv \
    ../dut/rtl/design.sv

# Checker + Bind
analyze -sv \
    ../checker/ahb_checker.sv   \
    ../checker/bind_ahb.sv      \
    ../checker/ahb_assumptions.sv \
    ../checker/ahb_cover.sv

# ------------------------------------------------------------
# 2. ELABORATE — Top module  
# ------------------------------------------------------------

elaborate \
    -top ahb3lite_sram \
    -bbox_mul 8

# ------------------------------------------------------------
# 3. CLOCK & RESET
# ------------------------------------------------------------

clock  HCLK
reset  -expression {~HRESETn}

# ------------------------------------------------------------
# 4. PROVE
# ------------------------------------------------------------

prove -task FPV

# ------------------------------------------------------------
# 5. RESULTS — jg_results/  save 
# ------------------------------------------------------------

report -task FPV \
    -file ../formal/jg_results/fpv_report.txt

# Proven assertions
report -task FPV \
    -proven \
    -file ../formal/jg_results/proven/proven_props.txt

# Counterexamples
report -task FPV \
    -cex \
    -file ../formal/jg_results/cex/cex_props.txt

# Bounded results
report -task FPV \
    -bounded \
    -file ../formal/jg_results/bounded/bounded_props.txt

# Cover properties
report -task FPV \
    -cover \
    -file ../formal/jg_results/cover_report.txt

# ------------------------------------------------------------
# 6. VACUITY CHECK  
# ------------------------------------------------------------

check_vacuity -task FPV