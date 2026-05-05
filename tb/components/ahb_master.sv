import ahb3lite_pkg::*;
`include "scoreboard.sv"
class ahb_master;

    scoreboard sb_ahb_master;

    //Virtual interface
    virtual ahb_if vif;

    function new(virtual ahb_if vif);
        this.vif = vif;
        sb_ahb_master = new();
    endfunction

    //Random transaction fields
    rand logic [15:0] addr;
    rand logic [31:0] data;
    rand logic        write;
    rand logic [ 2:0] hsize;
    rand logic [ 2:0] hburst;

    //HTRANS sequence
    typedef enum logic [1:0] { IDLE   = HTRANS_IDLE,
                               BUSY   = HTRANS_BUSY,
                               NONSEQ = HTRANS_NONSEQ,
                               SEQ    = HTRANS_SEQ
                             } htrans_state;

    rand htrans_state htrans_q[];

    //ALIGNMENT CONSTRAINT
    constraint align_c { (hsize == HSIZE_HWORD) -> (addr[  0] == 1'b0);
                         (hsize == HSIZE_WORD)  -> (addr[1:0] == 2'b00);
                       }

    //1KB BOUNDARY CONSTRAINT
    constraint boundary_c { addr inside {[0:1023]}; }

    //Internal tracking
    logic [15:0] base_addr;
    int beats;

    //BURST TYPE CONSTRAINT
    constraint burst_c { hburst inside { HBURST_SINGLE,
                                         HBURST_INCR,
                                         HBURST_INCR4,
                                         HBURST_INCR8,
                                         HBURST_INCR16,
                                         HBURST_WRAP4,
                                         HBURST_WRAP8,
                                         HBURST_WRAP16
                                       };
                        }

    //SIZE CONSTRAINT
    constraint size_c { hsize inside {HSIZE_BYTE, HSIZE_HWORD, HSIZE_WORD}; }

    //BURST LENGTH
    function void post_randomize();
        case (hburst)
            HBURST_SINGLE:                 beats = 1;
            HBURST_INCR:                   beats = $urandom_range(1,16);    //undefined length
            HBURST_INCR4,  HBURST_WRAP4:   beats = 4;
            HBURST_INCR8,  HBURST_WRAP8:   beats = 8;
            HBURST_INCR16, HBURST_WRAP16:  beats = 16;
            default:                       beats = 1;
        endcase

        base_addr = addr;

        build_htrans_sequence();
    endfunction


    //HTRANS STATE MACHINE
    function void build_htrans_sequence();
        htrans_q = new[beats];

        for (int i = 0; i < beats; i++) begin
            if (i == 0)
                htrans_q[i] = NONSEQ;
            else begin
                    htrans_q[i] = SEQ;
            end
        end
    endfunction

    //NEXT ADDRESS CALCULATION
    function logic [15:0] next_addr(logic [15:0] curr_addr, int beat_idx);
        int beat_size;
        int wrap_size;

        beat_size = (1 << hsize);

        case (hburst)
            //INCR bursts
            HBURST_INCR, HBURST_INCR4, HBURST_INCR8, HBURST_INCR16: 
            begin
                return curr_addr + beat_size;
            end

            //WRAP bursts
            HBURST_WRAP4, HBURST_WRAP8, HBURST_WRAP16: 
            begin
                wrap_size = beats * beat_size;
                return base_addr + ((curr_addr + beat_size - base_addr) % wrap_size);
            end

            default: return curr_addr;
        endcase
    endfunction

    task drive(output logic [31:0] read_data);
        logic [15:0] curr_addr;
        
        curr_addr = addr;

        for (int i = 0; i < beats; i++) begin
            //wait until bus is ready
            @(posedge vif.HCLK);
            wait (vif.HREADYOUT);

            vif.HSEL   <= #1 1;
            vif.HADDR  <= #1 curr_addr;
            vif.HSIZE  <= #1 hsize;
            vif.HBURST <= #1 hburst;
            vif.HTRANS <= #1 htrans_q[i];

            //read or write?
            if (write) begin
                vif.HWRITE <= 1;
                @(posedge vif.HCLK);
                vif.HWDATA <=  data;
                sb_ahb_master.update_write(curr_addr, data, hsize);
            end 
            else begin
                vif.HWRITE <= #1 0;
            end

            //if read
            if (!write) begin
                //data
                @(posedge vif.HCLK); #1;
                wait (vif.HREADYOUT);

                //capture data
                @(posedge vif.HCLK); #11;
                read_data = vif.HRDATA;
                sb_ahb_master.check_read(curr_addr, read_data, hsize);
            end
        
            while (!vif.HREADYOUT) @(posedge vif.HCLK);

            curr_addr = next_addr(curr_addr, i);
        end

        //back to idle
        @(posedge vif.HCLK);
        wait(vif.HREADYOUT);
            vif.HTRANS <= HTRANS_IDLE;
            vif.HSEL   <= 0;

    endtask

endclass
