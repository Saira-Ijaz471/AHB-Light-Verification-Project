module directed_tests
import ahb3lite_pkg::*;
#(
    parameter MEM_SIZE    = 32,
    parameter MEM_DEPTH   = 256,
    parameter HADDR_SIZE  = 16,
    parameter HDATA_SIZE  = 32
)(
    output logic                      HRESETn,
    input  logic                      HCLK,

    output logic                      HSEL,
    output logic [HADDR_SIZE-1:0]     HADDR,
    output logic [HDATA_SIZE-1:0]     HWDATA,
    input  logic [HDATA_SIZE-1:0]     HRDATA,
    output logic                      HWRITE,
    output logic [2:0]                HSIZE,
    output logic [2:0]                HBURST,
    output logic [3:0]                HPROT,
    output logic [1:0]                HTRANS,

    input  logic                      HREADYOUT,
    output logic                      HREADY,
    input  logic                      HRESP
);
timeunit 1ns;
timeprecision 1ns;
logic [31:0] rdata_tb;

//****************************************
//Reset
//****************************************
task reset_dut();
begin
    HSEL   = 0;
    HADDR  = 0;
    HWDATA = 0;
    HWRITE = 0;
    HSIZE  = 0;
    HBURST = 0;
    HPROT  = 0;
    HTRANS = HTRANS_IDLE;
    HREADY = 1;

    HRESETn = 0;
    repeat(2) @(posedge HCLK);
    HRESETn = 1;
end
endtask

//****************************************
//AHB Write
//****************************************
task ahb_write(
    input  logic                  write,
    input  logic [HADDR_SIZE-1:0] addr,
    input  logic [HDATA_SIZE-1:0] data,
    input  logic [           2:0] size
);
begin
    //wait until bus is ready
    @(posedge HCLK);
    wait (HREADYOUT);

    //addr
    HSEL   <= #1 1'b1;
    HADDR  <= #1 addr;
    HWRITE <= #1 write;
    HSIZE  <= #1 size;
    HTRANS <= #1 HTRANS_NONSEQ;

    //data
    @(posedge HCLK);
    HWDATA <= #1 data;

    //wait for transfer completion
    while (!HREADYOUT) @(posedge HCLK);

    //end
    HTRANS <= #1 HTRANS_IDLE;
    HSEL   <= #1 1'b0;
end
endtask

//****************************************
//AHB Read
//****************************************
task ahb_read(
    input  logic                  write,
    input  logic [HADDR_SIZE-1:0] addr,
    input  logic [           2:0] size,
    output logic [HDATA_SIZE-1:0] rdata
);

begin
    //wait until bus is ready
    @(posedge HCLK);
    wait (HREADYOUT);

    //addr
    HSEL   <= #1 1'b1;
    HADDR  <= #1 addr;
    HWRITE <= #1 write;
    HSIZE  <= #1 size;
    HTRANS <= #1 HTRANS_NONSEQ;

    //data
    @(posedge HCLK); #1;
    wait (HREADYOUT);

    @(posedge HCLK); #1;
    //capture data
    rdata = #1 HRDATA;

    //end
    HTRANS <= #1 HTRANS_IDLE;
    HSEL   <= #1 1'b0;

end
endtask

//****************************************
//incr burst
//****************************************
task burst_incr(
    input int                    beats,
    input logic [HADDR_SIZE-1:0] start_addr,
    input logic [HDATA_SIZE-1:0] start_data,
    input logic [           2:0] size
);
int                    i;
logic [HADDR_SIZE-1:0] addr;
logic [HDATA_SIZE-1:0] data;
begin
    addr = start_addr;

    //wait until bus is ready
    @(posedge HCLK);
    wait (HREADYOUT);

    //addr
    HSEL   <= #1 1;
    HADDR  <= #1 addr;
    HWRITE <= #1 1;
    HSIZE  <= #1 size;
    HBURST <= #1 ((beats==4)  ? HBURST_INCR4  :
                  (beats==8)  ? HBURST_INCR8  :
                                HBURST_INCR16);
    HTRANS <= #1 HTRANS_NONSEQ;

    //data
    @(posedge HCLK);
    HWDATA <= #1 start_data;

    //beats
    for (i = 1; i < beats; i++) begin
        addr = addr + (1 << size);

        @(posedge HCLK);
        HADDR  <= #1 addr;
        HTRANS <= #1 HTRANS_SEQ;
        @(posedge HCLK);
        HWDATA <= #1 HWDATA + 1;
    end

    @(posedge HCLK);
    HTRANS <= #1 HTRANS_IDLE;
    HSEL   <= #1 0;
