bind ahb3liten ahb_checker checker_i(

    .HCLK(HCLK),
    .HRESETn(HRESETn),

    .HSEL(HSEL),

    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HBURST(HBURST),
    .HSIZE(HSIZE),
    .HPROT(HPROT),

    .HWRITE(HWRITE),
    .HREADY(HREADY),
    .HREADYOUT(HREADYOUT),
    .HRESP(HRESP),

    .HWDATA(HWDATA),
    .HRDATA(HRDATA)

);