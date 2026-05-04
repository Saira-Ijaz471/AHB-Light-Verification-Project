import ahb3lite_pkg::*;
class scoreboard;

    logic [31:0] ref_mem [0:1023];

    //BYTE ENABLE GENERATOR
    function automatic logic [3:0] gen_be(
        input logic [2:0]  hsize,
        input logic [31:0] addr
    );
        logic [127:0] full_be;
        logic [6:0]   haddr_masked;
        logic [6:0]   addr_offset;

        //same as DUT address_offset
        addr_offset = 7'h03;

        case (hsize)
            HSIZE_WORD : full_be = {4{1'b1}};   
            HSIZE_HWORD: full_be = {2{1'b1}}; 
            HSIZE_BYTE : full_be = {1{1'b1}}; 
            default    : full_be = {4{1'b1}};
        endcase

        haddr_masked = addr & addr_offset;
        gen_be = full_be[3:0] << haddr_masked;

    endfunction


    //WRITE
    task update_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [2:0]  hsize
    );

        int word_addr;
        logic [3:0] be;

        begin
            word_addr = addr >> 2;
            be = gen_be(hsize, addr);

            for (int i = 0; i < 4; i++) begin
                if (be[i]) begin
                    ref_mem[word_addr][i*8 +: 8] = data[i*8 +: 8];
                end
            end
        end

    endtask


    //READ CHECK
    task check_read(
        input logic [31:0] addr,
        input logic [31:0] dut_data,
        input logic [2:0]  hsize
    );

        int word_addr;
        logic [31:0] expected;

        begin
            word_addr = addr >> 2;

            expected = ref_mem[word_addr];

            if (dut_data !== expected) begin
                $display("SCOREBOARD MISMATCH: ADDR = %0h, EXPected = %0h, DUT_DATA = %0h, TIME = %0t", addr, expected, dut_data, $time);
            end
            else begin
                $display("SCOREBOARD MATCHED: ADDR = %0h, TIME=%t", addr, $time);
            end
        end

    endtask

endclass
