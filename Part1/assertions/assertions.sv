 
module ahb_lite_htrans_assertions #(
    parameter HADDR_SIZE = 32,
    parameter HDATA_SIZE = 32
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

    // ---- local parameters  ----------------------
    localparam IDLE   = 2'b00;
    localparam BUSY   = 2'b01;
    localparam NONSEQ = 2'b10;
    localparam SEQ    = 2'b11;

    localparam SINGLE = 3'b000;
    localparam INCR   = 3'b001;   // undefined length

    localparam OKAY   = 1'b0;
    localparam ERROR  = 1'b1;

    // ============================================================
    //  RULE 1 — HADDR must be aligned to HSIZE
    //           on every NONSEQ and SEQ transfer
    //
    //  HSIZE=0 (byte)     : any address
    //  HSIZE=1 (halfword) : HADDR[0]   == 0
    //  HSIZE=2 (word)     : HADDR[1:0] == 00
    // ============================================================
    a_haddr_aligned: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS inside {NONSEQ, SEQ} && HREADY) |->
        ( (HSIZE == 3'd0)                        ||
          (HSIZE == 3'd1 && HADDR[0]   == 1'b0)  ||
          (HSIZE == 3'd2 && HADDR[1:0] == 2'b00) )
    );

    // ============================================================
    //  RULE 2 — SEQ transfer can only follow NONSEQ or SEQ
    //           Never after IDLE or BUSY
    // ============================================================
    a_seq_after_nonseq_or_seq: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == SEQ && HREADY) |->
        ($past(HTRANS) inside {NONSEQ, SEQ})
    );

    // ============================================================
    //  RULE 3 — BUSY is illegal during SINGLE burst
    // ============================================================
    a_no_busy_in_single: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HBURST == SINGLE) |->
        (HTRANS != BUSY)
    );

    // ============================================================
    //  RULE 4 — BUSY only legal when continuing an active burst
    //           i.e. previous transfer must have been NONSEQ or SEQ
    // ============================================================
    a_busy_only_in_active_burst: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == BUSY && HREADY) |->
        ($past(HTRANS) inside {NONSEQ, SEQ, BUSY})
    );

    // ============================================================
    //  RULE 5 — HTRANS must always contain valid encoding
    //           IDLE(00) BUSY(01) NONSEQ(10) SEQ(11)
    // ============================================================
    a_htrans_valid_encoding: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        HTRANS inside {IDLE, BUSY, NONSEQ, SEQ}
    );

    // ============================================================
    //  RULE 6 — Only NONSEQ and SEQ may initiate a valid transfer
    //           IDLE and BUSY must be ignored by slave
    // ============================================================
    a_only_nonseq_seq_transfer: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS inside {IDLE, BUSY}) |->
        (HRESP == OKAY && HREADYOUT == 1'b1)
    );

    // ============================================================
    //  RULE 7 — HTRANS must return to IDLE immediately after reset
    // ============================================================
    a_htrans_idle_after_reset: assert property (
        @(posedge HCLK)
        (!HRESETn) |=> (HTRANS == IDLE)
    );

    // ============================================================
    //  RULE 8 — IDLE must get zero wait state OKAY response
    //           HREADY=1, HRESP=OKAY same cycle
    // ============================================================
    a_idle_zero_wait_okay: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == IDLE) |->
        (HREADYOUT == 1'b1 && HRESP == OKAY)
    );

    // ============================================================
    //  RULE 9 — IDLE transfer must be ignored by slave
    //           Checked via HRESP=OKAY  
    // ============================================================
    a_idle_ignored_hresp: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == IDLE) |->
        (HRESP == OKAY)
    );

    // ============================================================
    //  RULE 10 — During BUSY, address/control must reflect
    //            the NEXT transfer in the burst
    //            i.e. HADDR must have already incremented by HSIZE
    // ============================================================
    a_busy_addr_reflects_next: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == BUSY && HREADY &&
         $past(HTRANS) inside {NONSEQ, SEQ, BUSY}) |->
        ( (HSIZE == 3'd0 && HADDR == $past(HADDR) + 1)  ||
          (HSIZE == 3'd1 && HADDR == $past(HADDR) + 2)  ||
          (HSIZE == 3'd2 && HADDR == $past(HADDR) + 4)  )
    );

    // ============================================================
    //  RULE 11 — BUSY must get zero wait state OKAY response
    // ============================================================
    a_busy_zero_wait_okay: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == BUSY) |->
        (HREADYOUT == 1'b1 && HRESP == OKAY)
    );

    // ============================================================
    //  RULE 12 — BUSY transfer must be ignored by slave
    //            HRESP must be OKAY
    // ============================================================
    a_busy_ignored_hresp: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == BUSY) |->
        (HRESP == OKAY)
    );

    // ============================================================
    //  RULE 13 — BUSY as last cycle only allowed in
    //            undefined length burst (INCR)
    //            Fixed length bursts must not end on BUSY
    // ============================================================
    a_busy_last_only_in_incr: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == BUSY && HREADY &&
         $past(HTRANS) inside {NONSEQ, SEQ, BUSY}) |->
        ( (HBURST == INCR) ||
          ($past(HTRANS) != BUSY) )
    );

    // ============================================================
    //  RULE 14 — SEQ address must increment according to HSIZE
    //            HSIZE=0 : addr + 1
    //            HSIZE=1 : addr + 2
    //            HSIZE=2 : addr + 4 
    // ============================================================
    a_seq_addr_increment: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == SEQ && HREADY &&
         HBURST == INCR) |->
        ( (HSIZE == 3'd0 && HADDR == $past(HADDR) + 1)  ||
          (HSIZE == 3'd1 && HADDR == $past(HADDR) + 2)  ||
          (HSIZE == 3'd2 && HADDR == $past(HADDR) + 4)  )
    );

    // ============================================================
    //  RULE 15 — SEQ control signals must be identical
    //            to previous transfer (HSIZE, HBURST, HWRITE)
    // ============================================================
    a_seq_control_stable: assert property (
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS == SEQ && HREADY) |->
        ( HSIZE  == $past(HSIZE)  &&
          HBURST == $past(HBURST) &&
          HWRITE == $past(HWRITE) )
    );

endmodule