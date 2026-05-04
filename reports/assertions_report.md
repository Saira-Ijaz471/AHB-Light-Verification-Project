# AHB-Lite Slave Assertions Report

**Project:** AMBA AHB-Lite RAM Verification  
**DUT:** ahb3liten + SRAM  
**Tool:** JasperGold 2025.06p002  
**Date:** May 4, 2026  
**Spec:** ARM IHI0033A  

---

## Summary

| Metric | Count |
|--------|-------|
| Total Assertions | 50 |
| Proven | 38 (76.0%) |
| Counterexample (cex) | 12 (24.0%) |

---

## Assertions Detail

| Name | Spec Clause | Result |
|------|-------------|--------|
| a_idle_okay_only | IDLE transfers → OKAY response only (Spec 3.2, 4.1.1) | proven |
| a_idle_ignored_hresp | IDLE transfers ignored by slave, HRESP=OKAY (Spec 3.2) | proven |
| a_busy_okay_only | BUSY transfers → OKAY response only (Spec 3.4) | proven |
| a_busy_ignored_hresp | BUSY transfers ignored by slave, HRESP=OKAY (Spec 3.2) | proven |
| a_only_nonseq_seq_transfer | Only NONSEQ/SEQ initiate valid transfers (Spec 3.2) | proven |
| a_hsize_invalid_error_c1 | Invalid HSIZE → ERROR, cycle1: HREADY=0 (Spec 3.3, 3.6.2) | proven |
| a_hsize_invalid_error_c2 | Invalid HSIZE → ERROR, cycle2: HREADY=1 (Spec 3.6) | proven |
| a_hrdata_valid_final | HRDATA valid final cycle of read when HREADY=1, HRESP=OKAY (Spec 6.1.2) | proven |
| a_error_cycle1_hready_low | ERROR cycle1: HREADY must be LOW (Spec 3.6.2, 5.1.3) | proven |
| a_error_cycle2_hready_high | ERROR cycle2: HREADY must be HIGH (Spec 3.6.2, 5.1.3) | proven |
| a_error_max_2_cycles | ERROR does not persist beyond 2 cycles (Spec 3.6.2) | proven |
| a_hsel_0_hreadyout_default | HSEL=0 → HREADYOUT default HIGH (Derived from Spec 3.4) | proven |
| a_hsel_0_hresp_default | HSEL=0 → HRESP = OKAY (Derived from Spec 3.5) | proven |
| a_hsel_0_hrdata_safe | HSEL=0 → HRDATA not X/Z (Derived from Spec 2.5) | proven |
| a_hrdata_valid_on_hready | HRDATA valid final cycle of read (Spec 6.1.2) | proven |
| a_hrdata_not_xz_valid_read | HRDATA not X/Z on valid read (Spec 6.1.2) | proven |
| a_hwdata_valid_after_write | HWDATA valid in write data phase (Spec 6.1.1) | proven |
| a_hresp_valid | HRESP valid encoding: OKAY/ERROR (Spec 5.1) | proven |
| a_hreadyout_no_xz | HREADYOUT no X/Z (Spec 2.3) | proven |
| a_write_read_correctness | Data written to A must be readable from A (Functional) | **cex** |
| a_no_change_without_write | No memory change without valid write (Functional) | **cex** |
| a_latest_write_wins | Back-to-back writes: latest value wins (Functional) | **cex** |
| a_word_write_atomic | Word write atomically updates all 4 bytes (Functional) | **cex** |
| a_no_mem_change_on_read | Memory unchanged during read (Functional) | **cex** |
| a_hwdata_ignored_read | HWDATA ignored during read (Functional) | proven |
| a_byte_write_targeted | Byte write: only targeted byte changes (Functional) | **cex** |
| a_byte_write_no_corrupt | Byte write: remaining bytes unchanged (Functional) | **cex** |
| a_hword_write_targeted | Half-word write: only targeted 2 bytes change (Functional) | **cex** |
| a_hword_write_no_corrupt | Half-word write: remaining bytes unchanged (Functional) | **cex** |
| a_consec_reads_same_data | Consecutive reads same address → identical data (Functional) | **cex** |
| a_first_read_after_reset | First read after reset: no X/Z on HRDATA (Functional) | proven |
| a_read_after_write | Read-after-write returns latest data (Functional) | **cex** |
| a_read_data_not_xz | Read data not X/Z (Functional) | proven |
| a_pipeline_write_correct | Pipeline write: HWDATA valid (Functional) | proven |
| a_no_data_leakage | No data leakage between pipelined transactions (Functional) | proven |
| a_pipeline_rw_ordering | Back-to-back R/W ordering preserved (Functional) | **cex** |
| a_pipeline_addr_data_assoc | Address/data phase association correct (Functional) | proven |
| a_out_of_range_error | Out-of-range address → HRESP=ERROR (Spec 4.1.1) | proven |
| a_incr_no_mem_boundary_cross | INCR burst within memory (Spec 3.5.3) | proven |
| a_hready_high_after_reset | HREADY high within RESET_BOUND after reset (Spec 7) | proven |
| a_hresp_okay_after_reset | HRESP=OKAY within RESET_BOUND after reset (Spec 7) | proven |
| a_reset_aborts_transaction | Ongoing transaction aborts cleanly on reset (Spec 7) | proven |
| a_reset_no_mem_corrupt | Memory not corrupted after reset (Spec 7) | proven |
| a_htrans_idle_after_reset | HTRANS=IDLE immediately after reset (Spec 7) | proven |
| a_hreadyout_reset_default | HREADYOUT=1 immediately after reset (Spec 7) | proven |
| a_hresp_reset_default | HRESP=OKAY immediately after reset (Spec 7) | proven |
| a_wrap4_byte_region | WRAP4 byte transfers stay within 16-byte region (Spec 3.5.3) | proven |
| a_wrap4_word_region | WRAP4 word transfers stay within 16-byte region (Spec 3.5.3) | proven |
| a_wrap8_word_region | WRAP8 word transfers stay within 32-byte region (Spec 3.5.3) | proven |
| a_wrap16_word_region | WRAP16 word transfers stay within 64-byte region (Spec 3.5.3) | proven |

---

## Failed Assertions (cex) - 12 Total

| # | Name | Category |
|---|------|----------|
| 1 | a_write_read_correctness | Write Correctness |
| 2 | a_no_change_without_write | Write Correctness |
| 3 | a_latest_write_wins | Write Correctness |
| 4 | a_word_write_atomic | Write Correctness |
| 5 | a_no_mem_change_on_read | Write Correctness |
| 6 | a_read_after_write | Write Correctness |
| 7 | a_pipeline_rw_ordering | Pipeline |
| 8 | a_byte_write_targeted | Byte/Hword Masking |
| 9 | a_byte_write_no_corrupt | Byte/Hword Masking |
| 10 | a_hword_write_targeted | Byte/Hword Masking |
| 11 | a_hword_write_no_corrupt | Byte/Hword Masking |
| 12 | a_consec_reads_same_data | Read Stability |

---

## Status Legend

| Status | Meaning |
|--------|---------|
| proven | Assertion holds under all legal inputs |
| cex | Counterexample found - design bug |
