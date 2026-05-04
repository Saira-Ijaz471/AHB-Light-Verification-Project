//  AHB Lite SVA Checker — DUT Assertions Only
//  Project  : EE-5214 AMBA AHB-Lite RAM Verification
//  DUT      : ahb3liten and sram
//  Role     : B — Assertions & Formal
//  Spec     : ARM IHI0033A
//
//  NOTE: Master behaviour is constrained in ahb_assumptions.sv
//        This file only checks DUT (slave) outputs and
//        functional memory correctness.
//
//  Sections:
//  [1]  Slave Response        — SR1  to SR8   (Spec  3.2,4.1.1) slaves must always provide a zero wait st,  3.6)
//  [2]  ERROR Response        — ER1  to ER3   (Spec  3.6.2) done
//  [3]  HSEL Inactive         — HS1  to HS3   (Spec  3,2,5 inferred from spec) done
//  [4]  Data Bus              — DB1  to DB4   (Spec  6.1.1, 6.1.2) done
//  [5]  Signal Integrity      — SI1  to SI2   (Spec  5.1,2.3) done
//  [6]  Write Correctness     — WC1  to WC6   (Functional)
//  [7]  Byte & HW Masking     — M1   to M4    (Functional)
//  [8]  Read Correctness      — RC1  to RC4   (Functional)
//  [9]  Pipeline              — P1   to P4    (Functional)
//  [10] Address & Boundary    — A1   to A3    (Spec  3.5.3,4.1.1 )done
//  [11] Reset                 — R1   to R7    (Spec  7)
                   
