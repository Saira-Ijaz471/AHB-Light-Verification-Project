// ============================================================
//  AHB Lite — Bind File
//  Project  : EE-5214 AMBA AHB-Lite RAM Verification
//  Role     : B — Assertions & Formal
//  DUT      : ahb3liten
//             MEM_SIZE=16, MEM_DEPTH=16, HADDR_SIZE=8
//
//  Parameters passed from DUT automatically via
//  parameter forwarding — no hardcoding needed.
// ============================================================

// ---- Bind checker to DUT -----------------------------------
bind ahb3liten ahb_checker #(
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
bind ahb3liten ahb_assumptions #(
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

// ---- Bind cover to DUT -------------------------------------
bind ahb3liten ahb_cover #(
    .HADDR_SIZE (HADDR_SIZE),
    .HDATA_SIZE (HDATA_SIZE)
) cover_i (
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