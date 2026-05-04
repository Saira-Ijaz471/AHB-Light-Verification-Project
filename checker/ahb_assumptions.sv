// ============================================================
//  AHB Lite Formal Verification — Master Assumptions
//  Project  : EE-5214 AMBA AHB-Lite RAM Verification
//  DUT      : ahb3lite_sram (RoaLogic)
//  Role     : B — Assertions & Formal
//  Spec     : ARM IHI0033A
//
//  Purpose  : Constrain the formal tool to only explore
//             legal AHB-Lite master behaviour.
//             Without these, JasperGold will drive illegal
//             stimulus and generate false counterexamples.
//
//  Sections:
//  [1] HTRANS State Machine   — legal transfer sequences
//  [2] Address Constraints    — alignment, 1KB, stability
//  [3] Burst Constraints      — HBURST/HSIZE/HWRITE stability
//  [4] Data Constraints       — HWDATA validity
//  [5] Signal Integrity       — no X/Z on master signals
//  [6] Reset Constraints      — master reset behaviour
// ============================================================

import ahb3lite_pkg::*;

module ahb_assumptions #(
    parameter int HADDR_SIZE  = 32,
    parameter int HDATA_SIZE  = 32,
    parameter int MEM_DEPTH   = 256
)(
    input                       HRESETn,
    input                       HCLK,
    input                       HSEL,
    input      [HADDR_SIZE-1:0] HADDR,
    input      [HDATA_SIZE-1:0] HWDATA,
    input                       HWRITE,
    input      [           2:0] HSIZE,
    input      [           2:0] HBURST,
    input      [           1:0] HTRANS,
    input                       HREADY,
    input                       HRESP
);

    // ---- default clocking & disable iff ------------------------
    default clocking ahb_clk @(posedge HCLK); endclocking
    default disable iff (!HRESETn);

    // ---- max valid address -------------------------------------
    localparam [HADDR_SIZE-1:0] MAX_ADDR =
        (MEM_DEPTH * (HDATA_SIZE/8)) - 1;

    logic [HADDR_SIZE-1:0] burst_start_addr;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) burst_start_addr <= '0;
        else if (HREADY && HTRANS == HTRANS_NONSEQ)
            burst_start_addr <= HADDR;
    end

    // ============================================================
    //  [1] HTRANS STATE MACHINE CONSTRAINTS
    //  — Legal transfer type sequences
    // ============================================================

    // AM1 — HTRANS must always be valid encoding
    //       Prevents tool from driving X/Z or illegal values
    am_htrans_valid: assume property (
        HTRANS inside {HTRANS_IDLE, HTRANS_BUSY,
                       HTRANS_NONSEQ, HTRANS_SEQ}
    );

    // AM2 — SEQ can only follow NONSEQ or SEQ
    //       "SEQ cannot follow IDLE or BUSY at burst start"
    am_seq_after_nonseq_or_seq: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ})
    );

    // AM3 — BUSY illegal in SINGLE burst
    //        "Master not permitted to perform BUSY
    //       immediately after SINGLE burst"
    am_no_busy_in_single: assume property (
        (HSEL && HBURST == HBURST_SINGLE) |->
        (HTRANS != HTRANS_BUSY)
    );

    // AM4 — BUSY only in active burst
    //         "BUSY only legal when continuing active burst"
    am_busy_only_in_active_burst: assume property (
        (HSEL && HTRANS == HTRANS_BUSY && HREADY) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY})
    );

    // AM5 — BUSY as last cycle only in undefined INCR burst
    //       "Only undefined length bursts can have
    //       BUSY as the last cycle"
    am_busy_last_only_in_incr: assume property (
        (HSEL && HTRANS == HTRANS_BUSY && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY}) |->
        ( (HBURST == HBURST_INCR) ||
          ($past(HTRANS) != HTRANS_BUSY) )
    );

    // AM6 — Burst must always start with NONSEQ
    //        "First transfer of burst is NONSEQ"
    am_burst_starts_nonseq: assume property (
        (HSEL && HBURST != HBURST_SINGLE && HREADY &&
         $past(HTRANS) == HTRANS_IDLE &&
         HTRANS != HTRANS_IDLE) |->
        (HTRANS == HTRANS_NONSEQ)
    );

    // AM7 — SINGLE burst must be followed by IDLE or NONSEQ
    //       "SINGLE bursts must be followed by
    //       IDLE or NONSEQ"
    am_single_followed_by_idle_nonseq: assume property (
        (HSEL && $past(HBURST) == HBURST_SINGLE &&
         $past(HTRANS) == HTRANS_NONSEQ && HREADY) |->
        (HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ})
    );

    // AM8 — Fixed-length burst continuation: valid HTRANS
    //       After NONSEQ in fixed burst, only SEQ/BUSY until done
    am_incr_valid_continuation: assume property (
        (HSEL && HBURST == HBURST_INCR && HREADY &&
         HTRANS inside {HTRANS_SEQ, HTRANS_BUSY}) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY})
    );

    // AM9 — HTRANS stable when HREADY=0 (wait state)
   // "Address-phase signals must remain stable
    //       when HREADY is LOW"
    am_htrans_stable_wait: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HTRANS == $past(HTRANS))
    );

    // AM10 — Master returns to IDLE after ERROR response
    am_master_idle_after_error: assume property (
        (HSEL && $past(HRESP) == HRESP_ERROR && HREADY) |=>
        (HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ})
    );
    // ============================================================
    //  [2] ADDRESS CONSTRAINTS
    // ============================================================

    // AM11 — HADDR must be aligned to HSIZE
    //        "Transfers must be aligned to address
    //        boundary equal to size of transfer"
    am_haddr_aligned: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && HREADY) |->
        ( (HSIZE == HSIZE_B8)  ||
          (HSIZE == HSIZE_B16  && HADDR[0]   == 1'b0)  ||
          (HSIZE == HSIZE_B32  && HADDR[1:0] == 2'b00) )
    );

    // AM12 — HADDR stable during wait states
    //         "Address must remain stable when HREADY=0"
    am_haddr_stable_wait: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HADDR == $past(HADDR))
    );

    // AM13 — INCR burst must not cross 1KB boundary
    //        "Masters must not start an incrementing
    //        burst that crosses 1KB address boundary"
    am_incr_no_1kb_cross: assume property (
    (HSEL && HBURST inside {HBURST_INCR, HBURST_INCR4,
                             HBURST_INCR8, HBURST_INCR16} &&
     HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
    (HADDR <= MAX_ADDR)
    );

    // AM14 — HADDR within valid memory range 
    am_haddr_in_range: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (HADDR <= MAX_ADDR)
    );

    // AM15 — BUSY address reflects next transfer in burst
    //      "Address and control must reflect
    //        next transfer in burst during BUSY"
    am_busy_addr_reflects_next: assume property (
        (HSEL && HTRANS == HTRANS_BUSY && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY}) |->
        ( (HSIZE == HSIZE_B8  && HADDR == $past(HADDR) + 1) ||
          (HSIZE == HSIZE_B16 && HADDR == $past(HADDR) + 2) ||
          (HSIZE == HSIZE_B32 && HADDR == $past(HADDR) + 4) )
    );

    // AM16 — SEQ address increments by HSIZE (INCR bursts)
    //     "Address = prev address + transfer size"
    am_seq_addr_increment: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY &&
         HBURST == HBURST_INCR) |->
        ( (HSIZE == HSIZE_B8  && HADDR == $past(HADDR) + 1) ||
          (HSIZE == HSIZE_B16 && HADDR == $past(HADDR) + 2) ||
          (HSIZE == HSIZE_B32 && HADDR == $past(HADDR) + 4) )
    );

    // ============================================================
    //  [3] BURST CONSTRAINTS
    // ============================================================

    // AM17 — HBURST must remain constant throughout burst
    //       "HBURST value must remain constant"
    am_hburst_constant_burst: assume property (
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        (HBURST == $past(HBURST))
    );

    // AM18 — HBURST stable during wait states
    am_hburst_stable_wait: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HBURST == $past(HBURST))
    );

    // AM19 — HSIZE must remain constant throughout burst
    //       "HSIZE must remain constant throughout burst"
    am_hsize_constant_burst: assume property (
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        (HSIZE == $past(HSIZE))
    );

    // AM20 — HSIZE stable during wait states
    //       "HSIZE has same timing as address bus"
    am_hsize_stable_wait: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HSIZE == $past(HSIZE))
    );

    // AM21 — HSIZE valid for 32-bit bus
    //    "Transfer size must be <= data bus width"
    am_hsize_valid_32bit: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (HSIZE inside {HSIZE_B8, HSIZE_B16, HSIZE_B32})
    );

    // AM22 — HWRITE stable during wait states
    //      "HWRITE must remain stable during wait states"
    am_hwrite_stable_wait: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HWRITE == $past(HWRITE))
    );

    // AM23 — SEQ control signals same as previous transfer
    //      "Control information identical to previous"
    am_seq_control_stable: assume property (
        (HSEL && HTRANS == HTRANS_SEQ && HREADY) |->
        ( HSIZE  == $past(HSIZE)  &&
          HBURST == $past(HBURST) &&
          HWRITE == $past(HWRITE) )
    );

    // ============================================================
    //  [4] DATA CONSTRAINTS
    // ============================================================

    // AM24 — HWDATA stable until HREADY=1 during extended write
    //"Master must hold data valid
    //        until transfer completes (HREADY HIGH)"
    am_hwdata_stable_until_hready: assume property (
        (HSEL && HWRITE == 1'b1 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         !HREADY) |->
        (HWDATA == $past(HWDATA))
    );

    // AM25 — HWDATA not X/Z during active write data phase
    //        Spec §6.1.1: write data must be valid
    am_hwdata_not_xz: assume property (
        (HSEL && HREADY == 1'b1 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b1) |->
        (!$isunknown(HWDATA))
    );

    // ============================================================
    //  [5] SIGNAL INTEGRITY — MASTER SIGNALS
    // ============================================================

    // AM26 — HADDR no X/Z during active operation
    am_haddr_no_xz: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HADDR))
    );

    // AM27 — HTRANS no X/Z
    am_htrans_no_xz: assume property (
        (HSEL) |-> (!$isunknown(HTRANS))
    );

    // AM28 — HWRITE no X/Z during active transfer
    am_hwrite_no_xz: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HWRITE))
    );

    // AM29 — HBURST no X/Z during active transfer
    am_hburst_no_xz: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HBURST))
    );

    // AM30 — HSIZE no X/Z during active transfer
    am_hsize_no_xz: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HSIZE))
    );

    // AM31 — HSEL no X/Z
    am_hsel_no_xz: assume property (
        (!$isunknown(HSEL))
    );

    // ============================================================
    //  [6] RESET CONSTRAINs
    // ============================================================

    // AM32 — Master drives IDLE immediately after reset
    //       "After reset all masters must drive IDLE"
    am_htrans_idle_after_reset: assume property (
        @(posedge HCLK)
        (!HRESETn) |=> (HTRANS == HTRANS_IDLE)
    );

    // AM33 — No transfer starts during reset
    //        Prevents tool from starting burst during reset
    am_no_transfer_during_reset: assume property (
        @(posedge HCLK)
        (!HRESETn) |->
        (HTRANS == HTRANS_IDLE)
    );

    // AM34 — HSEL deasserted during reset
    //        Master should not select slave during reset
    am_hsel_deasserted_reset: assume property (
        @(posedge HCLK)
        (!HRESETn) |-> (!HSEL)
    );
    // burst start address tracker

    // WRAP4
    am_wrap4_no_region_cross_byte: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP4 && HSIZE == 3'b000 && HREADY) |->
        (HADDR[HADDR_SIZE-1:2] == burst_start_addr[HADDR_SIZE-1:2] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap4_no_region_cross_hword: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP4 && HSIZE == 3'b001 && HREADY) |->
        (HADDR[HADDR_SIZE-1:3] == burst_start_addr[HADDR_SIZE-1:3] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap4_no_region_cross_word: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP4 && HSIZE == 3'b010 && HREADY) |->
        (HADDR[HADDR_SIZE-1:4] == burst_start_addr[HADDR_SIZE-1:4] ||
        HTRANS == HTRANS_NONSEQ)
    );

    // WRAP8
    am_wrap8_no_region_cross_byte: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP8 && HSIZE == 3'b000 && HREADY) |->
        (HADDR[HADDR_SIZE-1:3] == burst_start_addr[HADDR_SIZE-1:3] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap8_no_region_cross_hword: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP8 && HSIZE == 3'b001 && HREADY) |->
        (HADDR[HADDR_SIZE-1:4] == burst_start_addr[HADDR_SIZE-1:4] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap8_no_region_cross_word: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP8 && HSIZE == 3'b010 && HREADY) |->
        (HADDR[HADDR_SIZE-1:5] == burst_start_addr[HADDR_SIZE-1:5] ||
        HTRANS == HTRANS_NONSEQ)
    );

        // WRAP16
    am_wrap16_no_region_cross_byte: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP16 && HSIZE == 3'b000 && HREADY) |->
        (HADDR[HADDR_SIZE-1:4] == burst_start_addr[HADDR_SIZE-1:4] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap16_no_region_cross_hword: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP16 && HSIZE == 3'b001 && HREADY) |->
        (HADDR[HADDR_SIZE-1:5] == burst_start_addr[HADDR_SIZE-1:5] ||
        HTRANS == HTRANS_NONSEQ)
    );
    am_wrap16_no_region_cross_word: assume property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HBURST == HBURST_WRAP16 && HSIZE == 3'b010 && HREADY) |->
        (HADDR[HADDR_SIZE-1:6] == burst_start_addr[HADDR_SIZE-1:6] ||
        HTRANS == HTRANS_NONSEQ)
    );
endmodule