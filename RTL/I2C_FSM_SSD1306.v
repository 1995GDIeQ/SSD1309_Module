`timescale 1ns / 1ps
module  I2C_FSM_SSD1306(
        //Core        
        input                   Clock,
        input                   cReset,
        
        input   [7:0]           Command,
        input   [7:0]           WriteData,
        
        input                   cSCL,
        output                  cSCLDriverLow,
        output                  cSDADriverLow,
    );
    
    
//-------------------------------------------------------------------------
// Static Assignments 
//-------------------------------------------------------------------------
    localparam  [6:0]       SLAVE_ADDRESS = 7'b0111100;
    
    localparam              FSM_SIZE    = 10;
    
    localparam              IDLE        = 0;
    localparam              START       = 1;
    localparam              ADDR        = 2;
    localparam              ADDR_ACK    = 3;
    localparam              CMD         = 4;
    localparam              CMD_ACK     = 5;
    localparam              WRITE       = 6;
    localparam              WRITE_ACK   = 7;
    localparam              CONT        = 8;
    localparam              STOP        = 9;
//#########################################################################
// Reg and wire
//#########################################################################   
    reg     [FSM_SIZE-1:0]     cStatus;
    reg     [FSM_SIZE-1:0]     nStatus;
//#########################################################################
// assign Assignments
//#########################################################################	
    assign     cHostSCL_RE  = ~cHostSCL_Dly &  cHostSCL;
    assign     cHostSCL_FE  =  cHostSCL_Dly & ~cHostSCL;
//#########################################################################
// cSCL Delay 
//#########################################################################   
    always@(posedge Clock) cHostSCL_Dly <= cHostSCL;
//-----------------------------------------------------------------------//
// SDA ctrl module
//-----------------------------------------------------------------------//
    assign  cSDADriverLow = rMasterSDA
    //####################################################################
    // 
    //####################################################################
    always@(posedge Clock or posedge cReset)begin
        if(cReset)begin
            rMasterSDA <= 1'bz;
        end
        else begin
            case(1'b1)
                cStatus[IDLE]   : 
                cStatus[START]  : rMasterSDA <= 1'b0;
                cStatus[ADDR]   : rMasterSDA <= (cHoldPlues1uS)?  : rMasterSDA;
                default :
            endcase
        end
    end
    //####################################################################
    // 
    //####################################################################
    always@(posedge Clock or posedge cReset)begin
        if(cReset)begin
            rSDAData[7:0] <= 8'h00;
        end
        else begin
            case(1'b1)
                cStatus[ADDR]       : rSDAData[7:0] <= {SLAVE_ADDRESS,1'b0};
                cStatus[CMD]        : rSDAData[7:0] <= Command[7:0];
                cStatus[WRITE]      : rSDAData[7:0] <= WriteData[7:0];
                default             : rSDAData[7:0] <= 8'h00
            endcase
        end
    end
//#########################################################################
// Finite-State Machine
//#########################################################################
    always@(posedge Clock or posedge cReset)begin
        if(cReset) begin
            cStatus[FSM_SIZE-1:0]   <= {(FSM_SIZE-1){1'b0},1'b1};
            // nStatus[FSM_SIZE-1:0]   <= {FSM_SIZE{1'b0}};
        end else begin
            cStatus[FSM_SIZE-1:0]   <= nStatus[FSM_SIZE-1:0];
        end
    end
    
    always@(*)begin
        nStatus[FSM_SIZE-1:0]   = {FSM_SIZE{1'b0}};
        case(1'b1)
            cStatus[IDLE] : begin
                if(Enable_Tran)
                    nStatus[START]      = 1'b1;
                else
                    nStatus[IDLE]       = 1'b1;
            end
            cStatus[START] : begin
                if(cHostSCL_FE)
                    nStatus[ADDR]       = 1'b1;
                else
                    nStatus[START]      = 1'b1;
            end
            cStatus[ADDR] : begin
                if((ByteCount == 4'd8) && cHostSCL_RE)
                    nStatus[ADDR_ACK]   = 1'b1;
                else
                    nStatus[ADDR]       = 1'b1;
            end
            cStatus[ADDR_ACK] : begin
                if(Timeout)
                    nStatus[IDLE]       = 1'b1;
                else if(Ack_Check && cHostSCL_RE)
                    nStatus[CMD]        = 1'b1;
                else
                    nStatus[ADDR_ACK]   = 1'b1;
            end
            cStatus[CMD] : begin
                if((ByteCount == 4'd8) && cHostSCL_RE)
                    nStatus[CMD_ACK]   = 1'b1;
                else
                    nStatus[CMD]       = 1'b1;
            end
            cStatus[CMD_ACK] : begin
                if(Timeout)
                    nStatus[IDLE]       = 1'b1;
                else if(Ack_Check && cHostSCL_RE)
                    nStatus[WRITE]      = 1'b1;
                else
                    nStatus[CMD_ACK]    = 1'b1;
            end
            cStatus[WRITE] : begin
                if((ByteCount == 4'd8) && cHostSCL_RE)
                    nStatus[WRITE_ACK]  = 1'b1;
                else
                    nStatus[WRITE]      = 1'b1;
            end
            cStatus[WRITE_ACK] : begin
                if(Timeout)
                    nStatus[IDLE]       = 1'b1;
                else if(Ack_Check && cHostSCL_RE)
                    nStatus[CONT]       = 1'b1;
                else
                    nStatus[WRITE_ACK]  = 1'b1;
            end
            cStatus[CONT] : begin
                if(End_Tran)
                    nStatus[STOP]       = 1'b1;
                else
                    nStatus[CMD]        = 1'b1;
            end
            cStatus[STOP] : begin
                if(WaitTimePlus)
                    nStatus[IDLE]       = 1'b1;
                else
                    nStatus[STOP]       = 1'b1;
            end
            default:nStatus[IDLE]       = 1'b1;
        endcase
    end    
//#########################################################################
// Driver low hold time
//#########################################################################
    // 200KHz - Half period of Time 2.5uS 
    // Active 2.5uS plues
    TimePlues#(
        .VALUE_BIT_SIZE     (7)
    )SCL_TimePlues(
        .Clock              (Clock),
        .cRst_n             (cRst_n),
        .CLK_Enable         (1'b1),
        .Reload             (~cSCKLDriverLow),
        .Value              (7'd125),
        .TimeOutPlues       (cSCLHoldLowPlues)
    );
    
    TimePlues#(
        .VALUE_BIT_SIZE     (7)
    )SDA_TimePlues(
        .Clock              (Clock),
        .cRst_n             (cRst_n),
        .CLK_Enable         (1'b1),
        .Reload             (~cSDADriverLow),
        .Value              (7'd125),
        .TimeOutPlues       (cSDAHoldLowPlues)
    );
    
    
    //Hold 1u between SCK as low and SDA data
    TimePlues#(
        .VALUE_BIT_SIZE     (6)
    )HoldTime(
        .Clock              (Clock),
        .cRst_n             (cRst_n),
        .CLK_Enable         (1'b1),
        .Reload             (cHostSCL),
        .Value              (6'd50),
        .TimeOutPlues       (cHoldPlues1uS)
    );
    
endmodule