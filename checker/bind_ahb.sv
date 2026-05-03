// ============================================================
//  AHB Lite — Bind File
//  Project  : EE-5214 AMBA AHB-Lite RAM Verification
//  Role     : B — Assertions & Formal
//
//  Binds both:
//  1. ahb_checker     — DUT (slave) assertions
//  2. ahb_assumptions — Master environment constraints
//
//  DUT module : ahb3lite_sram
 
// ============================================================

// ---- Bind checker to DUT -----------------------------------
bind ahb3lite_sram ahb_checker #(
    .HADDR_SIZE  (HADDR_SIZE),
    .HDATA_SIZE  (HDATA_SIZE),
    .MEM_DEPTH   (MEM_DEPTH),
    .RESET_BOUND (4)
) checker_i (
    .HRESETn   (HRESETn),
    .HCLK      (HCLK),
    .HSEL      (HSEL),
    .HADDR     (HADDR),
    .HWDATA    (HWDATA),
    .HRDATA    (HRDATA),
    .HWRITE    (HWRITE),
    .HSIZE     (HSIZE),
    .HBURST    (HBURST),
    .HTRANS    (HTRANS),
    .HREADYOUT (HREADYOUT),
    .HREADY    (HREADY),
    .HRESP     (HRESP)
);

// ---- Bind assumptions to DUT -------------------------------
bind ahb3lite_sram ahb_assumptions #(
    .HADDR_SIZE (HADDR_SIZE),
    .HDATA_SIZE (HDATA_SIZE),
    .MEM_DEPTH  (MEM_DEPTH)
) assumptions_i (
    .HRESETn (HRESETn),
    .HCLK    (HCLK),
    .HSEL    (HSEL),
    .HADDR   (HADDR),
    .HWDATA  (HWDATA),
    .HWRITE  (HWRITE),
    .HSIZE   (HSIZE),
    .HBURST  (HBURST),
    .HTRANS  (HTRANS),
    .HREADY  (HREADY),
    .HRESP   (HRESP)
);