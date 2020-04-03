
module keyboard ( 
	input clk,
	input reset,

	// ps2 interface	
	input ps2_clk,
	input ps2_data,
	
	// decodes keys
   output [10:0] KA_n,   // 11 bits on address bus, negated logic 0 = key pressed     
	output [ 6:0] KD_n    // 7 bits on data bus, negated logic 0 = key pressed     
);

reg [11:0] KA;   // 12 keyboard matrix rows, A0-A7 + A,B,C,D; mapped onto address bus; 1 = key pressed     
reg [ 6:0] KD;   // 7 keyboard matrix columns mapped onto data bus; 1 = key pressed       	

assign KA_n = ~( {KA_dec, KA[7:0]} );
assign KD_n = ~KD;

// this implements the 74LS138 demultiplexer
wire DCBA = KA[11:8];   // D, C, B, A input to demultiplexer

// demultiplexer output
wire [3:0] KA_dec = DCBA == 'b0000 ? 0 :
					 	  DCBA == 'b0001 ? 1 :
						  DCBA == 'b0010 ? 2 : 
						  DCBA == 'b0100 ? 3 : 
						  DCBA == 'b1000 ? 4 : 0;

parameter [15:0] KEY_RESET         = 'h77; // as pause/break key -- not mapped on the I/O but directly on the /RES line to the CPU
parameter [15:0] KEY_F1            = 'h05;
parameter [15:0] KEY_F2            = 'h06;
parameter [15:0] KEY_F3            = 'h04;
parameter [15:0] KEY_F4            = 'h0c;
parameter [15:0] KEY_F5            = 'h03;
parameter [15:0] KEY_F6            = 'h0b;
parameter [15:0] KEY_F7            = 'h83;
parameter [15:0] KEY_F8            = 'h0a;
parameter [15:0] KEY_F9            = 'h01;
parameter [15:0] KEY_F10           = 'h09;  // f11 8'h78, f12 8'h07
parameter [15:0] KEY_INS           = 'he070;
parameter [15:0] KEY_DEL           = 'he069;
parameter [15:0] KEY_ESC           = 'h76;
parameter [15:0] KEY_1             = 'h16;
parameter [15:0] KEY_2             = 'h1e;
parameter [15:0] KEY_3             = 'h26;
parameter [15:0] KEY_4             = 'h25;
parameter [15:0] KEY_5             = 'h2e;
parameter [15:0] KEY_6             = 'h36;
parameter [15:0] KEY_7             = 'h3d;
parameter [15:0] KEY_8             = 'h3e;
parameter [15:0] KEY_9             = 'h46;
parameter [15:0] KEY_0             = 'h45;
parameter [15:0] KEY_MINUS         = 'h4e;
parameter [15:0] KEY_EQUAL         = 'h55;
parameter [15:0] KEY_BACKSLASH     = 'h0e;
parameter [15:0] KEY_BS            = 'h66;
parameter [15:0] KEY_DEL_LINE      = 'he06c;
parameter [15:0] KEY_CLS_HOME      = 'he071;
parameter [15:0] KEY_TAB           = 'h0d;
parameter [15:0] KEY_Q             = 'h15;
parameter [15:0] KEY_W             = 'h1d;
parameter [15:0] KEY_E             = 'h24;
parameter [15:0] KEY_R             = 'h2d;
parameter [15:0] KEY_T             = 'h2c;
parameter [15:0] KEY_Y             = 'h35;
parameter [15:0] KEY_U             = 'h3c;
parameter [15:0] KEY_I             = 'h43;
parameter [15:0] KEY_O             = 'h44;
parameter [15:0] KEY_P             = 'h4d;
parameter [15:0] KEY_OPEN_BRACKET  = 'h54;
parameter [15:0] KEY_CLOSE_BRACKET = 'h5b;
parameter [15:0] KEY_RETURN        = 'h5a;
parameter [15:0] KEY_CONTROL       = 'h14;  // other control is e014
parameter [15:0] KEY_A             = 'h1c;
parameter [15:0] KEY_S             = 'h1b;
parameter [15:0] KEY_D             = 'h23;
parameter [15:0] KEY_F             = 'h2b;
parameter [15:0] KEY_G             = 'h34;
parameter [15:0] KEY_H             = 'h33;
parameter [15:0] KEY_J             = 'h3b;
parameter [15:0] KEY_K             = 'h42;
parameter [15:0] KEY_L             = 'h4b;
parameter [15:0] KEY_SEMICOLON     = 'h4c;
parameter [15:0] KEY_QUOTE         = 'h52;
parameter [15:0] KEY_BACK_QUOTE    = 'h5d;
parameter [15:0] KEY_GRAPH         = 'h78;  // as f8
parameter [15:0] KEY_UP            = 'he075;
parameter [15:0] KEY_SHIFT         = 'h12;  // also 59
parameter [15:0] KEY_Z             = 'h1a;
parameter [15:0] KEY_X             = 'h22;
parameter [15:0] KEY_C             = 'h21;
parameter [15:0] KEY_V             = 'h2a;
parameter [15:0] KEY_B             = 'h32;
parameter [15:0] KEY_N             = 'h31;
parameter [15:0] KEY_M             = 'h3a;
parameter [15:0] KEY_COMMA         = 'h41;
parameter [15:0] KEY_DOT           = 'h49;
parameter [15:0] KEY_SLASH         = 'h4a;
parameter [15:0] KEY_MU            = 'h00;   // ??
parameter [15:0] KEY_LEFT          = 'he06b;
parameter [15:0] KEY_RIGHT         = 'he074;
parameter [15:0] KEY_CAP_LOCK      = 'h58;
parameter [15:0] KEY_SPACE         = 'h29;
parameter [15:0] KEY_DOWN          = 'he072;

