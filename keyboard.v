
module keyboard ( 
	input clk,
	input reset,

	// ps2 interface	
	input ps2_clk,
	input ps2_data,
	
	// VTL chip interface
   input      [10:0] address,   
	output     [ 6:0] KD,   
	output reg reset_key,
	
	output debug
);

// demux LS138 3 high bits int 4 bits
wire [3:0] ABCD = (address[10:8] == 3'b000) ? 4'b1110 :
                  (address[10:8] == 3'b001) ? 4'b1101 :
                  (address[10:8] == 3'b010) ? 4'b1011 :
                  (address[10:8] == 3'b011) ? 4'b0111 : 4'b1111;

wire [11:0] KA = {ABCD, address[7:0]};

// keyboard output
assign KD = ((KA[ 0] == 0) ? KM[ 0] : 7'b1111111) & 
            ((KA[ 1] == 0) ? KM[ 1] : 7'b1111111) &
				((KA[ 2] == 0) ? KM[ 2] : 7'b1111111) &
				((KA[ 3] == 0) ? KM[ 3] : 7'b1111111) &
				((KA[ 4] == 0) ? KM[ 4] : 7'b1111111) &
				((KA[ 5] == 0) ? KM[ 5] : 7'b1111111) &
				((KA[ 6] == 0) ? KM[ 6] : 7'b1111111) &
				((KA[ 7] == 0) ? KM[ 7] : 7'b1111111) &
				((KA[ 8] == 0) ? KM[ 8] : 7'b1111111) &
				((KA[ 9] == 0) ? KM[ 9] : 7'b1111111) &
				((KA[10] == 0) ? KM[10] : 7'b1111111) &
				((KA[11] == 0) ? KM[11] : 7'b1111111) ;

// debug
assign debug = KM[0][0];
				
// keyboard matrix (12 rows x 7 columns)
reg [6:0] KM [11:0]; 

parameter [15:0] KEY_RESET         = 'h77; // as pause/break key -- not mapped on the I/O but directly on the /RES line to the CPU
parameter [15:0] KEY_ALT_LEFT      = 'h11; // as pause/break key -- not mapped on the I/O but directly on the /RES line to the CPU
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
parameter [15:0] KEY_DEL           = 'he071;
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
parameter [15:0] KEY_1_NUMPAD      = 'h69;
parameter [15:0] KEY_2_NUMPAD      = 'h72;
parameter [15:0] KEY_3_NUMPAD      = 'h7a;
parameter [15:0] KEY_4_NUMPAD      = 'h6b;
parameter [15:0] KEY_5_NUMPAD      = 'h73;
parameter [15:0] KEY_6_NUMPAD      = 'h74;
parameter [15:0] KEY_7_NUMPAD      = 'h6c;
parameter [15:0] KEY_8_NUMPAD      = 'h75;
parameter [15:0] KEY_9_NUMPAD      = 'h7d;
parameter [15:0] KEY_0_NUMPAD      = 'h70;
parameter [15:0] KEY_MINUS         = 'h4e;
parameter [15:0] KEY_EQUAL         = 'h55;
parameter [15:0] KEY_BACKSLASH     = 'h0e;
parameter [15:0] KEY_BS            = 'h66;
parameter [15:0] KEY_DEL_LINE      = 'he069;
parameter [15:0] KEY_CLS_HOME      = 'he06c;
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
parameter [15:0] KEY_CONTROL       = 'h14;  
parameter [15:0] KEY_CONTROL_RIGHT = 'he014; 
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
parameter [15:0] KEY_GRAPH         = 'he07a;
parameter [15:0] KEY_UP            = 'he075;
parameter [15:0] KEY_SHIFT         = 'h12;  
parameter [15:0] KEY_SHIFT_RIGHT   = 'h59;  
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
parameter [15:0] KEY_MU            = 'he07d;   
parameter [15:0] KEY_LEFT          = 'he06b;
parameter [15:0] KEY_RIGHT         = 'he074;
parameter [15:0] KEY_CAP_LOCK      = 'h58;
parameter [15:0] KEY_SPACE         = 'h29;
parameter [15:0] KEY_DOWN          = 'he072;

parameter [15:0] KEY_RETURN_NUMPAD = 'he05a;
parameter [15:0] KEY_MINUS_NUMPAD  = 'h7b;
parameter [15:0] KEY_PLUS_NUMPAD   = 'h79;
parameter [15:0] KEY_MULT_NUMPAD   = 'h7c;
parameter [15:0] KEY_SLASH_NUMPAD  = 'he04a;
parameter [15:0] KEY_DOT_NUMPAD    = 'h71;

wire [7:0] kdata;  // keyboard data byte, 0xE0 = extended key, 0xF0 release key
wire valid;        // 1 = data byte contains valid keyboard data 
wire error;        // not used here

reg key_status;
reg key_extended;

wire [15:0] key = { (key_extended ? 8'he0 : 8'h00) , kdata };

always @(posedge clk) begin
	if(reset) begin		
      key_status <= 1'b1;
      key_extended <= 1'b0;
		KM[ 0] <= 7'b1111111;
		KM[ 1] <= 7'b1111111;
		KM[ 2] <= 7'b1111111;
		KM[ 3] <= 7'b1111111;
		KM[ 4] <= 7'b1111111;
		KM[ 5] <= 7'b1111111;
		KM[ 6] <= 7'b1111111;
		KM[ 7] <= 7'b1111111;
		KM[ 8] <= 7'b1111111;
		KM[ 9] <= 7'b1111111;
		KM[10] <= 7'b1111111;
		KM[11] <= 7'b1111111;		
	end 
	else begin
		// ps2 decoder has received a valid byte
		if(valid) begin
			if(kdata == 8'he0) 
				// extended key code
            key_extended <= 1'b1;
         else if(kdata == 8'hf0)
				// release code
            key_status <= 1'b1;
         else begin
			   // key press
				key_extended <= 1'b0;
				key_status   <= 1'b0;
				
				case(key)	
               KEY_RESET        : begin reset_key <= ~key_status; end													
					KEY_ALT_LEFT     : begin reset_key <= ~key_status; end													
					KEY_SHIFT        : begin KM['h0][6] <= key_status; end
					KEY_SHIFT_RIGHT  : begin KM['h0][6] <= key_status; end
					KEY_Z            : begin KM['h0][5] <= key_status; end 
					KEY_X            : begin KM['h0][4] <= key_status; end 
					KEY_C            : begin KM['h0][3] <= key_status; end 
					KEY_V            : begin KM['h0][2] <= key_status; end 
					KEY_B            : begin KM['h0][1] <= key_status; end 
					KEY_N            : begin KM['h0][0] <= key_status; end 
					KEY_CONTROL      : begin KM['h1][6] <= key_status; end
					KEY_CONTROL_RIGHT: begin KM['h1][6] <= key_status; end
					KEY_A            : begin KM['h1][5] <= key_status; end   
					KEY_S            : begin KM['h1][4] <= key_status; end   
					KEY_D            : begin KM['h1][3] <= key_status; end   
					KEY_F            : begin KM['h1][2] <= key_status; end   
					KEY_G            : begin KM['h1][1] <= key_status; end   
					KEY_H            : begin KM['h1][0] <= key_status; end   
					KEY_TAB          : begin KM['h2][6] <= key_status; end
					KEY_Q            : begin KM['h2][5] <= key_status; end      
					KEY_W            : begin KM['h2][4] <= key_status; end      
					KEY_E            : begin KM['h2][3] <= key_status; end      
					KEY_R            : begin KM['h2][2] <= key_status; end      
					KEY_T            : begin KM['h2][1] <= key_status; end      
					KEY_Y            : begin KM['h2][0] <= key_status; end      
					KEY_ESC          : begin KM['h3][6] <= key_status; end
					KEY_1            : begin KM['h3][5] <= key_status; end 
					KEY_2            : begin KM['h3][4] <= key_status; end 
					KEY_3            : begin KM['h3][3] <= key_status; end 
					KEY_4            : begin KM['h3][2] <= key_status; end 
					KEY_5            : begin KM['h3][1] <= key_status; end 
					KEY_6            : begin KM['h3][0] <= key_status; end 
					KEY_EQUAL        : begin KM['h4][5] <= key_status; end 
					KEY_MINUS        : begin KM['h4][4] <= key_status; end 
					KEY_0            : begin KM['h4][3] <= key_status; end 
					KEY_9            : begin KM['h4][2] <= key_status; end 
					KEY_8            : begin KM['h4][1] <= key_status; end 
					KEY_7            : begin KM['h4][0] <= key_status; end 
					KEY_BS           : begin KM['h5][6] <= key_status; end 
					KEY_P            : begin KM['h5][3] <= key_status; end 
					KEY_O            : begin KM['h5][2] <= key_status; end 
					KEY_I            : begin KM['h5][1] <= key_status; end 
					KEY_U            : begin KM['h5][0] <= key_status; end 
					KEY_RETURN       : begin KM['h6][6] <= key_status; end                        
					KEY_QUOTE        : begin KM['h6][4] <= key_status; end
					KEY_SEMICOLON    : begin KM['h6][3] <= key_status; end
					KEY_L            : begin KM['h6][2] <= key_status; end
					KEY_K            : begin KM['h6][1] <= key_status; end
					KEY_J            : begin KM['h6][0] <= key_status; end                                                       
					KEY_GRAPH        : begin KM['h7][6] <= key_status; end 
					KEY_BACK_QUOTE   : begin KM['h7][5] <= key_status; end 
					KEY_SPACE        : begin KM['h7][4] <= key_status; end
					KEY_SLASH        : begin KM['h7][3] <= key_status; end 
					KEY_DOT          : begin KM['h7][2] <= key_status; end 
					KEY_COMMA        : begin KM['h7][1] <= key_status; end 
					KEY_M            : begin KM['h7][0] <= key_status; end 
					KEY_BACKSLASH    : begin KM['hb][5] <= key_status; end 
					KEY_CLOSE_BRACKET: begin KM['hb][4] <= key_status; end 
					KEY_OPEN_BRACKET : begin KM['hb][3] <= key_status; end 
					KEY_MU           : begin KM['hb][2] <= key_status; end 
					KEY_DEL          : begin KM['hb][1] <= key_status; end 
					KEY_INS          : begin KM['hb][0] <= key_status; end  
					KEY_CAP_LOCK     : begin KM['ha][6] <= key_status; end 
					KEY_DEL_LINE     : begin KM['ha][5] <= key_status; end 
					KEY_CLS_HOME     : begin KM['ha][4] <= key_status; end 
					KEY_UP           : begin KM['ha][3] <= key_status; end 
					KEY_LEFT         : begin KM['ha][2] <= key_status; end 
					KEY_RIGHT        : begin KM['ha][1] <= key_status; end 
					KEY_DOWN         : begin KM['ha][0] <= key_status; end 
					KEY_F1           : begin KM['h8][5] <= key_status; end 
					KEY_F2           : begin KM['h8][4] <= key_status; end 
					KEY_F3           : begin KM['h8][3] <= key_status; end 
					KEY_F4           : begin KM['h8][2] <= key_status; end    
					KEY_F10          : begin KM['h9][5] <= key_status; end   
					KEY_F9           : begin KM['h9][4] <= key_status; end   
					KEY_F8           : begin KM['h9][3] <= key_status; end   
					KEY_F7           : begin KM['h9][2] <= key_status; end 
					KEY_F6           : begin KM['h9][1] <= key_status; end 
					KEY_F5           : begin KM['h9][0] <= key_status; end
	
					// num pad
					KEY_0_NUMPAD     : begin KM['h4][3] <= key_status; end 
					KEY_1_NUMPAD     : begin KM['h3][5] <= key_status; end 
					KEY_2_NUMPAD     : begin KM['h3][4] <= key_status; end 
					KEY_3_NUMPAD     : begin KM['h3][3] <= key_status; end 
					KEY_4_NUMPAD     : begin KM['h3][2] <= key_status; end 
					KEY_5_NUMPAD     : begin KM['h3][1] <= key_status; end 
					KEY_6_NUMPAD     : begin KM['h3][0] <= key_status; end 
					KEY_7_NUMPAD     : begin KM['h4][0] <= key_status; end 
					KEY_8_NUMPAD     : begin KM['h4][1] <= key_status; end 
					KEY_9_NUMPAD     : begin KM['h4][2] <= key_status; end 									
					KEY_RETURN_NUMPAD: begin KM['h6][6] <= key_status; end                        
					KEY_MINUS_NUMPAD : begin KM['h4][4] <= key_status; end 
					KEY_PLUS_NUMPAD  : begin KM['h4][5] <= key_status; KM['h0][6] <= key_status; end  // shift + "="
					KEY_MULT_NUMPAD  : begin KM['h4][1] <= key_status; KM['h0][6] <= key_status; end  // shift + "8"
					KEY_SLASH_NUMPAD : begin KM['h7][3] <= key_status; end 
					KEY_DOT_NUMPAD   : begin KM['h7][2] <= key_status; end 	
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
	.DATA		  ( kdata  ),
	.VALID	  ( valid  ),
	.ERROR	  ( error  )
);

endmodule
