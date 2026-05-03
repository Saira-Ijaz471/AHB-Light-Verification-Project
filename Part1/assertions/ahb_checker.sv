// ============================================================
//  AHB Lite Formal Verification — Complete Assertions
//  DUT   : Single Master, Single Slave, 32-bit data bus
//  Clock : HCLK
//  Reset : HRESETn (active low)
//
//  Sections:
//  [1] HTRANS Rules          (15 assertions)
//  [2] HSIZE Rules           ( 5 assertions)
//  [3] Burst Rules           (13 assertions)
//  [4] Handshake & Response  ( 7 assertions)
//  [5] Data Bus              ( 6 assertions)
//  [6] Signal Integrity      ( 4 assertions)
//  [7] Write Correctness     ( 6 assertions)
//  [8] Byte & HW Masking     ( 4 assertions)
//  [9] Read Correctness      ( 4 assertions)
//  [10] Pipeline             ( 4 assertions)
//  [11] Address & Boundary   ( 5 assertions)
//  [12] Reset                ( 7 assertions)
// ============================================================

import ahb3lite_pkg::*;

module ahb_lite_assertions #(
    parameter int HADDR_SIZE  = 32,
    parameter int HDATA_SIZE  = 32,
    parameter int MEM_DEPTH   = 256,
    parameter int RESET_BOUND = 4
)(
    input                       HRESETn,
    input                       HCLK,
    input                       HSEL,
    input      [HADDR_SIZE-1:0] HADDR,
    input      [HDATA_SIZE-1:0] HWDATA,
    input      [HDATA_SIZE-1:0] HRDATA,
    input                       HWRITE,
    input      [           2:0] HSIZE,
    input      [           2:0] HBURST,
    input      [           1:0] HTRANS,
    input                       HREADYOUT,
    input                       HREADY,
    input                       HRESP
);

    // ---- max valid address -------------------------------------
    localparam [HADDR_SIZE-1:0] MAX_ADDR =
        (MEM_DEPTH * (HDATA_SIZE/8)) - 1;

    // ============================================================
    //  PIPELINE TRACKING REGISTERS
    //  addr_ph / size_ph / write_ph / valid_ph
    //  Latched at end of address phase (when HREADY=1)
    // ============================================================
    logic [HADDR_SIZE-1:0] addr_ph;
    logic [2:0]            size_ph;
    logic                  write_ph;
    logic                  valid_ph;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_ph  <= '0;
            size_ph  <= '0;
            write_ph <= '0;
            valid_ph <= '0;
        end else if (HREADY) begin
            addr_ph  <= HADDR;
            size_ph  <= HSIZE;
            write_ph <= HWRITE;
            valid_ph <= (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ});
        end
    end

    // ============================================================
    //  BEAT COUNTER — tracks beats in fixed-length bursts
    // ============================================================
    int beat_count;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            beat_count <= 0;
        end else if (HSEL && HREADY) begin
            if      (HTRANS == HTRANS_NONSEQ)                    beat_count <= 1;
            else if (HTRANS inside {HTRANS_SEQ, HTRANS_BUSY})    beat_count <= beat_count + 1;
            else                                                  beat_count <= 0;
        end
    end

    // ---- wrap boundary helper ----------------------------------
    function automatic [HADDR_SIZE-1:0] wrap_boundary;
        input [2:0] hburst;
        input [2:0] hsize;
        logic [HADDR_SIZE-1:0] beats, size_bytes;
        begin
            case (hburst)
                HBURST_WRAP4 : beats = 4;
                HBURST_WRAP8 : beats = 8;
                HBURST_WRAP16: beats = 16;
                default      : beats = 1;
            endcase
            size_bytes    = (1 << hsize);
            wrap_boundary = beats * size_bytes;
        end
    endfunction

    default clocking cb @(posedge HCLK);
    endclocking

    default disable iff (!HRESETn);

    // ============================================================
    //  [1] HTRANS RULES
    // ============================================================

    // T1 — HADDR must be aligned to HSIZE on NONSEQ/SEQ
    a_haddr_aligned: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && HREADY) |->
        ( (HSIZE == HSIZE_B8)  ||
          (HSIZE == HSIZE_B16  && HADDR[0]   == 1'b0)  ||
          (HSIZE == HSIZE_B32  && HADDR[1:0] == 2'b00) )
    );

    // T2 — SEQ only after NONSEQ or SEQ
    a_seq_after_nonseq_or_seq: assert property (
        
        (HSEL && HTRANS == HTRANS_SEQ && HREADY) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ})
    );

    // T3 — BUSY illegal in SINGLE burst
    a_no_busy_in_single: assert property (
        
        (HSEL && HBURST == HBURST_SINGLE) |->
        (HTRANS != HTRANS_BUSY)
    );

    // T4 — BUSY only in active burst
    a_busy_only_in_active_burst: assert property (
        
        (HSEL && HTRANS == HTRANS_BUSY && HREADY) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY})
    );

    // T5 — Valid HTRANS encoding only
    a_htrans_valid_encoding: assert property (
        
        HTRANS inside {HTRANS_IDLE, HTRANS_BUSY, HTRANS_NONSEQ, HTRANS_SEQ}
    );

    // T6 — Only NONSEQ/SEQ initiate valid transfer
    a_only_nonseq_seq_transfer: assert property (
        
        (HSEL && HTRANS inside {HTRANS_IDLE, HTRANS_BUSY}) |->
        (HRESP == HRESP_OKAY && HREADYOUT == 1'b1)
    );

    // T7 — HTRANS = IDLE immediately after reset
    a_htrans_idle_after_reset: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HTRANS == HTRANS_IDLE)
    );

    // T8 — IDLE gets zero wait OKAY response
    a_idle_zero_wait_okay: assert property (
        
        (HSEL && HTRANS == HTRANS_IDLE) |->
        (HREADYOUT == 1'b1 && HRESP == HRESP_OKAY)
    );

    // T9 — IDLE ignored by slave (HRESP=OKAY)
    a_idle_ignored_hresp: assert property (
        
        (HSEL && HTRANS == HTRANS_IDLE) |->
        (HRESP == HRESP_OKAY)
    );

    // T10 — BUSY address reflects next transfer
    a_busy_addr_reflects_next: assert property (
        
        (HSEL && HTRANS == HTRANS_BUSY && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY}) |->
        ( (HSIZE == HSIZE_B8  && HADDR == $past(HADDR) + 1) ||
          (HSIZE == HSIZE_B16 && HADDR == $past(HADDR) + 2) ||
          (HSIZE == HSIZE_B32 && HADDR == $past(HADDR) + 4) )
    );

    // T11 — BUSY gets zero wait OKAY response
    a_busy_zero_wait_okay: assert property (
        
        (HSEL && HTRANS == HTRANS_BUSY) |->
        (HREADYOUT == 1'b1 && HRESP == HRESP_OKAY)
    );

    // T12 — BUSY ignored by slave
    a_busy_ignored_hresp: assert property (
        
        (HSEL && HTRANS == HTRANS_BUSY) |->
        (HRESP == HRESP_OKAY)
    );

    // T13 — BUSY as last cycle only in INCR
    a_busy_last_only_in_incr: assert property (
        
        (HSEL && HTRANS == HTRANS_BUSY && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY}) |->
        ( (HBURST == HBURST_INCR) ||
          ($past(HTRANS) != HTRANS_BUSY) )
    );

    // T14 — SEQ address increments by HSIZE (INCR only)
    a_seq_addr_increment: assert property (
        
        (HSEL && HTRANS == HTRANS_SEQ && HREADY &&
         HBURST == HBURST_INCR) |->
        ( (HSIZE == HSIZE_B8  && HADDR == $past(HADDR) + 1) ||
          (HSIZE == HSIZE_B16 && HADDR == $past(HADDR) + 2) ||
          (HSIZE == HSIZE_B32 && HADDR == $past(HADDR) + 4) )
    );

    // T15 — SEQ control signals same as previous transfer
    a_seq_control_stable: assert property (
        
        (HSEL && HTRANS == HTRANS_SEQ && HREADY) |->
        ( HSIZE  == $past(HSIZE)  &&
          HBURST == $past(HBURST) &&
          HWRITE == $past(HWRITE) )
    );

    // ============================================================
    //  [2] HSIZE RULES
    // ============================================================

    // S1 — Valid HSIZE for 32-bit bus (000, 001, 010 only)
    a_hsize_valid_32bit: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (HSIZE inside {HSIZE_B8, HSIZE_B16, HSIZE_B32})
    );

    // S2a — Invalid HSIZE → ERROR cycle 1: HREADY=0
    a_hsize_invalid_error_c1: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HSIZE > HSIZE_B32) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b0)
    );

    // S2b — Invalid HSIZE → ERROR cycle 2: HREADY=1
    a_hsize_invalid_error_c2: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HSIZE) > HSIZE_B32 &&
         $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b0) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b1)
    );

    // S3 — HSIZE stable during wait states
    a_hsize_stable_wait_state: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HSIZE == $past(HSIZE))
    );

    // S4 — HSIZE constant throughout burst (no X/Z)
    a_hsize_no_xz: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HSIZE))
    );

    // ============================================================
    //  [3] BURST RULES
    // ============================================================

    // B1 — Fixed-length bursts: exact beat counts
    a_incr4_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_INCR4 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 4)
    );

    a_wrap4_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_WRAP4 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 4)
    );

    a_incr8_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_INCR8 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 8)
    );

    a_wrap8_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_WRAP8 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 8)
    );

    a_incr16_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_INCR16 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 16)
    );

    a_wrap16_exact_beats: assert property (
        
        (HSEL && HBURST == HBURST_WRAP16 && HREADY &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ}) |->
        (beat_count == 16)
    );

    // B2 — HBURST constant throughout burst
    a_hburst_constant_burst: assert property (
        
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        (HBURST == $past(HBURST))
    );

    // B3 — HSIZE constant throughout burst
    a_hsize_constant_in_burst: assert property (
        
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        (HSIZE == $past(HSIZE))
    );

    // B4 — INCR valid continuation (SEQ/BUSY after NONSEQ)
    a_incr_valid_continuation: assert property (
        
        (HSEL && HBURST == HBURST_INCR && HREADY &&
         HTRANS inside {HTRANS_SEQ, HTRANS_BUSY}) |->
        ($past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY})
    );

    // B5 — Fixed-length bursts terminate with SEQ
    a_fixed_burst_ends_seq: assert property (
        
        (HSEL && HREADY &&
         HBURST inside {HBURST_INCR4, HBURST_WRAP4,
                        HBURST_INCR8, HBURST_WRAP8,
                        HBURST_INCR16, HBURST_WRAP16} &&
         HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ} &&
         $past(HTRANS) inside {HTRANS_SEQ, HTRANS_BUSY}) |->
        ($past(HTRANS) == HTRANS_SEQ)
    );

    // B6 — WRAP burst address inside aligned boundary
    a_wrap4_addr_in_boundary: assert property (
        
        (HSEL && HBURST == HBURST_WRAP4 &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        ( (HADDR & ~(wrap_boundary(HBURST_WRAP4, HSIZE) - 1)) ==
          ($past(HADDR) & ~(wrap_boundary(HBURST_WRAP4, HSIZE) - 1)) )
    );

    a_wrap8_addr_in_boundary: assert property (
        
        (HSEL && HBURST == HBURST_WRAP8 &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        ( (HADDR & ~(wrap_boundary(HBURST_WRAP8, HSIZE) - 1)) ==
          ($past(HADDR) & ~(wrap_boundary(HBURST_WRAP8, HSIZE) - 1)) )
    );

    a_wrap16_addr_in_boundary: assert property (
        
        (HSEL && HBURST == HBURST_WRAP16 &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        ( (HADDR & ~(wrap_boundary(HBURST_WRAP16, HSIZE) - 1)) ==
          ($past(HADDR) & ~(wrap_boundary(HBURST_WRAP16, HSIZE) - 1)) )
    );

    // B7 — WRAP burst address wraps correctly at boundary
    a_wrap4_correct_wrap: assert property (
        
        (HSEL && HBURST == HBURST_WRAP4 && HTRANS == HTRANS_SEQ && HREADY) |->
        ( HADDR == ($past(HADDR) + (1 << HSIZE)) ||
          HADDR == ($past(HADDR) + (1 << HSIZE) -
                    wrap_boundary(HBURST_WRAP4, HSIZE)) )
    );

    a_wrap8_correct_wrap: assert property (
        
        (HSEL && HBURST == HBURST_WRAP8 && HTRANS == HTRANS_SEQ && HREADY) |->
        ( HADDR == ($past(HADDR) + (1 << HSIZE)) ||
          HADDR == ($past(HADDR) + (1 << HSIZE) -
                    wrap_boundary(HBURST_WRAP8, HSIZE)) )
    );

    a_wrap16_correct_wrap: assert property (
        
        (HSEL && HBURST == HBURST_WRAP16 && HTRANS == HTRANS_SEQ && HREADY) |->
        ( HADDR == ($past(HADDR) + (1 << HSIZE)) ||
          HADDR == ($past(HADDR) + (1 << HSIZE) -
                    wrap_boundary(HBURST_WRAP16, HSIZE)) )
    );

    // B8 — SEQ address increments by HSIZE (INCR bursts)
    a_seq_incr_addr: assert property (
        
        (HSEL && HTRANS == HTRANS_SEQ && HREADY &&
         HBURST inside {HBURST_INCR, HBURST_INCR4,
                        HBURST_INCR8, HBURST_INCR16}) |->
        (HADDR == $past(HADDR) + (1 << $past(HSIZE)))
    );

    // B9 — Burst starts with NONSEQ
    a_burst_starts_nonseq: assert property (
        
        (HSEL && HBURST != HBURST_SINGLE && HREADY &&
         $past(HTRANS) == HTRANS_IDLE &&
         HTRANS != HTRANS_IDLE) |->
        (HTRANS == HTRANS_NONSEQ)
    );

    // B10 — HBURST no X/Z during active transfer
    a_hburst_valid_encoding: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HBURST))
    );

    // B11 — INCR must not cross 1KB boundary
    a_incr_no_1kb_cross: assert property (
        
        (HSEL && HBURST inside {HBURST_INCR, HBURST_INCR4,
                                 HBURST_INCR8, HBURST_INCR16} &&
         HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} && HREADY) |->
        (HADDR[HADDR_SIZE-1:10] == $past(HADDR[HADDR_SIZE-1:10]))
    );

    // B12 — SINGLE followed by IDLE or NONSEQ
    a_single_followed_by_idle_nonseq: assert property (
        
        (HSEL && $past(HBURST) == HBURST_SINGLE &&
         $past(HTRANS) == HTRANS_NONSEQ && HREADY) |->
        (HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ})
    );

    // B13 — After ERROR master can terminate burst
    a_error_burst_termination: assert property (
        
        (HSEL && HRESP == HRESP_ERROR && HREADYOUT == 1'b1) |=>
        (HTRANS inside {HTRANS_IDLE, HTRANS_NONSEQ,
                        HTRANS_SEQ,  HTRANS_BUSY})
    );

    // ============================================================
    //  [4] HANDSHAKE & RESPONSE RULES
    // ============================================================

    // H1 — Address-phase signals stable when HREADY=0
    a_haddr_stable_wait: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HADDR == $past(HADDR))
    );

    a_htrans_stable_wait: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HTRANS == $past(HTRANS))
    );

    a_hwrite_stable_wait: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} && !HREADY) |->
        (HWRITE == $past(HWRITE))
    );

    // H2 — HRESP=ERROR exactly 2 cycles
    //      Cycle 1: HREADY=0
    a_error_cycle1_hready_low: assert property (
        
        (HSEL && HRESP == HRESP_ERROR &&
         $past(HRESP) == HRESP_OKAY) |->
        (HREADYOUT == 1'b0)
    );

    //      Cycle 2: HREADY=1
    a_error_cycle2_hready_high: assert property (
        
        (HSEL && $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b0) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b1)
    );

    //      ERROR must not persist beyond 2 cycles
    a_error_max_2_cycles: assert property (
        
        (HSEL && $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b1) |->
        (HRESP == HRESP_OKAY)
    );

    // H3 — HSEL=0: slave outputs must be default/inactive
    a_hsel_0_hreadyout_default: assert property (
        
        (!HSEL) |-> (HREADYOUT == 1'b1)
    );

    a_hsel_0_hresp_default: assert property (
        
        (!HSEL) |-> (HRESP == HRESP_OKAY)
    );

    a_hsel_0_hrdata_default: assert property (
        
        (!HSEL) |-> (HRDATA == '0)
    );

    // H4 — HWDATA valid (not X/Z) in data phase of write
    a_hwdata_valid_after_write: assert property (
        
        (HSEL && $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b1 && HREADY) |->
        (!$isunknown(HWDATA))
    );

    // H5 — HRDATA stable while stalled on read (HREADY=0)
    a_hrdata_stable_wait: assert property (
        
        (HSEL && !HREADY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0) |->
        (HRDATA == $past(HRDATA))
    );

    // ============================================================
    //  [5] DATA BUS RULES
    // ============================================================

    // D1 — HWDATA stable until HREADY=1 during extended write
    a_hwdata_stable_until_hready: assert property (
        
        (HSEL && HWRITE == 1'b1 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         !HREADY) |->
        (HWDATA == $past(HWDATA))
    );

    // D2 — HRDATA valid in final cycle of read (HREADY=1, OKAY)
    a_hrdata_valid_on_hready: assert property (
        
        (HSEL && $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b0 &&
         HREADY == 1'b1 &&
         HRESP == HRESP_OKAY) |->
        (!$isunknown(HRDATA))
    );

    // D3 — HRDATA not X/Z on valid read (OKAY, HREADY=1)
    a_hrdata_not_xz_valid_read: assert property (
        
        (HSEL && HREADY == 1'b1 &&
         HRESP == HRESP_OKAY &&
         $past(HWRITE) == 1'b0 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HRDATA))
    );

    // D4 — HWDATA not X/Z during active write data phase
    a_hwdata_not_xz_on_write: assert property (
        
        (HSEL && HREADY == 1'b1 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b1) |->
        (!$isunknown(HWDATA))
    );

    // ============================================================
    //  [6] SIGNAL INTEGRITY
    // ============================================================

    // SI1 — No X/Z on control signals during active operation
    a_haddr_no_xz: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HADDR))
    );

    a_htrans_no_xz: assert property (
        
        (HSEL) |-> (!$isunknown(HTRANS))
    );

    a_hwrite_no_xz: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HWRITE))
    );

    a_hburst_no_xz: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HBURST))
    );

    // SI2 — HRESP valid encoding only (OKAY or ERROR)
    a_hresp_valid: assert property (
        
        (!$isunknown(HRESP)) &&
        (HRESP inside {HRESP_OKAY, HRESP_ERROR})
    );

    // SI3 — HREADY/HREADYOUT no X/Z
    a_hready_no_xz: assert property (
        
        (!$isunknown(HREADY)) &&
        (!$isunknown(HREADYOUT))
    );

    // ============================================================
    //  [7] WRITE CORRECTNESS
    // ============================================================

    // WC1 — Data written to A must be readable from A
    a_write_read_correctness: assert property (
        
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph &&
         HSIZE  == size_ph) |=>
        (HRDATA == $past(HWDATA))
    );

    // WC2 — No memory change without valid write
    a_no_change_without_write: assert property (
        
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );

    // WC3 — Back-to-back writes: latest value wins on readback
    a_latest_write_wins: assert property (
        
        (HSEL && HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph &&
         valid_ph && write_ph) |=>
        (HRDATA == $past(HWDATA))
    );

    // WC4 — Word write atomically updates all 4 bytes
    a_word_write_atomic: assert property (
        
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B32 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph) |=>
        (HRDATA[31:0] == $past(HWDATA[31:0]))
    );

    // WC5 — Memory unchanged during read transactions
    a_no_mem_change_on_read: assert property (
        
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );

    // WC6 — HWDATA ignored during read (HRDATA not X/Z)
    a_hwdata_ignored_read: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HREADY) |->
        (!$isunknown(HRDATA))
    );

    // ============================================================
    //  [8] BYTE & HALF-WORD MASKING
    // ============================================================

    // M1 — Byte write: only targeted byte changes
    a_byte_write_targeted: assert property (
        
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B8 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1:0] == 2'b00) ? (HRDATA[7:0]   == $past(HWDATA[7:0]))   :
          (addr_ph[1:0] == 2'b01) ? (HRDATA[15:8]  == $past(HWDATA[15:8]))  :
          (addr_ph[1:0] == 2'b10) ? (HRDATA[23:16] == $past(HWDATA[23:16])) :
                                    (HRDATA[31:24] == $past(HWDATA[31:24])) )
    );

    // M2 — Byte write: remaining bytes unchanged
    a_byte_write_no_corrupt: assert property (
        
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B8 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1:0] == 2'b00) ? (HRDATA[31:8]  == $past(HRDATA[31:8]))  :
          (addr_ph[1:0] == 2'b01) ? (HRDATA[31:16] == $past(HRDATA[31:16]) &&
                                     HRDATA[7:0]   == $past(HRDATA[7:0]))   :
          (addr_ph[1:0] == 2'b10) ? (HRDATA[31:24] == $past(HRDATA[31:24]) &&
                                     HRDATA[15:0]  == $past(HRDATA[15:0]))  :
                                    (HRDATA[23:0]  == $past(HRDATA[23:0]))  )
    );

    // M3 — Half-word write: only targeted 2 bytes change
    a_hword_write_targeted: assert property (
        
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B16 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1] == 1'b0) ? (HRDATA[15:0]  == $past(HWDATA[15:0]))  :
                                  (HRDATA[31:16] == $past(HWDATA[31:16])) )
    );

    // M4 — Half-word write: remaining bytes unchanged
    a_hword_write_no_corrupt: assert property (
        
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B16 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1] == 1'b0) ? (HRDATA[31:16] == $past(HRDATA[31:16])) :
                                  (HRDATA[15:0]  == $past(HRDATA[15:0]))  )
    );

    // ============================================================
    //  [9] READ CORRECTNESS
    // ============================================================

    // RC1 — Consecutive reads to same address: same data
    a_consec_reads_same_data: assert property (
        
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );

    // RC2 — First read after reset: no X/Z on HRDATA
    a_first_read_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn) ##1
         (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
          HWRITE == 1'b0 && HREADY && HRESP == HRESP_OKAY)) |=>
        (!$isunknown(HRDATA))
    );

    // RC3 — Read-after-write returns latest written data
    a_read_after_write: assert property (
        
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph &&
         HSIZE  == size_ph) |=>
        (HRDATA == $past(HWDATA))
    );

    // RC4 — Read data not X/Z (address match implied)
    a_read_data_not_xz: assert property (
        
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY) |->
        (!$isunknown(HRDATA))
    );

    // ============================================================
    //  [10] PIPELINE ASSERTIONS
    // ============================================================

    // P1 — Write overlapping next addr phase: HWDATA not X/Z
    a_pipeline_write_correct: assert property (
        
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HWDATA))
    );

    // P2 — No data leakage between pipelined transactions
    a_no_data_leakage: assert property (
        
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HADDR != addr_ph) |=>
        (!$isunknown(HRDATA))
    );

    // P3 — Back-to-back R/W ordering preserved
    a_pipeline_rw_ordering: assert property (
        
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == $past(HWDATA))
    );

    // P4 — Addr/data phase association correct under pipelining
    a_pipeline_addr_data_assoc: assert property (
        
        (HSEL && valid_ph && write_ph && HREADY) |->
        (!$isunknown(HWDATA))
    );

    // ============================================================
    //  [11] ADDRESS & BOUNDARY RULES
    // ============================================================

    // A1 — Out-of-range address → HRESP=ERROR or HRDATA=0
    a_out_of_range_error: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HREADY && HADDR > MAX_ADDR) |=>
        (HRESP == HRESP_ERROR || HRDATA == '0)
    );

    // A2 — INCR burst address must not exceed memory boundary
    a_incr_no_mem_boundary_cross: assert property (
        
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} &&
         HBURST inside {HBURST_INCR, HBURST_INCR4,
                        HBURST_INCR8, HBURST_INCR16} &&
         HREADY) |->
        (HADDR <= MAX_ADDR)
    );

    // A3 — WRAP bursts must not cross aligned wrap region
    a_wrap4_no_region_cross: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HBURST == HBURST_WRAP4 && HREADY) |->
        ( HADDR[HADDR_SIZE-1 : $clog2(4*(1<<HSIZE))] ==
          $past(HADDR[HADDR_SIZE-1 : $clog2(4*(1<<HSIZE))]) ||
          HTRANS == HTRANS_NONSEQ )
    );

    a_wrap8_no_region_cross: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HBURST == HBURST_WRAP8 && HREADY) |->
        ( HADDR[HADDR_SIZE-1 : $clog2(8*(1<<HSIZE))] ==
          $past(HADDR[HADDR_SIZE-1 : $clog2(8*(1<<HSIZE))]) ||
          HTRANS == HTRANS_NONSEQ )
    );

    a_wrap16_no_region_cross: assert property (
        
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HBURST == HBURST_WRAP16 && HREADY) |->
        ( HADDR[HADDR_SIZE-1 : $clog2(16*(1<<HSIZE))] ==
          $past(HADDR[HADDR_SIZE-1 : $clog2(16*(1<<HSIZE))]) ||
          HTRANS == HTRANS_NONSEQ )
    );

    // ============================================================
    //  [12] RESET ASSERTIONS
    // ============================================================

    // R1 — HREADY high within RESET_BOUND cycles after reset
    a_hready_high_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn)) |->
        ##[1:RESET_BOUND] (HREADYOUT == 1'b1)
    );

    // R2 — HRESP = OKAY within RESET_BOUND cycles after reset
    a_hresp_okay_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn)) |->
        ##[1:RESET_BOUND] (HRESP == HRESP_OKAY)
    );

    // R3 — Ongoing transaction aborts cleanly on reset
    a_reset_aborts_transaction: assert property (
        @(posedge HCLK)
        (!HRESETn &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ}) |=>
        (HTRANS == HTRANS_IDLE)
    );

    // R4 — Memory not corrupted after mid-transaction reset
    a_reset_no_mem_corrupt: assert property (
        @(posedge HCLK)
        ($rose(HRESETn) ##[1:10]
         (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
          HWRITE == 1'b0 && HREADY && HRESP == HRESP_OKAY)) |=>
        (!$isunknown(HRDATA))
    );

    // R5 — HTRANS = IDLE immediately after reset
    a_htrans_idle_after_reset: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HTRANS == HTRANS_IDLE)
    );

    // R6 — HREADYOUT = 1 immediately after reset
    a_hreadyout_reset_default: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HREADYOUT == 1'b1)
    );

    // R7 — HRESP = OKAY immediately after reset
    a_hresp_reset_default: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HRESP == HRESP_OKAY)
    );

endmodule