wire [7:0] byte;   // keyboard data byte, 0xE0 = extended key, 0xF0 release key
wire valid;        // 1 = data byte contains valid keyboard data 
wire error;        // not used here

reg key_released;
reg key_extended;

wire key_pressed = !key_released;

always @(posedge clk) begin
	if(reset) begin
		//keys <= 8'h00;
      key_released <= 1'b0;
      key_extended <= 1'b0;
	end else begin
		// ps2 decoder has received a valid byte
		if(valid) begin
			if(byte == 8'he0) 
				// extended key code
            key_extended <= 1'b1;
         else if(byte == 8'hf0)
				// release code
            key_released <= 1'b1;
         else begin
				key_extended <= 1'b0;
				key_released <= 1'b0;
				
				case(byte)					

					KEY_SHIFT        : begin KA['h0] <= key_pressed; KD[6] <= key_pressed; end
					KEY_Z            : begin KA['h0] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_X            : begin KA['h0] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_C            : begin KA['h0] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_V            : begin KA['h0] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_B            : begin KA['h0] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_N            : begin KA['h0] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_CONTROL      : begin KA['h1] <= key_pressed; KD[6] <= key_pressed; end
					KEY_A            : begin KA['h1] <= key_pressed; KD[5] <= key_pressed; end   
					KEY_S            : begin KA['h1] <= key_pressed; KD[4] <= key_pressed; end   
					KEY_D            : begin KA['h1] <= key_pressed; KD[3] <= key_pressed; end   
					KEY_F            : begin KA['h1] <= key_pressed; KD[2] <= key_pressed; end   
					KEY_G            : begin KA['h1] <= key_pressed; KD[1] <= key_pressed; end   
					KEY_H            : begin KA['h1] <= key_pressed; KD[0] <= key_pressed; end   
					KEY_TAB          : begin KA['h2] <= key_pressed; KD[6] <= key_pressed; end
					KEY_Q            : begin KA['h2] <= key_pressed; KD[5] <= key_pressed; end      
					KEY_W            : begin KA['h2] <= key_pressed; KD[4] <= key_pressed; end      
					KEY_E            : begin KA['h2] <= key_pressed; KD[3] <= key_pressed; end      
					KEY_R            : begin KA['h2] <= key_pressed; KD[2] <= key_pressed; end      
					KEY_T            : begin KA['h2] <= key_pressed; KD[1] <= key_pressed; end      
					KEY_Y            : begin KA['h2] <= key_pressed; KD[0] <= key_pressed; end      
					KEY_ESC          : begin KA['h3] <= key_pressed; KD[6] <= key_pressed; end
					KEY_1            : begin KA['h3] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_2            : begin KA['h3] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_3            : begin KA['h3] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_4            : begin KA['h3] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_5            : begin KA['h3] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_6            : begin KA['h3] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_EQUAL        : begin KA['h4] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_MINUS        : begin KA['h4] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_0            : begin KA['h4] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_9            : begin KA['h4] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_8            : begin KA['h4] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_7            : begin KA['h4] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_BS           : begin KA['h5] <= key_pressed; KD[6] <= key_pressed; end 
					KEY_P            : begin KA['h5] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_O            : begin KA['h5] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_I            : begin KA['h5] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_U            : begin KA['h5] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_RETURN       : begin KA['h6] <= key_pressed; KD[6] <= key_pressed; end                        
					KEY_QUOTE        : begin KA['h6] <= key_pressed; KD[4] <= key_pressed; end
					KEY_SEMICOLON    : begin KA['h6] <= key_pressed; KD[3] <= key_pressed; end
					KEY_L            : begin KA['h6] <= key_pressed; KD[2] <= key_pressed; end
					KEY_K            : begin KA['h6] <= key_pressed; KD[1] <= key_pressed; end
					KEY_J            : begin KA['h6] <= key_pressed; KD[0] <= key_pressed; end                                                       
					KEY_GRAPH        : begin KA['h7] <= key_pressed; KD[6] <= key_pressed; end 
					KEY_BACK_QUOTE   : begin KA['h7] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_SPACE        : begin KA['h7] <= key_pressed; KD[4] <= key_pressed; end
					KEY_SLASH        : begin KA['h7] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_DOT          : begin KA['h7] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_COMMA        : begin KA['h7] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_M            : begin KA['h7] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_BACKSLASH    : begin KA['h8] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_CLOSE_BRACKET: begin KA['h8] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_OPEN_BRACKET : begin KA['h8] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_MU           : begin KA['h8] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_DEL          : begin KA['h8] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_INS          : begin KA['h8] <= key_pressed; KD[0] <= key_pressed; end  
					KEY_CAP_LOCK     : begin KA['h9] <= key_pressed; KD[6] <= key_pressed; end 
					KEY_DEL_LINE     : begin KA['h9] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_CLS_HOME     : begin KA['h9] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_UP           : begin KA['h9] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_LEFT         : begin KA['h9] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_RIGHT        : begin KA['h9] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_DOWN         : begin KA['h9] <= key_pressed; KD[0] <= key_pressed; end 
					KEY_F1           : begin KA['hA] <= key_pressed; KD[5] <= key_pressed; end 
					KEY_F2           : begin KA['hA] <= key_pressed; KD[4] <= key_pressed; end 
					KEY_F3           : begin KA['hA] <= key_pressed; KD[3] <= key_pressed; end 
					KEY_F4           : begin KA['hA] <= key_pressed; KD[2] <= key_pressed; end    
					KEY_F10          : begin KA['hB] <= key_pressed; KD[5] <= key_pressed; end   
					KEY_F9           : begin KA['hB] <= key_pressed; KD[4] <= key_pressed; end   
					KEY_F8           : begin KA['hB] <= key_pressed; KD[3] <= key_pressed; end   
					KEY_F7           : begin KA['hB] <= key_pressed; KD[2] <= key_pressed; end 
					KEY_F6           : begin KA['hB] <= key_pressed; KD[1] <= key_pressed; end 
					KEY_F5           : begin KA['hB] <= key_pressed; KD[0] <= key_pressed; end
				
				endcase
			end
		end
	end
end

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf ps2_keyboard (
	.CLK		 ( clk       ),
	.nRESET	 ( !reset    ),
	
	// PS/2 interface
	.PS2_CLK  ( ps2_clk   ),
	.PS2_DATA ( ps2_data  ),
	
	// Byte-wide data interface - only valid for one clock
	// so must be latched externally if required
	.DATA		  ( byte   ),
	.VALID	  ( valid  ),
	.ERROR	  ( error  )
);


endmodule
