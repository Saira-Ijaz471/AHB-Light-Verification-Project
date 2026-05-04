module tb_top;
timeunit 1ns;
timeprecision 1ns;
import ahb3lite_pkg::*;
`include "ahb_master.sv"

localparam MEM_SIZE          = 32;
localparam MEM_DEPTH         = 256;
localparam HADDR_SIZE        = 16;
localparam HDATA_SIZE        = 32;
localparam BE_SIZE           = (HDATA_SIZE+7)/8;

//AHB SIGNALS
logic HCLK;
logic HRESETn;
int                    ok;
logic [31:0]           sb_out;
logic [BE_SIZE-1:0]    be_tb;

//CLK GENERATION
initial begin
    HCLK = 1'b0;
    forever #5 HCLK = ~HCLK;
end

//EVENT FOR SYNCHRONIZATION
event master_done;

//DUT INSTANTIATION
ahb3liten #(
    .MEM_SIZE   (32),
    .MEM_DEPTH  (256),
    .HADDR_SIZE (16),
    .HDATA_SIZE (32)
) dut (
    .HCLK      (ahb_if.HCLK),
    .HRESETn   (HRESETn),
    .HSEL      (ahb_if.HSEL),
    .HADDR     (ahb_if.HADDR),
    .HWDATA    (ahb_if.HWDATA),
    .HRDATA    (ahb_if.HRDATA),
    .HWRITE    (ahb_if.HWRITE),
    .HSIZE     (ahb_if.HSIZE),
    .HBURST    (ahb_if.HBURST),
    .HTRANS    (ahb_if.HTRANS),
    .HPROT     (ahb_if.HPROT),
    .HREADY    (ahb_if.HREADY),
    .HREADYOUT (ahb_if.HREADYOUT),
    .HRESP     (ahb_if.HRESP)
);

assign be_tb         = dut.be;


//DIRECTED TESTS INSTANCE
directed_tests #( .MEM_SIZE  ( 32),
                  .MEM_DEPTH (256),
                  .HADDR_SIZE( 16),
                  .HDATA_SIZE( 32)
) directed_tb (
    .HCLK      (ahb_if_directed.HCLK),
    .HRESETn   (HRESETn),
    .HSEL      (ahb_if_directed.HSEL),
    .HADDR     (ahb_if_directed.HADDR),
    .HWDATA    (ahb_if_directed.HWDATA),
    .HRDATA    (ahb_if_directed.HRDATA),
    .HWRITE    (ahb_if_directed.HWRITE),
    .HSIZE     (ahb_if_directed.HSIZE),
    .HBURST    (ahb_if_directed.HBURST),
    .HTRANS    (ahb_if_directed.HTRANS),
    .HPROT     (ahb_if_directed.HPROT),
    .HREADY    (ahb_if_directed.HREADY),
    .HREADYOUT (ahb_if_directed.HREADYOUT),
    .HRESP     (ahb_if_directed.HRESP)
);


//INTERFACE
ahb_if #(16,32) ahb_if(HCLK);
ahb_if #(16,32) ahb_if_directed(HCLK);   


//MASTER CLASS INSTANCE
ahb_master m;


//COVERFILE
ahb_cov #(16,32) cov (
    .HCLK      (ahb_if.HCLK),
    .HRESETn   (HRESETn),
    .HSEL      (ahb_if.HSEL),
    .HADDR     (ahb_if.HADDR),
    .HWDATA    (ahb_if.HWDATA),
    .HRDATA    (ahb_if.HRDATA),
    .HWRITE    (ahb_if.HWRITE),
    .HSIZE     (ahb_if.HSIZE),
    .HBURST    (ahb_if.HBURST),
    .HTRANS    (ahb_if.HTRANS),
    .HPROT     (ahb_if.HPROT),
    .HREADY    (ahb_if.HREADY),
    .HREADYOUT (ahb_if.HREADYOUT),
    .HRESP     (ahb_if.HRESP),
    .be        (be_tb)
);


//CONNECT MASTER
initial begin
    HRESETn = 0;
    ahb_if.HSEL    = 0;
    ahb_if.HADDR   = 0;
    ahb_if.HWDATA  = 0;
    ahb_if.HWRITE  = 0;
    ahb_if.HSIZE   = 0;
    ahb_if.HBURST  = 0;
    ahb_if.HTRANS  = 0;
    ahb_if.HREADY  = 0;
    ahb_if.HPROT   = 0;

    repeat(2) @(posedge HCLK);
    HRESETn = 1;
    ahb_if.HREADY  = 1;
    
    m = new(ahb_if);

    for (int i = 0; i < 10000; i++) begin
        ok = m.randomize();
        m.drive(sb_out);
    end

    $display("Simulation finished: 10000 transactions done");
    -> master_done;               //trigger event
end

//DIRECTED TESTS
initial begin
    @(master_done);               //wait for master to complete
    directed_tb.reset_dut();
  
    //SINGLE read and write for byte, halfword, and word sizes
    directed_tb.ahb_write(1, 32'h10, 32'haaaaaaaa, HSIZE_BYTE);
    directed_tb.ahb_write(1, 32'h74, 32'hbbbbbbbb, HSIZE_HWORD);
    directed_tb.ahb_write(1, 32'h64, 32'hdeadbeaf, HSIZE_WORD);

    directed_tb.ahb_read(0, 32'h10, HSIZE_BYTE,  directed_tb.rdata_tb);
    directed_tb.ahb_read(0, 32'h74, HSIZE_HWORD, directed_tb.rdata_tb);
    directed_tb.ahb_read(0, 32'h64, HSIZE_WORD,  directed_tb.rdata_tb);

    //INCR4, INCR8, INCR16 — write then read back all beats
    directed_tb.burst_incr(4,  32'h10, 32'h67083581, HSIZE_WORD);
    directed_tb.burst_incr(8,  32'h20, 32'h25641869, HSIZE_WORD);
    directed_tb.burst_incr(16, 32'h50, 32'h51015286, HSIZE_WORD);

    directed_tb.burst_incr(4,  32'h1f, 32'h91, HSIZE_BYTE);
    directed_tb.burst_incr(8,  32'h2b, 32'h2d, HSIZE_BYTE);
    directed_tb.burst_incr(16, 32'h3e, 32'he7, HSIZE_BYTE);

    directed_tb.burst_incr(4,  32'h10, 32'hA1B2, HSIZE_HWORD);
    directed_tb.burst_incr(8,  32'h20, 32'h3C4D, HSIZE_HWORD);
    directed_tb.burst_incr(16, 32'h50, 32'h5286, HSIZE_HWORD);

    //WRAP4, WRAP8, WRAP16 — verify the address actually wraps at the right boundary
    directed_tb.burst_wrap(32'h80, HSIZE_BYTE, HBURST_WRAP4,  32'ha0);
    directed_tb.burst_wrap(32'h11, HSIZE_BYTE, HBURST_WRAP8,  32'h77);
    directed_tb.burst_wrap(32'h20, HSIZE_BYTE, HBURST_WRAP16, 32'h55);

    directed_tb.burst_wrap(32'h00, HSIZE_HWORD, HBURST_WRAP4,  32'hb1c2);
    directed_tb.burst_wrap(32'h10, HSIZE_HWORD, HBURST_WRAP8,  32'hd3e4);
    directed_tb.burst_wrap(32'h20, HSIZE_HWORD, HBURST_WRAP16, 32'h9a7b);

    directed_tb.burst_wrap(32'hc0, HSIZE_WORD, HBURST_WRAP4,  32'h67083581);
    directed_tb.burst_wrap(32'h98, HSIZE_WORD, HBURST_WRAP8,  32'h66776677);
    directed_tb.burst_wrap(32'h2c, HSIZE_WORD, HBURST_WRAP16, 32'hdeaddead);

    //Back-to-back transfers with no IDLE between
    directed_tb.back_to_back(HSIZE_WORD);
    directed_tb.back_to_back(HSIZE_HWORD);
    directed_tb.back_to_back(HSIZE_BYTE);

    //HREADY=0 — slave inserts wait states, master must hold address phase
    directed_tb.test_hready_hold();

    //RAW
    directed_tb.ahb_write(1, 32'h64, 32'hdeadbeaf, HSIZE_WORD);
    directed_tb.ahb_read (0, 32'h64, HSIZE_WORD,  directed_tb.rdata_tb);
    $finish;
end

endmodule