end
endtask

//****************************************
//wrap burst
//****************************************
task burst_wrap(
    input logic [HADDR_SIZE-1:0] start_addr,
    input logic [           2:0] size,
    input logic [           2:0] hburst,
    input logic [HDATA_SIZE-1:0] start_data
);

logic [HADDR_SIZE-1:0] base;
logic [HADDR_SIZE-1:0] wrap_base;
logic [HADDR_SIZE-1:0] addr;
logic [HDATA_SIZE-1:0] data;
logic [          31:0] beat_size;
logic [          31:0] wrap_size;
int                    beats;
int                    i;

begin
    base = start_addr;
    addr = start_addr;
    data = start_data;

    //bytes per transfer
    beat_size = (1 << size);

    //which wrap
    case (hburst)
        HBURST_WRAP4 : beats = 4;
        HBURST_WRAP8 : beats = 8;
        HBURST_WRAP16: beats = 16;
        default      : beats = 4;
    endcase

    //wrap region size
    wrap_size = beats * beat_size;
    wrap_base = start_addr & ~(wrap_size - 1);

    //wait until bus is ready
    @(posedge HCLK);
    wait (HREADYOUT);

    //addr
    HSEL   <= #1 1;
    HWRITE <= #1 1;
    HSIZE  <= #1 size;
    HBURST <= #1 hburst;
    HTRANS <= #1 HTRANS_NONSEQ;
    HADDR  <= #1 addr;
    
    //data
    @(posedge HCLK);
    HWDATA <= #1 data;
    data    = data + 1;

    //beats
    for (i = 1; i < beats; i++) begin
        addr = wrap_base + ((addr + beat_size - wrap_base) % wrap_size);

        @(posedge HCLK);
        HADDR  <= #1 addr;
        HTRANS <= #1 HTRANS_SEQ;
        @(posedge HCLK);
        HWDATA <= #1 data;

        data = data + 1;
    end

    //end
    @(posedge HCLK);
    HTRANS <= #1 HTRANS_IDLE;
    HSEL   <= #1 0;

end
endtask

//****************************************
//test back to back
//****************************************
task back_to_back(
    input  logic [           2:0] size
);
int                    i;
logic [HADDR_SIZE-1:0] addr;
logic [HDATA_SIZE-1:0] bbdata;
begin
    addr = 32'h18;

    for (i = 0; i < 10; i++) begin
        //wait until bus is ready
        @(posedge HCLK);
        wait (HREADYOUT);

        //addr
        HSEL   <= #1 1;
        HADDR  <= #1 addr;
        HSIZE  <= #1 size;
        HBURST <= #1 HBURST_SINGLE;
        HTRANS <= #1 HTRANS_NONSEQ;
        
        //read or write?
        if (i % 2 == 0) begin
            HWRITE <= #1 1;
            @(posedge HCLK);
            HWDATA <= #1 i + 1;
        end 
        else begin
            HWRITE <= #1 0;
        end

        //if read
        if (i % 2 != 0) begin
            //data
            @(posedge HCLK); #1;
            wait (HREADYOUT);

            //capture data
            @(posedge HCLK); #1;
            bbdata = HRDATA;
        end

        //wait for transfer completion
        while (!HREADYOUT) @(posedge HCLK);

        //end
        HTRANS <= #1 HTRANS_IDLE;
        HSEL   <= #1 1'b0;

        //nxt addr
        addr = #1 addr + (1 << size);

        if (i != 9) begin
            @(posedge HCLK);
            HTRANS <= #1 HTRANS_SEQ;
        end
    end

    //end
    @(posedge HCLK);
    HTRANS <= #1 HTRANS_IDLE;
    HSEL   <= #1 0;

end
endtask

