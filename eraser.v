//
// This module erases the RAM allowing cold boot
//

module eraser(	
	input 			   clk,
	input             ena,
	input             trigger,    // 1=starts erasing
	
	output reg        erasing,    // 1=signals RAM is being erased

	// sdram interface	
	output reg        wr,
	output reg [24:0] addr,
	output reg [7:0]  data
);

reg [24:0] pos;

// erases from page 3 to page 7 (all 64K RAM)
localparam [24:0] START_RAM = { 7'd0, 4'h3, 14'b0 };  // 25'h10000 + 25'h99a;
localparam [24:0] END_RAM   = { 7'd0, 4'h8, 14'b0 };  // 25'h10000 + 25'h99d; 

// detect trigger
always @(posedge clk) begin
	if(ena) begin
		if(trigger && !erasing) begin
			erasing <= 1;		
			pos <= START_RAM;		
		end
		
		if(erasing) begin
			wr <= 1;
			addr <= pos;
			data <= 'hff;			
			pos  <= pos + 1;
			if(pos == END_RAM + 1) begin
				erasing <= 0;
				wr <= 0;
			end				
		end		
	end
end

endmodule
