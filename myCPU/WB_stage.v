`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    //to ds data dependence
    output [ 4:0] WB_dest         ,
    //forward
    output [31:0] WB_dest_data    ,
    // EX
    output        WS_EX           ,
    output [31:0] cp0_epc         ,
    output        ERET            ,
    // READ CP0
    input         mfc0_read       ,
    input  [ 4:0] mfc0_cp0_raddr  ,
    output [31:0] mfc0_rdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc  ;
wire        bd     ;
wire        eret   ;
wire [ 2:0] ex_code;
assign {ex_code        ,  //74:72
        eret           ,  //71:71
        bd             ,  //70:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;

assign WB_dest = ws_dest & {5{ws_valid}};

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset | (ex_code != 3'b0) | eret) begin
        ws_valid       <= 1'b0;
        ms_to_ws_bus_r <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid & ~WS_EX;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// forward
assign WB_dest_data = rf_wdata;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

// EX
assign WS_EX = (ex_code != 3'b0);
assign ERET  = eret ;

wire [ 4:0] cp0_raddr;
wire [31:0] cp0_rdata;
wire [ 4:0] cp0_waddr;
wire [31:0] cp0_wdata;
wire [ 4:0] excode;

assign mfc0_rdata = cp0_rdata;
assign cp0_epc    = eret ? cp0_rdata + 4'h4 : 32'b0;

assign cp0_raddr = mfc0_read ? mfc0_cp0_raddr : 
                   eret      ? `CP0_EPC       :
                               5'b11111;
assign cp0_waddr = WS_EX ? `CP0_EPC :  5'b11111;
assign cp0_wdata = WS_EX ?  ws_pc : 31'b0;
assign excode    = (ex_code == `SYSCALL ) ? 5'b1000 :
                   (ex_code == `BREAK   ) ? 5'b1001 :
                   (ex_code == `OVERFLOW) ? 5'b1100 :
                                            5'b0;
// CP0
CP0 CP0(
    .clk     (clk      ),
    .reset   (reset    ),
    // read
    .raddr   (cp0_raddr),
    .rdata   (cp0_rdata),
    // write
    .waddr   (cp0_waddr),
    .wdata   (cp0_wdata),
    .excode  (excode   ),
    // control
    .ex_code (ex_code  ),
    .bd      (bd       ),
    .eret    (eret     )
    );
endmodule
