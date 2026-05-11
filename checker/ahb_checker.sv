//  AHB Lite SVA Checker — DUT Assertions Only
//  Project  : EE-5214 AMBA AHB-Lite RAM Verification
//  DUT      : ahb3liten and sram
//  Role     : B — Assertions & Formal
//  Spec     : ARM IHI0033A
//
 
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

    localparam SLAVE_MAX_ADDR = 32'h3FF;  // 1KB boundary
    localparam [HADDR_SIZE-1:0] MAX_ADDR = (MEM_DEPTH * (HDATA_SIZE/8)) - 1;


    default clocking ahb_clk @(posedge HCLK); endclocking
    default disable iff (!HRESETn);
 
    logic nonexistent_addr;
    assign nonexistent_addr = (HADDR > SLAVE_MAX_ADDR);
 
  
    //  [1] SLAVE RESPONSE RULES  
   
    //Spec  3.2: "Slave must always provide zero wait state
    //OKAY response to BUSY transfers"
    a_idle_okay_only: assert property (
    (HSEL && HTRANS == HTRANS_IDLE) |->
    (HRESP == HRESP_OKAY)
    );
    c_idle_seen: cover property (
    HSEL && HTRANS == HTRANS_IDLE && HRESP == HRESP_OKAY
    );

    a_busy_okay_only: assert property (
    (HSEL && HTRANS == HTRANS_BUSY) |->
    (HRESP == HRESP_OKAY)
    );
    c_busy_in_burst: cover property (
    HSEL &&
    $past(HTRANS) inside {HTRANS_NONSEQ, HTRANS_SEQ} &&
    HTRANS == HTRANS_BUSY
    );


    //4.1.1: If a NONSEQUENTIAL or SEQUENTIAL transfer is attempted to a nonexistent
    // address location then the default slave provides an ERROR response.
    // IDLE or BUSY transfers to nonexistent locations result in a okay response

    // 4.1.1 — NONSEQ/SEQ to nonexistent : ERROR 
    a_non_and_seq_nonexsistent_error: assert property (@(posedge HCLK) disable iff (!HRESETn)
        ((HTRANS == HTRANS_NONSEQ|| HTRANS == HTRANS_SEQ) && nonexistent_addr)
        |=> (HRESP == HRESP_ERROR)
    );

    c_non_and_seq_nonexsistent_error:cover property (@(posedge HCLK) disable iff (!HRESETn)
        ((HTRANS == HTRANS_NONSEQ|| HTRANS == HTRANS_SEQ) && nonexistent_addr)
        ##1 (HRESP == HRESP_ERROR)
    );
 
    // IDLE/BUSY to nonexistent : OKAY  
    a_idle_busy_nonexsistent_okay: assert property (@(posedge HCLK) disable iff (!HRESETn)
        ((HTRANS == HTRANS_IDLE || HTRANS == HTRANS_BUSY) && nonexistent_addr)
        |=> (HRESP == HRESP_OKAY)
    );

    c_idle_busy_nonexsistent_okay: cover property (@(posedge HCLK) disable iff (!HRESETn)
        ((HTRANS == HTRANS_IDLE || HTRANS == HTRANS_BUSY) && nonexistent_addr)
        ##1 (HRESP == HRESP_OKAY)
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


    
    logic HRESETn_q;
    always @(posedge HCLK) HRESETn_q <= HRESETn;
 
    
    logic valid_write_addr_phase;
    assign valid_write_addr_phase = HSEL & HWRITE &
                                    (HTRANS != HTRANS_IDLE) &
                                    (HTRANS != HTRANS_BUSY);

    logic read_active;
    assign read_active = HSEL & ~HWRITE & HREADY &
                        (HTRANS != HTRANS_IDLE) &
                        (HTRANS != HTRANS_BUSY);

  //-----------------------------------------------------------
  // Registered address/write-enable (data phase tracking)
  //-----------------------------------------------------------
    logic              we_q;
    logic [HADDR_SIZE-1:0] waddr_q;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
        we_q    <= '0;
        waddr_q <= '0;
        end else if (HREADY) begin
        we_q    <= HSEL & HWRITE &
                    (HTRANS != HTRANS_IDLE) &
                    (HTRANS != HTRANS_BUSY);
        waddr_q <= HADDR;
        end
    end

    //-----------------------------------------------------------
    // FUNC-1: Data written to A must be readable from A
    //         Address phase  -> t0  (HTRANS_NONSEQ or SEQ, HWRITE)
    //         Data    phase  -> t1  (HREADY high, latch HWDATA)
    //         Read    phase  -> any later cycle to same address
    //-----------------------------------------------------------
    
        logic HRESETn_q;
        always @(posedge HCLK) HRESETn_q <= HRESETn;
        
        property write_then_read_data_integrity;
        logic [HDATA_SIZE-1:0] wd;
        logic [HADDR_SIZE-1:0] wa;

        (
            HRESETn_q &&
            HSEL && HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}),
            wa = HADDR
        )
        ##1
        (we_q && (waddr_q == wa)) [->1]
        ##0
        (1, wd = HWDATA)
        ##1
        (
            !(HSEL && HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HADDR == wa))
        ) [*0:$]
        ##1
        (
            HSEL && !HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HADDR == wa)
        )
        |->
        ##1 (HRDATA == wd);   
        endproperty
            
        FUNC_WRITE_READ_INTEGRITY: assert property (write_then_read_data_integrity);

        //-----------------------------------------------------------
        // RESET BEHAVIOR CHECK
        //-----------------------------------------------------------
        property hreadyout_high_after_reset;
        @(posedge HCLK)
        (HRESETn)
        |=>
        ##[0:4] (HREADYOUT == 1'b1 && HRESP == HRESP_OKAY);
        endproperty

        FUNC2_HREADYOUT_AFTER_RST: assert property (hreadyout_high_after_reset);
        
        COVER_READY_AFTER_RST: cover property (
        @(posedge HCLK)
        (HRESETn)
        |=>
        ##[0:4] (HREADYOUT && (HRESP == HRESP_OKAY))
        );
        
        property byte_write_no_side_effect;
        logic [HDATA_SIZE-1:0] rdb; 
        logic [HADDR_SIZE-1:0] ba;  
        logic [1:0]            byte_lane;
        (
            HRESETn_q &&
            HSEL && !HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HSIZE == HSIZE_WORD) &&
        (HADDR[1:0] == 2'b00),

        ba        = HADDR,
        byte_lane = HADDR[1:0]
        )
        ##2
        (1, rdb = HRDATA)
        ##1
        (
            HSEL && HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HSIZE == HSIZE_BYTE) &&
            (HADDR[HADDR_SIZE-1:2] == ba[HADDR_SIZE-1:2]),
            byte_lane = HADDR[1:0]
        )
        ##1
        (HREADY && we_q && (waddr_q[HADDR_SIZE-1:2] == ba[HADDR_SIZE-1:2]))
        ##1
        (
            HSEL && !HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HSIZE == HSIZE_WORD) &&
            (HADDR == ba)
        )
        |->
        ##1
        (
            ((byte_lane == 2'b00) ->
            (HRDATA[31:8] == rdb[31:8])) &&

            ((byte_lane == 2'b01) ->
            ({HRDATA[31:16], HRDATA[7:0]} ==
            {rdb[31:16],   rdb[7:0]})) &&

            ((byte_lane == 2'b10) ->
            ({HRDATA[31:24], HRDATA[15:0]} ==
            {rdb[31:24],   rdb[15:0]})) &&

            ((byte_lane == 2'b11) ->
            (HRDATA[23:0] == rdb[23:0]))
        );
        endproperty
          
        FUNC3_BYTE_WRITE_NO_SIDE_EFFECT:assert property (byte_write_no_side_effect);
        //------------------------------------------------------------
        // FUNC-4: No memory location changes without
        //         a valid write transaction
        //------------------------------------------------------------
        // STEP 1: Read karo — data capture karo
        property no_spurious_write;
        logic [HDATA_SIZE-1:0] rdb;
        logic [HADDR_SIZE-1:0] ra;

        // STEP 1: Read address phase pakdo
        (
            HRESETn_q &&
            HSEL && !HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}),
            ra = HADDR
        ) 
        ##1 (HREADY, rdb = HRDATA)

        // STEP 2: Koi write nahi same address pe
        ##1 (!(
            HSEL && HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HADDR == ra)
        )) [*1:$]

        // STEP 3: Wapas same address read
        ##1 (
            HSEL && !HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HADDR == ra)
        )
 
        |-> ##1 (HREADY ##0 (HRDATA == rdb));

        endproperty 
        FUNC4_NO_SPURIOUS_WRITE: assert property (no_spurious_write)
        else $error("[FUNC-4 FAIL] Memory changed without valid write! Time=%0t",
                    $time);

        //------------------------------------------------------------
        // Cover
        //------------------------------------------------------------
        property cover_no_spurious_write;
        logic [HADDR_SIZE-1:0] ca;

        (HRESETn_q &&
        HSEL && !HWRITE && HREADY &&
        (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}),
        ca = HADDR)
        ##1 (1)
        ##1
        (!(HSEL && HWRITE && HREADY &&
            (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
            (HADDR == ca))
        ) [*1:$]
        ##1
        (HSEL && !HWRITE && HREADY &&
        (HTRANS inside {HTRANS_NONSEQ, HTRANS_SEQ}) &&
        (HADDR == ca));
        endproperty

        COVER_NO_SPURIOUS_WRITE: cover property (cover_no_spurious_write);

endmodule

