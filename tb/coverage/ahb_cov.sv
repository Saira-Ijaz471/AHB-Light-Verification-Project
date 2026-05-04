import ahb3lite_pkg::*;
module ahb_cov
#(
    parameter HADDR_SIZE = 16,
    parameter HDATA_SIZE = 32
)
(
    input                       HCLK,
    input                       HRESETn,
    input                       HSEL,
    input      [HADDR_SIZE-1:0] HADDR,
    input      [HDATA_SIZE-1:0] HWDATA,
    input      [HDATA_SIZE-1:0] HRDATA,
    input                       HWRITE,
    input      [           2:0] HSIZE,
    input      [           2:0] HBURST,
    input      [           3:0] HPROT,
    input      [           1:0] HTRANS,
    input                       HREADY,
    input                       HREADYOUT,
    input                       HRESP,
    input                       be
);
timeunit 1ns;
timeprecision 1ns;

//COVERGROUPS
covergroup ahb_cg @(posedge HCLK);

    //HSEL Coverage
    hsel_cp:        coverpoint HSEL       { bins SEL_0         = {0};
                                            bins SEL_1         = {1};
                                          }

    //HREADYOUT Coverage
    hreadyout_cp:   coverpoint HREADYOUT  { bins ready_low     = {0};
                                            bins ready_high    = {1};
                                          }

    //BYTE ENABLE(be) Coverage
    be_cp:          coverpoint be         { bins no_write      = {0             };
                                            bins single_byte   = {1, 2, 4, 8    };
                                            bins half_word     = {2'b11, 2'b1100};
                                            bins full_word     = {4'b1111       };
                                            bins partial       = default;
                                          }


    //EXTENDED COVERGROUPS
    //HTRANS Coverage
    htrans_cp:      coverpoint HTRANS     { bins IDLE          = {HTRANS_IDLE  };
                                            bins BUSY          = {HTRANS_BUSY  };
                                            bins NONSEQ        = {HTRANS_NONSEQ};
                                            bins SEQ           = {HTRANS_SEQ   }; 
                                          }

    //HBURST Coverage
    hburst_cp:      coverpoint HBURST     { bins SINGLE        = {HBURST_SINGLE};
                                            bins INCR          = {HBURST_INCR  };
                                            bins WRAP4         = {HBURST_WRAP4 };
                                            bins INCR4         = {HBURST_INCR4 };
                                            bins WRAP8         = {HBURST_WRAP8 };
                                            bins INCR8         = {HBURST_INCR8 };
                                            bins WRAP16        = {HBURST_WRAP16};
                                            bins INCR16        = {HBURST_INCR16};
                                          }

    //HSIZE Coverage
    hsize_cp:       coverpoint HSIZE      { bins BYTE          = {HSIZE_B8   };
                                            bins HWORD         = {HSIZE_B16  };
                                            bins WORD          = {HSIZE_B32  };
                                            bins DWORD         = {HSIZE_B64  };
                                            bins B128          = {HSIZE_B128 };
                                            bins B256          = {HSIZE_B256 };
                                            bins B512          = {HSIZE_B512 };
                                            bins B1024         = {HSIZE_B1024};
                                          }


    //HWRITE Coverage
    hwrite_cp:      coverpoint HWRITE     { bins READ  = {0};
                                            bins WRITE = {1};
                                          }


    //HREADY coverage
    hready_cp:      coverpoint HREADY     { bins READY_0 = {0};
                                            bins READY_1 = {1};
                                          }


    //HRESP Coverage
    hresp_cp:       coverpoint HRESP      { bins OKAY  = {HRESP_OKAY };
                                            bins ERROR = {HRESP_ERROR};
                                          }


    //Address Coverage
    //2^16 = 65536  into 4 address spaces: 65536/4 = 16384 each space 
    haddr_cp:       coverpoint HADDR      { bins low    = {[0 : (2**HADDR_SIZE)/4 - 1]};                          //0    -16383                   
                                            bins mid1   = {[(2**HADDR_SIZE)/4 : (2**HADDR_SIZE)/2 - 1]};          //16384-32767
                                            bins mid2   = {[(2**HADDR_SIZE)/2 : (3*(2**HADDR_SIZE)/4) - 1]};      //32768-49151
                                            bins high   = {[(3*(2**HADDR_SIZE)/4) : (2**HADDR_SIZE - 1)]};        //49151-65535
                                          }   

    
    //CROSS COVERAGE
    //HBURST x HWRITE
    cross_hburst_hwrite: cross hburst_cp, hwrite_cp;

    //HSIZE x HWRITE
    cross_hsize_hwrite:  cross hsize_cp,  hwrite_cp;

    //HTRANS x HREADY
    cross_htrans_hready: cross htrans_cp, hready_cp;

endgroup


//INSTANTIATION
ahb_cg  cg1;

//SAMPLING
initial begin
    cg1 = new();
end

endmodule
