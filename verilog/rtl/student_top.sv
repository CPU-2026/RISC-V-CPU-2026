module student_top (
    input  wire        clock,
    input  wire        reset,    // 高电平复位，初始化时保持 5 周期高电平

    // AXI4-Lite 读地址通道 (AR)
    output wire [31:0] araddr,
    output wire        arvalid,
    input  wire        arready,

    // AXI4-Lite 读数据通道 (R)
    input  wire [31:0] rdata,
    input  wire [1:0]  rresp,    // 2'b00 = OKAY, 2'b10 = SLVERR, 2'b11 = DECERR
    input  wire        rvalid,
    output wire        rready,

    // AXI4-Lite 写地址通道 (AW)
    output wire [31:0] awaddr,
    output wire        awvalid,
    input  wire        awready,

    // AXI4-Lite 写数据通道 (W)
    output wire [31:0] wdata,
    output wire [3:0]  wstrb,    // 字节写使能掩码
    output wire        wvalid,
    input  wire        wready,

    // AXI4-Lite 写响应通道 (B)
    input  wire [1:0]  bresp,
    input  wire        bvalid,
    output wire        bready
);