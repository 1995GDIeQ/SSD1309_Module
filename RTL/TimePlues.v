`timescale 1ns / 1ps
module	TimePlues#(
			parameter	VALUE_BIT_SIZE = 10,
			parameter 	AUTO_RELOAD = 1'b0
		)(
			input	Clock,
			input	cRst_n,
			input	CLK_Enable,
			input	Reload,
			input	[VALUE_BIT_SIZE-1:0]	Value,
			output	TimeOutPlues
		);
	
	reg		TimeOutLoad_Dly;
	reg		TimeOutLoad;
	reg		[VALUE_BIT_SIZE-1:0] Count;
	
	assign 	cResetOrReload 	= (~cRst_n | Reload);
	assign 	TimeOutPlues 	= TimeOutLoad;
	
	always@(posedge Clock)begin
		if (cResetOrReload) begin 
			Count 			<= Value - 1'b1;
			TimeOutLoad 	<= 1'b0;     
		end
		else if (CLK_Enable) begin
			Count <= Count;
			TimeOutLoad <= TimeOutLoad; 
			if (Count == 0) begin 
				TimeOutLoad <= 1'b1; 
				if (TimeOutLoad & AUTO_RELOAD) begin               
					Count 		<= Value - 1'b1;  
					TimeOutLoad <= 1'b0;
				end
			end
			else
				Count 	<= Count - 1'b1;
		end
		else begin
			Count 			<= Count; 
			TimeOutLoad 	<= TimeOutLoad;
		end
    end
endmodule