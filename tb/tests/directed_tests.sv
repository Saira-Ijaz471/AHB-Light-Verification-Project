module directed_tests
import ahb3lite_pkg::*;
#(
    parameter MEM_SIZE          = 32,
    parameter MEM_DEPTH         = 256,
    parameter HADDR_SIZE        = 16,
    parameter HDATA_SIZE        = 32
)
(
    output                      HRESETn,
    input                       HCLK,

    output                      HSEL,
    output     [HADDR_SIZE-1:0] HADDR,
    output     [HDATA_SIZE-1:0] HWDATA,
    input  reg [HDATA_SIZE-1:0] HRDATA,
    output                      HWRITE,
    output     [           2:0] HSIZE,
    output     [           2:0] HBURST,
    output     [           3:0] HPROT,
    output     [           1:0] HTRANS,
    input  reg                  HREADYOUT,
    output                      HREADY,
    input                       HRESP
);

logic [31:0] data_tb;

task reset_dut();
    begin
        HRESETn = 0;
        @(posedge HCLK);
        HRESETn = 1;
    end
endtask

task ahb_write(
    input [31:0] addr,
    input [31:0] data,
    input [ 2:0] hsize);
    begin
        @(posedge HCLK);
        HSEL   = 1;
        HADDR  = addr;
        HWRITE = 1;
        HTRANS = 2'b10;  //NONSEQ
        HBURST = 3'b000; //SINGLE
        HSIZE  = hsize;
        HWDATA = data;

        @(posedge HCLK);
        HTRANS = 2'b00; //IDLE
    end
endtask

task ahb_read(
    input  [31:0] addr,
    input  [ 2:0] hsize,
    output [31:0] rdata);
    begin
        @(posedge HCLK);
        HSEL   = 1;
        HADDR  = addr;
        HWRITE = 0;
        HTRANS = 2'b10;
        HBURST = 3'b000;
        HSIZE  = hsize;

        @(posedge HCLK); \\\\\\\\\
        wait (HREADYOUT == 1);
        rdata = HRDATA;
        HTRANS = 2'b00;
    end
endtask

