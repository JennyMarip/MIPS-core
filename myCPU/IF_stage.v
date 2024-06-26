`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    // allwoin
    input                          ds_allowin     ,
    // brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    // to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // EX
    input         WS_EX          ,
    input         ERET           ,
    input  [31:0] cp0_epc        ,
    input         DS_EX          ,
    input         ES_EX          ,
    input         MS_EX          ,
    // branch slot
    input         is_branch      ,
    output        BD
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         pre_fs_ready_go;

wire         br_stall;
wire         br_taken;
wire [ 31:0] br_target;
assign {br_stall, br_taken,br_target} = br_bus;

// EX test
wire [31:0] fs_inst;
reg  [31:0] fs_pc  ;
wire [ 4:0] ex_code;
assign      ex_code = ~DS_EX & ~ES_EX & ~MS_EX & ~WS_EX & (fs_pc[1:0] != 2'b0) ? `ADEL : `NO_EX;
wire [31:0] BadVAddr;
assign      BadVAddr = (ex_code == `ADEL) ? fs_pc : 32'b0;
wire        pc_error;
assign      pc_error = (ex_code == `ADEL);
assign fs_to_ds_bus = {pc_error,
                       BadVAddr,
                       ex_code ,
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset && pre_fs_ready_go;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = WS_EX              ? 32'hbfc00380 : 
                      ERET               ? cp0_epc      :
                      br_taken           ? br_target    : 
                                           seq_pc; 
assign pre_fs_ready_go  = ~br_stall;

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (WS_EX) begin
        fs_valid <= 1'b1;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin || WS_EX || ERET) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin && ~br_stall || WS_EX;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = {nextpc[31:2], 2'b0};
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

// slot
wire bd;
assign bd = is_branch;
assign BD = bd;

endmodule