import ahb3lite_pkg::*;
module ahb_checker #(
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
 
    // ── default clocking & disable ────────────────────────────────
    default clocking ahb_clk @(posedge HCLK); endclocking
    default disable iff (!HRESETn);
 
    // ── max valid address ─────────────────────────────────────────
    localparam [HADDR_SIZE-1:0] MAX_ADDR =
        (MEM_DEPTH * (HDATA_SIZE/8)) - 1;
 
    logic [HADDR_SIZE-1:0] addr_ph;
    logic [2:0]            size_ph;
    logic                  write_ph;
    logic                  valid_ph;
    logic [HDATA_SIZE-1:0] hwdata_ph;
  
    logic [HADDR_SIZE-1:0] burst_start_addr;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) burst_start_addr <= '0;
        else if (HREADY && HTRANS == HTRANS_NONSEQ)
            burst_start_addr <= HADDR;
    end
    
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_ph          <= '0;
            size_ph          <= '0;
            write_ph         <= '0;
            valid_ph         <= '0;
            hwdata_ph        <= '0;
        end else begin
            // ── pipeline registers ─────────────────────────────────
            if (HREADY) begin
                addr_ph   <= HADDR;
                size_ph   <= HSIZE;
                write_ph  <= HWRITE;
                valid_ph  <= (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ});
                hwdata_ph <= HWDATA;
            end
    end
    end
 
    //  [1] SLAVE RESPONSE RULES  

    // SR1 — Spec 4.1.1 IDLE or BUSY transfers to nonexistent locations result in a zero wait state OKAY
    //                  response.
    //       Spec  3.2 "Slave must always provide zero wait state
    //       OKAY response to IDLE transfers"
    a_idle_okay_only: assert property (
    (HSEL && HTRANS == HTRANS_IDLE) |->
    (HRESP == HRESP_OKAY)
    );
    c_idle_seen: cover property (
    HSEL && HTRANS == HTRANS_IDLE && HRESP == HRESP_OKAY
    );

    // SR2 — IDLE ignored by slave (HRESP=OKAY)
    //       Spec  3.2: "Transfer must be ignored by the slave"
    a_idle_ignored_hresp: assert property (
        (HSEL && HTRANS == HTRANS_IDLE) |->
        (HRESP == HRESP_OKAY)
    );
    c_idle_ignored: cover property (
        HSEL && HTRANS == HTRANS_IDLE && HRESP == HRESP_OKAY
    );

    // SR3 — BUSY must get zero wait state OKAY response
    //       Spec  3.4: "Slave must always provide zero wait state
    //       OKAY response to BUSY transfers"
    a_busy_okay_only: assert property (
    (HSEL && HTRANS == HTRANS_BUSY) |->
    (HRESP == HRESP_OKAY)
    );
    c_busy_in_burst: cover property (
    HSEL &&
    $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
    HTRANS == HTRANS_BUSY
    );

    // SR4 — BUSY ignored by slave (HRESP=OKAY)
    //       Spec  3.2: "Transfer must be ignored by the slave"
    a_busy_ignored_hresp: assert property (
        (HSEL && HTRANS == HTRANS_BUSY) |->
        (HRESP == HRESP_OKAY)
    );
    c_busy_ignored: cover property (
        HSEL && HTRANS == HTRANS_BUSY && HRESP == HRESP_OKAY
    );

    // SR5 — Only NONSEQ/SEQ initiate valid transfer
    //       IDLE and BUSY get OKAY with no side effects
    a_only_nonseq_seq_transfer: assert property (
        (HSEL && HTRANS inside {HTRANS_IDLE, HTRANS_BUSY}) |->
        (HRESP == HRESP_OKAY )
    );
    c_idle_busy_okay_resp: cover property (
        HSEL && HTRANS == HTRANS_BUSY &&
        HRESP == HRESP_OKAY 
    );

    // SR6 — Invalid HSIZE → ERROR cycle 1: HREADY=0
    //       Spec  3.3: "Invalid HSIZE must generate HRESP=ERROR"
    a_hsize_invalid_error_c1: assert property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HSIZE > HSIZE_B32) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b0)
    );
    c_hsize_error_c1: cover property (
        HSEL && HSIZE > HSIZE_B32 &&
        HRESP == HRESP_ERROR && HREADYOUT == 1'b0
    );

    // SR7 — Invalid HSIZE → ERROR cycle 2: HREADY=1
    //       Spec  3.6: "ERROR response lasts exactly 2 cycles"
    a_hsize_invalid_error_c2: assert property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HSIZE) > HSIZE_B32 &&
         $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b0) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b1)
    );
    c_hsize_error_c2: cover property (
        $past(HRESP) == HRESP_ERROR &&
        $past(HREADYOUT) == 1'b0 &&
        HRESP == HRESP_ERROR && HREADYOUT == 1'b1
    );

    // SR8 —  
    // Spec  6.1.2: slave only needs valid data in final cycle
    a_hrdata_valid_final: assert property (
    (HSEL &&
     $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
     $past(HWRITE) == 1'b0 &&
     HREADY == 1'b1 &&
     HRESP == HRESP_OKAY)
    |->
    (!$isunknown(HRDATA))
    );
    c_hrdata_valid_final: cover property (
    HSEL &&
    $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
    $past(HWRITE) == 1'b0 &&
    HREADY == 1'b1 &&
    HRESP == HRESP_OKAY &&
    !$isunknown(HRDATA)
     );

    // ============================================================
    //  [2] ERROR RESPONSE  
    // ============================================================

    // ER1 — ERROR cycle 1: HREADY must be LOW
    //       Spec  3.6.2 Waveform, 5.1.3: "HREADY=0 on first ERROR cycle"
    a_error_cycle1_hready_low: assert property (
        (HSEL && HRESP == HRESP_ERROR &&
         $past(HRESP) == HRESP_OKAY) |->
        (HREADYOUT == 1'b0)
    );
    c_error_first_cycle: cover property (
        HSEL && HRESP == HRESP_ERROR &&
        $past(HRESP) == HRESP_OKAY &&
        HREADYOUT == 1'b0
    );

    // ER2 — ERROR cycle 2: HREADY must be HIGH
    //       Spec  3.6.2 Waveform, 5.1.3: "HREADY=1 on second ERROR cycle"
    a_error_cycle2_hready_high: assert property (
        (HSEL && $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b0) |->
        (HRESP == HRESP_ERROR && HREADYOUT == 1'b1)
    );
    c_error_second_cycle: cover property (
        $past(HRESP) == HRESP_ERROR &&
        $past(HREADYOUT) == 1'b0 &&
        HRESP == HRESP_ERROR && HREADYOUT == 1'b1
    );

    // ER3 — ERROR must not persist beyond 2 cycles
    //       Spec  3.6.2 Waveform, 5.1.3: "ERROR lasts exactly 2 cycles"
    a_error_max_2_cycles: assert property (
        (HSEL && $past(HRESP) == HRESP_ERROR &&
         $past(HREADYOUT) == 1'b1) |->
        (HRESP == HRESP_OKAY)
    );
    c_error_ends: cover property (
        $past(HRESP) == HRESP_ERROR &&
        $past(HREADYOUT) == 1'b1 &&
        HRESP == HRESP_OKAY
    );

    // ============================================================
    //  [3] HSEL INACTIVE STATE   
    // ============================================================

    // HS1 — HSEL=0: HREADYOUT must be default HIGH
    // Derived from: Section 3,4 – Slave must not insert wait states when not selected
    a_hsel_0_hreadyout_default: assert property (
        (!HSEL && $past(!HSEL)) |-> (HREADYOUT == 1'b1)
    );
    c_hsel_0_hready: cover property (
        !HSEL && HREADYOUT == 1'b1
    );

    // HS2 — HSEL=0: HRESP must be OKAY
    //Derived from: Section 3 , 5– Response is only meaningful for active transfers
    a_hsel_0_hresp_default: assert property (
        (!HSEL) |-> (HRESP == HRESP_OKAY)
    );
    c_hsel_0_hresp: cover property (
        !HSEL && HRESP == HRESP_OKAY
    );

    // HS3 — HSEL=0: HRDATA must be 0
    //Derived from: Section 2,5– Read data is valid only during active transfer phase
    a_hsel_0_hrdata_safe: assert property (
    !HSEL |-> !$isunknown(HRDATA)
    );
    c_hsel_0_hrdata_default: cover property (
    !HSEL && !$isunknown(HRDATA)
    );

    // ============================================================
    //  [4] DATA BUS  —  Spec  6.1
    // ============================================================

    // DB1 — HRDATA valid in final cycle of read (HREADY=1, OKAY)
    //       Spec  6.1.2: "Slave only provides valid data in
    //       final cycle when HREADY HIGH"
    a_hrdata_valid_on_hready: assert property (
        (HSEL && $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b0 &&
         HREADY == 1'b1 && HRESP == HRESP_OKAY) |->
        (!$isunknown(HRDATA))
    );
    c_hrdata_final_valid: cover property (
        $past(HWRITE) == 1'b0 &&
        HREADY == 1'b1 && HRESP == HRESP_OKAY &&
        !$isunknown(HRDATA)
    );

    // DB2 — HRDATA not X/Z on valid read
    //       Spec  6.1.2: "Valid data on OKAY response only"
    a_hrdata_not_xz_valid_read: assert property (
        (HSEL && HREADY == 1'b1 &&
         HRESP == HRESP_OKAY &&
         $past(HWRITE) == 1'b0 &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HRDATA))
    );
    c_hrdata_not_xz: cover property (
        HREADY == 1'b1 && HRESP == HRESP_OKAY &&
        $past(HWRITE) == 1'b0 && !$isunknown(HRDATA)
    );

    // DB3 — HRDATA not required valid during ERROR
    //       Spec  6.1.2: "ERROR responses do not require valid data"
    //       (Intentionally no assertion — permissive by spec)
    //       Cover: confirm ERROR scenario is reachable
    c_hrdata_during_error: cover property (
        HSEL && HRESP == HRESP_ERROR && HREADYOUT == 1'b0
    );

    // DB4 — HWDATA valid in write data phase (master drives)
    //       Spec  6.1.1: checked here as functional sanity
    a_hwdata_valid_after_write: assert property (
        (HSEL && $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         $past(HWRITE) == 1'b1 && HREADY) |->
        (!$isunknown(HWDATA))
    );
    c_hwdata_valid: cover property (
        $past(HWRITE) == 1'b1 &&
        HREADY && !$isunknown(HWDATA)
    );

    // ============================================================
    //  [5] SIGNAL INTEGRITY — SLAVE OUTPUTS  
    // ============================================================

    // SI1 — HRESP valid encoding only
    //       Spec  5.1 Table: OKAY=0, ERROR=1
    a_hresp_valid: assert property (
        (!$isunknown(HRESP)) &&
        (HRESP inside {HRESP_OKAY, HRESP_ERROR})
    );
    c_hresp_error_seen: cover property (
        HRESP == HRESP_ERROR
    );

    // SI2 — HREADYOUT no X/Z
    //      Spec 2.3 : handshake signal integrity
    a_hreadyout_no_xz: assert property (
        (!$isunknown(HREADYOUT))
    );
    c_hreadyout_low: cover property (
        HREADYOUT == 1'b0
    );
 

    // ============================================================
    //  [6] WRITE CORRECTNESS  —  Functional
    // ============================================================

    // WC1 — Data written to A must be readable from A
    a_write_read_correctness: assert property (
    (valid_ph && write_ph &&                    // data phase of write
     HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
     HWRITE == 1'b0 &&                          // current is read
     HADDR == addr_ph) |=>                      // same address
    (HRDATA == hwdata_ph)
);
   
    c_write_then_read: cover property (
        valid_ph && write_ph && HREADY &&
        HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // WC2 — No memory change without valid write
    a_no_change_without_write: assert property (
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );
    c_read_no_side_effect: cover property (
        valid_ph && !write_ph && HREADY &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // WC3 — Back-to-back writes: latest value wins
    a_latest_write_wins: assert property (
    (valid_ph && write_ph &&
     HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
     HWRITE == 1'b0 &&
     HADDR == addr_ph) |=>
    (HRDATA == hwdata_ph)
);
    c_back2back_write: cover property (
        valid_ph && write_ph && HREADY && HADDR == addr_ph
    );

    // WC4 — Word write atomically updates all 4 bytes
    a_word_write_atomic: assert property (
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B32 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA[31:0] == hwdata_ph[31:0])
    );
    c_word_write: cover property (
        valid_ph && write_ph && size_ph == HSIZE_B32 && HREADY
    );

    // WC5 — Memory unchanged during read
    a_no_mem_change_on_read: assert property (
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );
    c_read_no_change: cover property (
        valid_ph && !write_ph && HREADY &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // WC6 — HWDATA ignored during read (HRDATA not X/Z)
    a_hwdata_ignored_read: assert property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HREADY) |->
        (!$isunknown(HRDATA))
    );
    c_read_hrdata_valid: cover property (
        HSEL && HWRITE == 1'b0 && HREADY && !$isunknown(HRDATA)
    );

    // ============================================================
    //  [7] BYTE & HALF-WORD MASKING  —  Functional
    // ============================================================

    // M1 — Byte write: only targeted byte changes
    a_byte_write_targeted: assert property (
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B8 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1:0] == 2'b00) ? (HRDATA[7:0]   == hwdata_ph[7:0])   :
          (addr_ph[1:0] == 2'b01) ? (HRDATA[15:8]  == hwdata_ph[15:8])  :
          (addr_ph[1:0] == 2'b10) ? (HRDATA[23:16] == hwdata_ph[23:16]) :
                                    (HRDATA[31:24] == hwdata_ph[31:24]) )
    );
    c_byte_write: cover property (
        valid_ph && write_ph && size_ph == HSIZE_B8 && HREADY
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
    c_byte_no_corrupt: cover property (
        valid_ph && write_ph && size_ph == HSIZE_B8 &&
        HREADY && addr_ph[1:0] == 2'b00
    );

    // M3 — Half-word write: only targeted 2 bytes change
    a_hword_write_targeted: assert property (
        (HSEL && valid_ph && write_ph &&
         size_ph == HSIZE_B16 &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        ( (addr_ph[1] == 1'b0) ? (HRDATA[15:0]  == hwdata_ph[15:0])  :
                                  (HRDATA[31:16] == hwdata_ph[31:16]) )
    );
    c_hword_write: cover property (
        valid_ph && write_ph && size_ph == HSIZE_B16 && HREADY
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
    c_hword_no_corrupt: cover property (
        valid_ph && write_ph && size_ph == HSIZE_B16 &&
        HREADY && addr_ph[1] == 1'b0
    );

    // ============================================================
    //  [8] READ CORRECTNESS  —  Functional
    // ============================================================

    // RC1 — Consecutive reads same address: identical data
    a_consec_reads_same_data: assert property (
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == $past(HRDATA))
    );
    c_two_reads_same: cover property (
        valid_ph && !write_ph && HREADY &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // RC2 — First read after reset: no X/Z on HRDATA
    a_first_read_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn) ##1
         (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
          HWRITE == 1'b0 && HREADY && HRESP == HRESP_OKAY)) |=>
        (!$isunknown(HRDATA))
    );
    c_first_read_post_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##[1:5]
        (HSEL && HWRITE == 1'b0 && HREADY && !$isunknown(HRDATA))
    );

    // RC3 — Read-after-write returns latest data
    a_read_after_write: assert property (
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 &&
         HADDR  == addr_ph && HSIZE == size_ph) |=>
        (HRDATA == hwdata_ph)
    );
    c_raw_scenario: cover property (
        valid_ph && write_ph && HREADY &&
        HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // RC4 — Read data not X/Z
    a_read_data_not_xz: assert property (
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY) |->
        (!$isunknown(HRDATA))
    );
    c_read_not_xz: cover property (
        valid_ph && !write_ph && HREADY &&
        HRESP == HRESP_OKAY && !$isunknown(HRDATA)
    );

    // ============================================================
    //  [9] PIPELINE  —  Functional
    // ============================================================

    // P1 — Write data phase overlapping next addr: HWDATA valid
    a_pipeline_write_correct: assert property (
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) |->
        (!$isunknown(HWDATA))
    );
    c_pipeline_write: cover property (
        valid_ph && write_ph && HREADY &&
        HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}
    );

    // P2 — No data leakage between pipelined transactions
    a_no_data_leakage: assert property (
        (HSEL && valid_ph && !write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HADDR != addr_ph) |=>
        (!$isunknown(HRDATA))
    );
    c_pipeline_no_leak: cover property (
        valid_ph && !write_ph && HREADY &&
        HADDR != addr_ph && !$isunknown(HRDATA)
    );

    // P3 — Back-to-back R/W ordering preserved
    a_pipeline_rw_ordering: assert property (
        (HSEL && valid_ph && write_ph &&
         HREADY && HRESP == HRESP_OKAY &&
         HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HWRITE == 1'b0 && HADDR == addr_ph) |=>
        (HRDATA == hwdata_ph)
    );
    c_pipeline_rw: cover property (
        valid_ph && write_ph && HREADY &&
        HWRITE == 1'b0 && HADDR == addr_ph
    );

    // P4 — Address/data phase association correct
    a_pipeline_addr_data_assoc: assert property (
        (HSEL && valid_ph && write_ph && HREADY) |->
        (!$isunknown(HWDATA))
    );
    c_pipeline_assoc: cover property (
        valid_ph && write_ph && HREADY && !$isunknown(HWDATA)
    );

    // ============================================================
    //  [10] ADDRESS & BOUNDARY   
    // ============================================================

    // A1 Spec 4.1.1 — Out-of-range address  HRESP=ERROR  
    a_out_of_range_error: assert property (
        (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
         HREADY && HADDR > MAX_ADDR) |=>
        (HRESP == HRESP_ERROR)
    );
    c_out_of_range: cover property (
        HSEL && HTRANS == HTRANS_NONSEQ &&
        HREADY && HADDR > MAX_ADDR
    );

    

    // A3 — INCR burst within memory
    a_incr_no_mem_boundary_cross: assert property (
        (HSEL && HTRANS inside {HTRANS_SEQ, HTRANS_BUSY} &&
         HBURST inside {HBURST_INCR,  HBURST_INCR4,
                        HBURST_INCR8, HBURST_INCR16} &&
         HREADY) |->
        (HADDR <= MAX_ADDR)
    );
    c_incr_within_mem: cover property (
        HSEL && HTRANS == HTRANS_SEQ &&
        HBURST == HBURST_INCR4 && HREADY &&
        HADDR <= MAX_ADDR
    );
     
       
    // ============================================================
    //  [11] RESET  
    // ============================================================

    //Spec 7
    // R1 — HREADY high within RESET_BOUND cycles after reset
    //      Spec  7: "After reset HREADY must return high"
    a_hready_high_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn)) |->
        ##[1:RESET_BOUND] (HREADYOUT == 1'b1)
    );
    c_hready_post_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##[1:RESET_BOUND] HREADYOUT == 1'b1
    );

    // R2 — HRESP = OKAY within RESET_BOUND cycles after reset
    a_hresp_okay_after_reset: assert property (
        @(posedge HCLK)
        ($rose(HRESETn)) |->
        ##[1:RESET_BOUND] (HRESP == HRESP_OKAY)
    );
    c_hresp_post_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##[1:RESET_BOUND] HRESP == HRESP_OKAY
    );

    // R3 — Ongoing transaction aborts cleanly on reset
    a_reset_aborts_transaction: assert property (
        @(posedge HCLK)
        (!HRESETn &&
         $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ}) |=>
        (HTRANS == HTRANS_IDLE)
    );
    c_reset_mid_tx: cover property (
        @(posedge HCLK)
        !HRESETn && $past(HTRANS) == HTRANS_SEQ
    );

    // R4 — Memory not corrupted after mid-transaction reset
    a_reset_no_mem_corrupt: assert property (
        @(posedge HCLK)
        ($rose(HRESETn) ##[1:10]
         (HSEL && HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
          HWRITE == 1'b0 && HREADY && HRESP == HRESP_OKAY)) |=>
        (!$isunknown(HRDATA))
    );
    c_read_post_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##[1:10]
        (HSEL && HWRITE == 1'b0 && HREADY && !$isunknown(HRDATA))
    );

    // R5 — HTRANS = IDLE immediately after reset
    a_htrans_idle_after_reset: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HTRANS == HTRANS_IDLE)
    );
    c_idle_post_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##1 HTRANS == HTRANS_IDLE
    );

    // R6 — HREADYOUT = 1 immediately after reset
    a_hreadyout_reset_default: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HREADYOUT == 1'b1)
    );
    c_hreadyout_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##1 HREADYOUT == 1'b1
    );

    // R7 — HRESP = OKAY immediately after reset
    a_hresp_reset_default: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HRESP == HRESP_OKAY)
    );
    c_hresp_reset: cover property (
        @(posedge HCLK)
        $rose(HRESETn) ##1 HRESP == HRESP_OKAY
    );
  
    a_wrap4_byte_region: assert property (
    (HSEL && HBURST == HBURST_WRAP4 && HSIZE == HSIZE_BYTE &&
     HTRANS == HTRANS_SEQ && HREADY) |->
    (HADDR[HADDR_SIZE-1:2] == burst_start_addr[HADDR_SIZE-1:2])
    );

    a_wrap4_word_region: assert property (
        (HSEL && HBURST == HBURST_WRAP4 && HSIZE == HSIZE_WORD &&
        HTRANS == HTRANS_SEQ && HREADY) |->
        (HADDR[HADDR_SIZE-1:4] == burst_start_addr[HADDR_SIZE-1:4])
    );

    a_wrap8_word_region: assert property (
        (HSEL && HBURST == HBURST_WRAP8 && HSIZE == HSIZE_WORD &&
        HTRANS == HTRANS_SEQ && HREADY) |->
        (HADDR[HADDR_SIZE-1:5] == burst_start_addr[HADDR_SIZE-1:5])
    );

    a_wrap16_word_region: assert property (
        (HSEL && HBURST == HBURST_WRAP16 && HSIZE == HSIZE_WORD &&
        HTRANS == HTRANS_SEQ && HREADY) |->
        (HADDR[HADDR_SIZE-1:6] == burst_start_addr[HADDR_SIZE-1:6])
    );
    
    endmodule