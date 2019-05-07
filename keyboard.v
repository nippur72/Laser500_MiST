module keyboard ( 
	input clk,
	input reset,

	// ps2 interface	
	input ps2_clk,
	input ps2_data,
	
	// keyboard matrix 14x7 in negated logic 0=key pressed, 1=key released
	output reg [13:0] KA,   // KA 14 row    lines mapped into address bus 
	output reg [ 6:0] KD    // KD  7 column lines mapped into data bus    
);

wire [7:0] byte;
wire valid;
wire error;

reg key_released;
reg key_extended;

// TODO handle reset key
// TODO shift/ctrl
// TODO italian keyboard/logical keyboard
// TODO 7th keyboard bit
// TODO ENG/GER/FRA bit

parameter [7:0] KEY_RESET = 0; // not mapped on the I/O but directly on the /RES line to the CPU
parameter [7:0] KEY_F1  = 1;
parameter [7:0] KEY_F2  = 2;
parameter [7:0] KEY_F3  = 3;
parameter [7:0] KEY_F4  = 4;
parameter [7:0] KEY_F5  = 5;
parameter [7:0] KEY_F6  = 6;
parameter [7:0] KEY_F7  = 7;
parameter [7:0] KEY_F8  = 8;
parameter [7:0] KEY_F9  = 9;
parameter [7:0] KEY_F10 = 10;
parameter [7:0] KEY_INS = 11;
parameter [7:0] KEY_DEL = 12;
parameter [7:0] KEY_ESC = 13;
parameter [7:0] KEY_1 = 14;
parameter [7:0] KEY_2 = 15;
parameter [7:0] KEY_3 = 16;
parameter [7:0] KEY_4 = 17;
parameter [7:0] KEY_5 = 18;
parameter [7:0] KEY_6 = 19;
parameter [7:0] KEY_7 = 20;
parameter [7:0] KEY_8 = 21;
parameter [7:0] KEY_9 = 22;
parameter [7:0] KEY_0 = 23;
parameter [7:0] KEY_MINUS = 24;
parameter [7:0] KEY_EQUAL = 25;
parameter [7:0] KEY_BACKSLASH = 26;
parameter [7:0] KEY_BS = 27;
parameter [7:0] KEY_DEL_LINE = 28;
parameter [7:0] KEY_CLS_HOME = 29;
parameter [7:0] KEY_TAB = 30;
parameter [7:0] KEY_Q = 31;
parameter [7:0] KEY_W = 32;
parameter [7:0] KEY_E = 33;
parameter [7:0] KEY_R = 34;
parameter [7:0] KEY_T = 35;
parameter [7:0] KEY_Y = 36;
parameter [7:0] KEY_U = 37;
parameter [7:0] KEY_I = 38;
parameter [7:0] KEY_O = 39;
parameter [7:0] KEY_P = 40;
parameter [7:0] KEY_OPEN_BRACKET = 41;
parameter [7:0] KEY_CLOSE_BRACKET = 42;
parameter [7:0] KEY_RETURN = 43;
parameter [7:0] KEY_CONTROL = 44;
parameter [7:0] KEY_A = 45;
parameter [7:0] KEY_S = 46;
parameter [7:0] KEY_D = 47;
parameter [7:0] KEY_F = 48;
parameter [7:0] KEY_G = 49;
parameter [7:0] KEY_H = 50;
parameter [7:0] KEY_J = 51;
parameter [7:0] KEY_K = 52;
parameter [7:0] KEY_L = 53;
parameter [7:0] KEY_SEMICOLON = 54;
parameter [7:0] KEY_QUOTE = 55;
parameter [7:0] KEY_BACK_QUOTE = 56;
parameter [7:0] KEY_GRAPH = 57;
parameter [7:0] KEY_UP = 58;
parameter [7:0] KEY_SHIFT = 59;
parameter [7:0] KEY_Z = 60;
parameter [7:0] KEY_X = 61;
parameter [7:0] KEY_C = 62;
parameter [7:0] KEY_V = 63;
parameter [7:0] KEY_B = 64;
parameter [7:0] KEY_N = 65;
parameter [7:0] KEY_M = 66;
parameter [7:0] KEY_COMMA = 67;
parameter [7:0] KEY_DOT = 68;
parameter [7:0] KEY_SLASH = 69;
parameter [7:0] KEY_MU = 70;
parameter [7:0] KEY_LEFT = 71;
parameter [7:0] KEY_RIGHT = 72;
parameter [7:0] KEY_CAP_LOCK = 73;
parameter [7:0] KEY_SPACE = 74;
parameter [7:0] KEY_DOWN = 75;