//****************************************
//test HREADY = 0
//****************************************
task automatic test_hready_hold();

    logic [HADDR_SIZE-1:0] addr_prev;

    begin
        $display("[TEST] HREADY=0 hold check");
        
        //wait until bus is ready
        @(posedge HCLK);
        wait (HREADYOUT);
        
        //addr
        HSEL   <= #1 1;
        HADDR  <= #1 16'h0040;
        HWRITE <= #1 1;
        HTRANS <= #1 HTRANS_NONSEQ;
        HSIZE  <= #1 3'b010;
        HBURST <= #1 HBURST_INCR4;

        //data
        @(posedge HCLK);
        HWDATA <= #1 32'hAAAA_AAAA;

        //capture address phase signal
        addr_prev  = dut.raddr;

        //force wait state
        HREADY = #1 1'b0;

        //try to disturb signal
        @(posedge HCLK);
        HADDR  <= #1 16'h9999;

        @(posedge HCLK);
        //CHECK addr phase HOLD
        if (dut.waddr !== addr_prev)
            $display("FAIL: HADDR changed during HREADY=0");

        //release
        HREADY = #1 1'b1;

        @(posedge HCLK);
        $display("[TEST]HREADY hold test done");
    end

endtask

initial begin

    reset_dut();
  
    //SINGLE read and write for byte, halfword, and word sizes
    ahb_write(1, 32'h10, 32'haaaaaaaa, HSIZE_BYTE);
    ahb_write(1, 32'h74, 32'hbbbbbbbb, HSIZE_HWORD);
    ahb_write(1, 32'h64, 32'hdeadbeaf, HSIZE_WORD);

    ahb_read(0, 32'h10, HSIZE_BYTE,  rdata_tb);
    ahb_read(0, 32'h74, HSIZE_HWORD, rdata_tb);
    ahb_read(0, 32'h64, HSIZE_WORD,  rdata_tb);

    //INCR4, INCR8, INCR16 — write then read back all beats
    burst_incr(4,  32'h10, 32'h67083581, HSIZE_WORD);
    burst_incr(8,  32'h20, 32'h25641869, HSIZE_WORD);
    burst_incr(16, 32'h50, 32'h51015286, HSIZE_WORD);

    burst_incr(4,  32'h1f, 32'h91, HSIZE_BYTE);
    burst_incr(8,  32'h2b, 32'h2d, HSIZE_BYTE);
    burst_incr(16, 32'h3e, 32'he7, HSIZE_BYTE);

    burst_incr(4,  32'h10, 32'hA1B2, HSIZE_HWORD);
    burst_incr(8,  32'h20, 32'h3C4D, HSIZE_HWORD);
    burst_incr(16, 32'h50, 32'h5286, HSIZE_HWORD);

    //WRAP4, WRAP8, WRAP16 — verify the address actually wraps at the right boundary
    burst_wrap(32'h80, HSIZE_BYTE, HBURST_WRAP4,  32'ha0);
    burst_wrap(32'h11, HSIZE_BYTE, HBURST_WRAP8,  32'h77);
    burst_wrap(32'h20, HSIZE_BYTE, HBURST_WRAP16, 32'h55);

    burst_wrap(32'h00, HSIZE_HWORD, HBURST_WRAP4,  32'hb1c2);
    burst_wrap(32'h10, HSIZE_HWORD, HBURST_WRAP8,  32'hd3e4);
    burst_wrap(32'h20, HSIZE_HWORD, HBURST_WRAP16, 32'h9a7b);

    burst_wrap(32'hc0, HSIZE_WORD, HBURST_WRAP4,  32'h67083581);
    burst_wrap(32'h98, HSIZE_WORD, HBURST_WRAP8,  32'h66776677);
    burst_wrap(32'h2c, HSIZE_WORD, HBURST_WRAP16, 32'hdeaddead);

    //Back-to-back transfers with no IDLE between
    back_to_back(HSIZE_WORD);
    back_to_back(HSIZE_HWORD);
    back_to_back(HSIZE_BYTE);

    //HREADY=0 — slave inserts wait states, master must hold address phase
    test_hready_hold();

    $finish;

end

endmodule