//TEST 1
task test1_byte_write();
    begin
        ahb_write(32'h10, 32'haa, 3'b000);
    end
endtask

//TEST 2
task test2_halfword_write();
    begin
        ahb_write(32'h72, 32'hbbbb, 3'b001);
    end
endtask

//TEST 3
task test3_word_write();
    begin
        ahb_write(32'h64, 32'hdeadbeef, 3'b010);
    end
endtask

//TEST 4, 5, 6
task test_read(
    input [31:0] addr,
    input [ 2:0] size);
    begin
        ahb_read(addr, size);
    end
endtask

//TEST 7
task test_contention();
    begin
        ahb_write(32'h10, 32'h12345678, 3'b010);
        ahb_read (32'h10, 3'b010);
    end
endtask

//TEST 8
task test_incr4();
    begin
        HBURST = 3'b011; //INCR4

        @(posedge HCLK);
        HSEL   = 1;
        HWRITE = 1;
        HTRANS = 2'b10; //NONSEQ
        HSIZE  = 3'b010;
        HADDR  = 32'h10;
        HWDATA = 32'h0;

        //next beats
        repeat (3) begin
            @(posedge HCLK);
            HTRANS = 2'b11; //SEQ
            HWDATA = HWDATA + 1;
        end

        @(posedge HCLK);
        HTRANS = 2'b00;
    end
endtask

//TEST 9
task test_incr8();
    begin
        HBURST = 3'b101; //INCR8

        @(posedge HCLK);
        HSEL   = 1;
        HWRITE = 1;
        HTRANS = 2'b10; //NONSEQ
        HSIZE  = 3'b010;
        HADDR  = 32'h20;
        HWDATA = 32'h0;

        //next beats
        repeat (7) begin
            @(posedge HCLK);
            HTRANS = 2'b11; //SEQ
            HWDATA = HWDATA + 1;
        end

        @(posedge HCLK);
        HTRANS = 2'b00;
    end
endtask

//TEST 10
task test_incr16();
    begin
        HBURST = 3'b111; //INCR16

        @(posedge HCLK);
        HSEL   = 1;
        HWRITE = 1;
        HTRANS = 2'b10; //NONSEQ
        HSIZE  = 3'b010;
        HADDR  = 32'h50;
        HWDATA = 32'h0;

        //next beats
        repeat (15) begin
            @(posedge HCLK);
            HTRANS = 2'b11; //SEQ
            HWDATA = HWDATA + 1;
        end

        @(posedge HCLK);
        HTRANS = 2'b00;
    end
endtask

//TEST 11
task test_wrap4();
    begin
        HBURST = 3'b010; //WRAP4

        @(posedge HCLK);
        HSEL   = 1;
        HWRITE = 1;
        HTRANS = 2'b10;      //NONSEQ
        HSIZE  = 3'b010;     //WORD
        HADDR  = 32'h0c;
        HWDATA = 32'ha0;

        repeat (3) begin
            @(posedge HCLK);
            HTRANS = 2'b11;     //SEQ
            HWDATA = HWDATA + 1;
        end

        @(posedge HCLK);
        HTRANS = 2'b00;
        HSEL   = 0;
    end
endtask

//TEST 12
task test_wrap8();
    begin
        HBURST = 3'b100; //WRAP8

        @(posedge HCLK);
        HSEL   = 1;
        HWRITE = 1;
        HTRANS = 2'b10;      //NONSEQ
        HSIZE  = 3'b010;     //WORD
        HADDR  = 32'h20;
        HWDATA = 32'h10;

        repeat (7) begin
            @(posedge HCLK);
            HTRANS = 2'b11;     //SEQ
            HWDATA = HWDATA + 1;
        end

        @(posedge HCLK);
        HTRANS = 2'b00;
        HSEL   = 0;
    end
endtask

//TEST 13
task test_idle();
    begin
        @(posedge HCLK);
        HTRANS = 2'b00;
        HSEL   = 0;
    end
endtask

//TEST 14
task test_back_to_back(
    output [31:0] rdata);
    begin
        for (int i = 0; i < 10; i++) begin
            if (i % 2 == 0) begin
                ahb_write(32'h10 + i*4, i, 3'b010);
            end

            else begin
                ahb_read(32'h10 + (i-1)*4, 3'b010, rdata);
            end
        end
    end
endtask

/*
task test_back_to_back();
    begin
        for (int i = 0; i < 10; i++) begin
            ahb_write(32'h10 + i*4, i, 3'b010);
        end
    end
endtask
*/

//TEST 15
task test_wait_state_hold();
    begin
        logic [31:0] addr_prev;
        logic [ 2:0] htrans_prev;
        logic [ 2:0] hsize_prev;
        logic        hwrite_prev;

        @(posedge HCLK);
        HSEL   = 1;
        HADDR  = 32'h69;
        HWRITE = 1;
        HTRANS = 2'b10;   //NONSEQ
        HSIZE  = 3'b010;
        HWDATA = 32'hdeadbeef;

        //save expected stable values
        addr_prev   = HADDR;
        htrans_prev = HTRANS;
        hsize_prev  = HSIZE;
        hwrite_prev = HWRITE;

        //stall
        @(posedge HCLK);
        HREADY = 0;

        repeat (2) begin
            @(posedge HCLK);

            if (HADDR !== addr_prev)
            $display("HADDR changed during wait state!");

            if (HTRANS !== htrans_prev)
            $display("HTRANS changed during wait state!");

            if (HSIZE !== hsize_prev)
            $display("HSIZE changed during wait state!");

            if (HWRITE !== hwrite_prev)
            $display("HWRITE changed during wait state!");
        end

        //stall released
        @(posedge HCLK);
        HREADY = 1;

        @(posedge HCLK);
        HTRANS = 2'b00;
        HSEL   = 0;
    end
endtask

initial begin
    reset_dut();

    test1_byte_write();
    test2_halfword_write();
    test3_word_write();
    test7_contention();
    test_incr4();
    test_incr8();
    test_incr16();
    test_wrap4();
    test_wrap8();
    test_back_to_back(data_tb);
    test_wait_state();

    $finish;
end

endmodule