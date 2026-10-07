interface axis_if # (
    // user parameters
    parameter TDATA_WIDTH = 256,      // DATA width
    parameter logic TID_EN = 0,     // use TID
    parameter TID_WIDTH = 8,        // TID width
    parameter logic TDEST_EN = 0,   // use TDEST
    parameter TDEST_WIDTH = 8,      // TDEST width
    parameter logic TUSER_EN = 0,   // use TUSER
    parameter TUSER_WIDTH = 8,      // TUSER width
    parameter logic TSTRB_EN = 0,   // use TSTRB
    parameter logic TWAKEUP_EN = 0, // use TWAKEUP

    parameter TKEEP_WIDTH = ((TDATA_WIDTH+7) / 8),
    parameter logic TKEEP_EN = TKEEP_WIDTH > 1

)
(
    // IO
);
// From the spec section 2.1
// logic       aclk; // these two come from elsewhere
// logic       asresetn;
wire                       tvalid;
wire                       tready;
wire [TDATA_WIDTH-1 : 0]   tdata;
wire [TKEEP_WIDTH-1 : 0]   tstrb;
wire [TKEEP_WIDTH-1 : 0]   tkeep;
wire                       tlast;
wire [TID_WIDTH-1 : 0]     tid;
wire [TDEST_WIDTH-1 : 0]   tdest;
wire [TUSER_WIDTH-1 : 0]   tuser;
wire                       twakeup;

modport master (
    output tvalid,
    input tready,
    output tdata,
    output tstrb,
    output tkeep,
    output tlast,
    output tid,
    output tdest,
    output tuser,
    output twakeup
);

modport slave (
    input tvalid,
    output tready,
    input tdata,
    input tstrb,
    input tkeep,
    input tlast,
    input tid,
    input tdest,
    input tuser,
    input twakeup
);


endinterface