always @(posedge clk) begin
	if(reset) begin
		KA <= 14'b11111111111111;
		KD <=  7'b1111111;
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
					KEY_SHIFT        : begin KA['h0] <= key_released; KD[6] <= key_released; end
					KEY_Z            : begin KA['h0] <= key_released; KD[5] <= key_released; end 
					KEY_X            : begin KA['h0] <= key_released; KD[4] <= key_released; end 
					KEY_C            : begin KA['h0] <= key_released; KD[3] <= key_released; end 
					KEY_V            : begin KA['h0] <= key_released; KD[2] <= key_released; end 
					KEY_B            : begin KA['h0] <= key_released; KD[1] <= key_released; end 
					KEY_N            : begin KA['h0] <= key_released; KD[0] <= key_released; end 
					KEY_CONTROL      : begin KA['h1] <= key_released; KD[6] <= key_released; end
					KEY_A            : begin KA['h1] <= key_released; KD[5] <= key_released; end   
					KEY_S            : begin KA['h1] <= key_released; KD[4] <= key_released; end   
					KEY_D            : begin KA['h1] <= key_released; KD[3] <= key_released; end   
					KEY_F            : begin KA['h1] <= key_released; KD[2] <= key_released; end   
					KEY_G            : begin KA['h1] <= key_released; KD[1] <= key_released; end   
					KEY_H            : begin KA['h1] <= key_released; KD[0] <= key_released; end   
					KEY_TAB          : begin KA['h2] <= key_released; KD[6] <= key_released; end
					KEY_Q            : begin KA['h2] <= key_released; KD[5] <= key_released; end      
					KEY_W            : begin KA['h2] <= key_released; KD[4] <= key_released; end      
					KEY_E            : begin KA['h2] <= key_released; KD[3] <= key_released; end      
					KEY_R            : begin KA['h2] <= key_released; KD[2] <= key_released; end      
					KEY_T            : begin KA['h2] <= key_released; KD[1] <= key_released; end      
					KEY_Y            : begin KA['h2] <= key_released; KD[0] <= key_released; end      
					KEY_ESC          : begin KA['h3] <= key_released; KD[6] <= key_released; end
					KEY_1            : begin KA['h3] <= key_released; KD[5] <= key_released; end 
					KEY_2            : begin KA['h3] <= key_released; KD[4] <= key_released; end 
					KEY_3            : begin KA['h3] <= key_released; KD[3] <= key_released; end 
					KEY_4            : begin KA['h3] <= key_released; KD[2] <= key_released; end 
					KEY_5            : begin KA['h3] <= key_released; KD[1] <= key_released; end 
					KEY_6            : begin KA['h3] <= key_released; KD[0] <= key_released; end 
					KEY_EQUAL        : begin KA['h4] <= key_released; KD[5] <= key_released; end 
					KEY_MINUS        : begin KA['h4] <= key_released; KD[4] <= key_released; end 
					KEY_0            : begin KA['h4] <= key_released; KD[3] <= key_released; end 
					KEY_9            : begin KA['h4] <= key_released; KD[2] <= key_released; end 
					KEY_8            : begin KA['h4] <= key_released; KD[1] <= key_released; end 
					KEY_7            : begin KA['h4] <= key_released; KD[0] <= key_released; end 
					KEY_BS           : begin KA['h5] <= key_released; KD[6] <= key_released; end 
					KEY_P            : begin KA['h5] <= key_released; KD[3] <= key_released; end 
					KEY_O            : begin KA['h5] <= key_released; KD[2] <= key_released; end 
					KEY_I            : begin KA['h5] <= key_released; KD[1] <= key_released; end 
					KEY_U            : begin KA['h5] <= key_released; KD[0] <= key_released; end 
					KEY_RETURN       : begin KA['h6] <= key_released; KD[6] <= key_released; end                        
					KEY_QUOTE        : begin KA['h6] <= key_released; KD[4] <= key_released; end
					KEY_SEMICOLON    : begin KA['h6] <= key_released; KD[3] <= key_released; end
					KEY_L            : begin KA['h6] <= key_released; KD[2] <= key_released; end
					KEY_K            : begin KA['h6] <= key_released; KD[1] <= key_released; end
					KEY_J            : begin KA['h6] <= key_released; KD[0] <= key_released; end                                                       
					KEY_GRAPH        : begin KA['h7] <= key_released; KD[6] <= key_released; end 
					KEY_BACK_QUOTE   : begin KA['h7] <= key_released; KD[5] <= key_released; end 
					KEY_SPACE        : begin KA['h7] <= key_released; KD[4] <= key_released; end
					KEY_SLASH        : begin KA['h7] <= key_released; KD[3] <= key_released; end 
					KEY_DOT          : begin KA['h7] <= key_released; KD[2] <= key_released; end 
					KEY_COMMA        : begin KA['h7] <= key_released; KD[1] <= key_released; end 
					KEY_M            : begin KA['h7] <= key_released; KD[0] <= key_released; end 
					KEY_BACKSLASH    : begin KA['hA] <= key_released; KD[5] <= key_released; end 
					KEY_CLOSE_BRACKET: begin KA['hA] <= key_released; KD[4] <= key_released; end 
					KEY_OPEN_BRACKET : begin KA['hA] <= key_released; KD[3] <= key_released; end 
					KEY_MU           : begin KA['hA] <= key_released; KD[2] <= key_released; end 
					KEY_DEL          : begin KA['hA] <= key_released; KD[1] <= key_released; end 
					KEY_INS          : begin KA['hA] <= key_released; KD[0] <= key_released; end  
					KEY_CAP_LOCK     : begin KA['hB] <= key_released; KD[6] <= key_released; end 
					KEY_DEL_LINE     : begin KA['hB] <= key_released; KD[5] <= key_released; end 
					KEY_CLS_HOME     : begin KA['hB] <= key_released; KD[4] <= key_released; end 
					KEY_UP           : begin KA['hB] <= key_released; KD[3] <= key_released; end 
					KEY_LEFT         : begin KA['hB] <= key_released; KD[2] <= key_released; end 
					KEY_RIGHT        : begin KA['hB] <= key_released; KD[1] <= key_released; end 
					KEY_DOWN         : begin KA['hB] <= key_released; KD[0] <= key_released; end 
					KEY_F1           : begin KA['hC] <= key_released; KD[5] <= key_released; end 
					KEY_F2           : begin KA['hC] <= key_released; KD[4] <= key_released; end 
					KEY_F3           : begin KA['hC] <= key_released; KD[3] <= key_released; end 
					KEY_F4           : begin KA['hC] <= key_released; KD[2] <= key_released; end    
					KEY_F10          : begin KA['hD] <= key_released; KD[5] <= key_released; end   
					KEY_F9           : begin KA['hD] <= key_released; KD[4] <= key_released; end   
					KEY_F8           : begin KA['hD] <= key_released; KD[3] <= key_released; end   
					KEY_F7           : begin KA['hD] <= key_released; KD[2] <= key_released; end 
					KEY_F6           : begin KA['hD] <= key_released; KD[1] <= key_released; end 
					KEY_F5           : begin KA['hD] <= key_released; KD[0] <= key_released; end
				endcase
			end
		end
	end
end

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf ps2_keyboard (
	.CLK		 ( clk             ),
	.nRESET	 ( !reset          ),
	
	// PS/2 interface
	.PS2_CLK  ( ps2_clk         ),
	.PS2_DATA ( ps2_data        ),
	
	// Byte-wide data interface - only valid for one clock
	// so must be latched externally if required
	.DATA		  ( byte   ),
	.VALID	  ( valid  ),
	.ERROR	  ( error  )
);


endmodule
