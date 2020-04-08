// Video Technology Laser 500 video chip
// "VTL 0390-00-00 MD52701" ("MD61800" on Laser 700)

module VTL_chip 
(	
	input    F14M,	           // pixel clock
	input    RESET,           // reset signal
		
	// cpu interface
   output           CPUCK,       // CPU clock to CPU (F14M / 4) - (not used on the MiST, we use F14M & CPUENA)
	output           CPUENA,      // CPU enabled signal
	output reg       WAIT_n,      // WAIT (TODO handle wait states)
	input            MREQ_n,      // MEMORY REQUEST (not used--yet) indicates the bus holds a valid memory address
	input            IORQ_n,      // IO REQUEST 0=read from I/O
	input            RD_n,        // READ       0=cpu reads
	input            WR_n,        // WRITE      0=cpu writes
	input     [15:0] A,           // 16 bit address bus
	input      [7:0] DO,          // 8 bit data output from cpu
	output reg [7:0] DI,          // 8 bit data input for cpu
	
	// keyboard 	
	input [ 6:0] KD,  
   input        cassette_bit_in,	
	
	// sdram interface
	output     [24:0] sdram_addr, // sdram address  
	input       [7:0] sdram_dout, // sdram data ouput
   output reg  [7:0] sdram_din,  // sdram data input
	output reg        sdram_wr,   // sdram write
	output reg        sdram_rd,   // sdram read	
	
	// output to CRT screen
	output hsync,
	output vsync,
	output [5:0] r,
	output [5:0] g,
	output [5:0] b,
	
	output reg BUZZER,
	output reg CASOUT,  // mapped I/O bit 2  
	
	// other ports
	input blank
);

parameter hfp = 10;         // horizontal front porch, unused time before hsync
parameter hsw = 66;         // hsync width
parameter hbp = 78;         // horizontal back porch, unused time after hsync

parameter HEIGHT              = 192;  // height of active area  
parameter TOP_BORDER_WIDTH    =  64;  // top border
parameter BOTTOM_BORDER_WIDTH =  56;  // bottom
parameter V                   = 312;  // number of lines

parameter WIDTH               = 640;  // width of active area  
parameter LEFT_BORDER_WIDTH   =  72;  // left border
parameter RIGHT_BORDER_WIDTH  =  86;  // right border
parameter H                   = 798;  // width of visible area

// 14778730 / (row_length * 312) =~49.7 => row_length = 952

reg[9:0]   hcnt;          // horizontal pixel counter
reg[9:0]   vcnt;          // vertical pixel counter
wire[12:0] xcnt;          // active area x TODO, replace with hcnt?
reg[9:0]   ycnt;          // active area y

reg[7:0]  char;           // bitmap graphic data to display
reg[7:0]  fgbg;           // foreground-background colors for the graphic to display
reg[7:0]  charsetData;    // bitmap data read from charset ROM
reg[7:0]  ramData;        // data read from RAM
reg[7:0]  ramDataD;       // data read from RAM at previous step
reg[13:0] ramAddress;     // address in video RAM to read from
reg[12:0] charsetAddress; // address in charset ROM to read from
wire[7:0] charsetQ;       // data ream from charset ROM

reg[7:0]  ramQ;    // test

reg [3:0] pixel;          // pixel to draw (color index in the palette)

reg [2:0] vdc_graphic_mode_number  = 5;  // graphic mode number 0..5
reg       vdc_text80_enabled       = 0;  // TEX80 mode, otherwise TEXT40
reg [3:0] vdc_text80_foreground    = 12; // foreground color for TEXT80 &c.
reg [3:0] vdc_text80_background    = 3;  // background color for TEXT80 &c.
reg [3:0] vdc_border_color         = 10; // border color
reg       vdc_page_7               = 0;  // 1=video RAM is in page 7 (Laser 500/700), 3 otherwise (Laser 350)

// memory mapped I/O write registers 
//reg io_bit_7                    ; // mapped to bit 7
reg caps_lock_bit               ; // mapped to bit 6
//reg io_bit_5                    ; // mapped to bit 5
//reg io_bit_4                    ; // mapped to bit 4
reg vdc_graphic_mode_enabled = 0; // mapped to bit 3
//reg cassette_bit_out_l          ; // mapped to bit 1 




// TODO use real 1bit colors
/*
parameter col0 = 12'h000;  // black 
parameter col1 = 12'h00f;  // blue 
parameter col2 = 12'h080;  // green 
parameter col3 = 12'h09f;  // cyan 
parameter col4 = 12'h600;  // red 
parameter col5 = 12'h83f;  // magenta 
parameter col6 = 12'h780;  // yellow 
parameter col7 = 12'hccc;  // bright grey 
parameter col8 = 12'h667;  // dark grey 
parameter col9 = 12'h88f;  // bright blue 
parameter cola = 12'h5e3;  // bright green 
parameter colb = 12'h8cf;  // bright cyan 
parameter colc = 12'hf59;  // bright red 
parameter cold = 12'hf9f;  // bright magenta 
parameter cole = 12'hee6;  // bright yellow 
parameter colf = 12'hfff;  // white 
*/

parameter col0 = 12'h000;  // black 
parameter col1 = 12'h008;  // blue 
parameter col2 = 12'h080;  // green 
parameter col3 = 12'h088;  // cyan 
parameter col4 = 12'h800;  // red 
parameter col5 = 12'h088;  // magenta 
parameter col6 = 12'h880;  // yellow 
parameter col7 = 12'h888;  // bright grey 
parameter col8 = 12'h444;  // dark grey 
parameter col9 = 12'h44f;  // bright blue 
parameter cola = 12'h4f4;  // bright green 
parameter colb = 12'h4ff;  // bright cyan 
parameter colc = 12'hf44;  // bright red 
parameter cold = 12'hf4f;  // bright magenta 
parameter cole = 12'hff4;  // bright yellow 
parameter colf = 12'hfff;  // white 

rom_charset rom_charset (
	.address(charsetAddress),
	.clock(F14M),
	.q(charsetQ)
);							  						
							  
wire[9:0] load_column;    // column where the ramAddress is initialized, changes depending on the video mode

wire [3:0] fg;
wire [3:0] bg;

// generate negative hsync and vsync signals
assign hsync = (hcnt < hsw) ? 0 : 1;
assign vsync = (vcnt <   2) ? 0 : 1;

// set row address loading colum
assign load_column =  vdc_graphic_mode_enabled && vdc_graphic_mode_number == 5 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(1*8)
						  : vdc_graphic_mode_enabled && vdc_graphic_mode_number == 4 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(2*8)
						  : vdc_graphic_mode_enabled && vdc_graphic_mode_number == 3 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(1*8)
						  : vdc_graphic_mode_enabled && vdc_graphic_mode_number == 2 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(2*8)
						  : vdc_graphic_mode_enabled && vdc_graphic_mode_number == 1 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(4*8)
						  : vdc_graphic_mode_enabled && vdc_graphic_mode_number == 0 ? hsw+hbp+LEFT_BORDER_WIDTH-1-(1*8)
						  : vdc_text80_enabled ?                                       hsw+hbp+LEFT_BORDER_WIDTH-1-(1*8)
						  :                                                            hsw+hbp+LEFT_BORDER_WIDTH-1-(2*8);
						  
// calculate foreground and background colors						  
assign fg = (vdc_graphic_mode_enabled && (vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 2)) || vdc_text80_enabled ? vdc_text80_foreground : fgbg[7:4];
assign bg = (vdc_graphic_mode_enabled && (vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 2)) || vdc_text80_enabled ? vdc_text80_background : fgbg[3:0];

// calculate x offset (TODO replace with hcnt or clk_div?)
assign xcnt = hcnt - (hsw+hbp+LEFT_BORDER_WIDTH);

wire [2:0] clk_div = hcnt[2:0];   // clock divider and bus slot assignment

assign CPUCK  = clk_div[1];   // derive CPUCK by dividing F14M by 4
// warning: CPUCK not used, F14M is fed into T80

assign CPUENA = clk_div == 2; // CPU enabled signal
//wire   CV     = ~clk_div[2];  // CV=1 video owns bus, CV=0 CPU owns bus

/*
Details of the state machine (T=clk_div):
 
VIDEO T=0
VIDEO T=1	
VIDEO T=2
VIDEO T=3  
				finish video RAM read
				starts charset ROM reading
			   if cpu read/write put CPU in wait state and initiate read/write cpu RAM 
            
CPU   T=4
CPU   T=5
CPU   T=6
CPU   T=7  
				end charset ROM reading, start video RAM reading
				if CPU wait state, finish cpu RAM read/write, release CPU wait, present data to cpu

T=0 video ram reading starts 
T=1 video ram is reading
T=2 video ram reading completed
T=3 nothing
T=4 video ram data transfered into video register
    charset rom reading starts
    cpu ram reading starts 
T=5 cpu reading
T=6 cpu reading completed
T=7 cpu transfer    				
*/

parameter CYCLE_VDC_STARTREAD = 7;  // T=0
parameter CYCLE_VDC_ENDREAD   = 0;  // T=1

parameter CYCLE_CPU_EXECUTE   = 1;  // T=2
parameter CYCLE_CPU_STARTREAD = 2;  // T=3
parameter CYCLE_CPU_ENDREAD   = 3;  // T=4
parameter CYCLE_CPU_ENDWRITE  = 4;  // T=5

// negated signals (easier to read)
wire MREQ = ~MREQ_n;
wire WR   = ~WR_n;
wire RD   = ~RD_n;
wire IORQ = ~IORQ_n;

always@(posedge F14M) begin

	if(RESET) begin
		hcnt <= 0;
		vcnt <= 0;
		pixel <= 0;		
		banks[0] <= 0;
		WAIT_n <= 1;
		sdram_rd <= 0;
		sdram_wr <= 0;
		CASOUT <= 0;
		BUZZER <= 0;
	end
	else begin	
		if(clk_div == CYCLE_CPU_EXECUTE) 
			sdram_rd <= 0;				
		else
			sdram_rd <= 1;				
			
		// T=4: MEMORY 
		if(clk_div == CYCLE_CPU_ENDREAD && MREQ) begin			
			if(WR) begin
				if(mapped_io) begin											
					caps_lock_bit            <= DO[6];
					vdc_graphic_mode_enabled <= DO[3];
					CASOUT                   <= DO[2];					
					BUZZER                   <= DO[0];
				end
				else begin
					sdram_wr <= bank_is_ram;
					sdram_din <= DO;  			
				end
			end			
			if(RD) begin
				if(mapped_io) begin											
					DI[7] <= cassette_bit_in;					
					DI[6:0] <= KD;						      
				end				
				else 
				   DI <= sdram_dout; // read from RAM/ROM
			end						
		end
		
		// end of write
		if(clk_div == CYCLE_CPU_ENDWRITE) begin
			sdram_wr <= 0; // terminate any memory write started at T=3
		end
												
		// T=4: Z80 IO 
		if(clk_div == CYCLE_CPU_ENDREAD && IORQ) begin
			if(RD) begin
				DI <= { DI[7:1], 1'b1 }; // value returned from unused ports
				// TODO implement I/O read
				//
				//switch(port & 0xFF) {					
				//case 0x2b: return joy0;  // joystick 8 directions
				//case 0x27: return joy1;  // joystick fire buttons      
				//case 0x00: return printerReady;                  
				//case 0x2e: return 0x00;  // joystick 2 not emulated yet
				//case 0x10:
				//case 0x11:
				//case 0x12:
				//case 0x13:
				//case 0x14:
				//	return emulate_fdc ? floppy_read_port(port & 0xFF) : 0xFF;   					
			end
			if(WR) begin
				case(A[7:0])
					'h40: banks[0] <= DO[3:0];
					'h41: banks[1] <= DO[3:0];
					'h42: banks[2] <= DO[3:0];
					'h43: banks[3] <= DO[3:0];
					'h44:
						begin	
							vdc_page_7         <= ~DO[3];
							vdc_text80_enabled <= DO[0]; 
							vdc_border_color   <= DO[7:4];
							
							if(DO[2:1] == 'b00)  vdc_graphic_mode_number <= 5;              											
							if(DO[2:0] == 'b010) vdc_graphic_mode_number <= 4;
							if(DO[2:0] == 'b011) vdc_graphic_mode_number <= 3;
							if(DO[2:0] == 'b110) vdc_graphic_mode_number <= 2;
							if(DO[2:0] == 'b111) vdc_graphic_mode_number <= 1;
							if(DO[2:1] == 'b10)  vdc_graphic_mode_number <= 0;                  
						end
					'h45:
						begin
							vdc_text80_foreground <= DO[7:4];
							vdc_text80_background <= DO[3:0];         
						end
					'h0d: ;
						// printerWrite(value);
					'h0e: ;
						// printer port duplicated here							
					'h10: ;
					'h11: ;
					'h12: ;
					'h13: ;
					'h14: ;
						//if(emulate_fdc) floppy_write_port(port & 0xFF, value); 
						//return;     				
				endcase				
			end
		end		
   				
		// counters
		if(hcnt == hsw+hbp+H+hfp-1) 
		begin
			hcnt <= 10'd0;
			if(vcnt == V-1) 
			begin
				vcnt <= 10'd0;				
			end
			else vcnt <= vcnt + 10'd1;
				
			if(vcnt === TOP_BORDER_WIDTH-1) ycnt <= 10'd0;
			else                            ycnt <= ycnt + 10'd1;
		end
		else hcnt <= hcnt + 10'd1;
      	
		// draw pixel at hcnt,vcnt, graphic data contained in "char"
		if(hcnt < hsw+hbp || vcnt < 2 || hcnt >= hsw+hbp+H) 
			pixel <= 0;   // blanking zone 
		else if(blank == 1) 
			pixel <= 'hC; // forced blank (io_download)        	
		else if( (vcnt < TOP_BORDER_WIDTH || vcnt >= TOP_BORDER_WIDTH + HEIGHT) || 
					(hcnt < hsw+hbp + LEFT_BORDER_WIDTH || hcnt >= hsw+hbp + LEFT_BORDER_WIDTH + WIDTH)) 
			pixel <= vdc_border_color; 				
		else 
		begin
			if(vdc_graphic_mode_enabled == 1) begin
				if(vdc_graphic_mode_number == 5) begin
					// GR 5 640x192x1
					pixel <= char[0] == 1 ? fg : bg;
					char <= char >> 1;         
				end 
				else if(vdc_graphic_mode_number == 4) begin
					// GR 4 320x192x2
					if(xcnt[0] == 0) begin
						pixel <= char[0] == 1 ? fg : bg;
						char <= char >> 1;
					end               
				end 
				else if(vdc_graphic_mode_number == 3 || vdc_graphic_mode_number == 0) begin
					// GR 3 160x192x16, GR 0 160x96
					if(xcnt[1:0] == 0) begin
						pixel = char[3:0];
						char = char >> 4;
					end               
				end 
				else if(vdc_graphic_mode_number == 2) begin
					// GR 2 320x196x1
					if(xcnt[0] == 0) begin
						pixel <= char[0] == 1 ? fg : bg;
						char <= char >> 1;
					end
				end 
				else if(vdc_graphic_mode_number == 1) begin
					// GR 1 160x192x2
					if(xcnt[1:0] == 0) begin
						pixel <= char[0] == 1 ? fg : bg;
						char <= char >> 1;
					end
				end
			end	
			else if(vdc_text80_enabled) begin
				// TEXT 80
				pixel <= char[0] == 1 ? fg : bg;
				char <= char >> 1;         
			end
			else begin
				// TEXT 40
				if(xcnt[0] == 0) begin
					pixel <= char[0] == 1 ? fg : bg;
					char <= char >> 1;
				end
			end	
		end

		// read character from RAM and stores into latch "ramData", starts ROM reading   
		if(xcnt[2:0] == CYCLE_VDC_ENDREAD) begin
			ramData <= sdram_dout;			
			charsetAddress <= (sdram_dout << 3) | ycnt[2:0]; // TODO eng/ger/fra									
		end		

		// calculate RAM address of character/byte and start reading video RAM
		if(xcnt[2:0] == CYCLE_VDC_STARTREAD) begin 
			// load start row address on the leftmost column
			if(hcnt == load_column) begin
				if(vdc_graphic_mode_enabled) begin
					if(vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 4 || vdc_graphic_mode_number == 3) begin
						// GR 5, GR 4, GR 3                                                               
						ramAddress[13] <= ycnt[2];
						ramAddress[12] <= ycnt[1];
						ramAddress[11] <= ycnt[0];
						ramAddress[10] <= ycnt[5];
						ramAddress[ 9] <= ycnt[4];
						ramAddress[ 8] <= ycnt[3];
						ramAddress[ 7] <= ycnt[7];
						ramAddress[ 6] <= ycnt[6];
						ramAddress[ 5] <= ycnt[7];
						ramAddress[ 4] <= ycnt[6];
						ramAddress[3:0] <= 0;
					end else if(vdc_graphic_mode_number == 2 || vdc_graphic_mode_number == 1) begin
						// GR 2            
						ramAddress[13] <= 1;
						ramAddress[12] <= ycnt[2];
						ramAddress[11] <= ycnt[1];
						ramAddress[10] <= ycnt[5];
						ramAddress[ 9] <= ycnt[4];
						ramAddress[ 8] <= ycnt[3];
						ramAddress[ 7] <= ycnt[0];
						ramAddress[ 6] <= ycnt[7];
						ramAddress[ 5] <= ycnt[6];
						ramAddress[ 4] <= ycnt[7];
						ramAddress[ 3] <= ycnt[6];
						ramAddress[2:0] <= 0;
					end else if(vdc_graphic_mode_number == 0) begin
						// GR 0            
						ramAddress[13] <= 1;
						ramAddress[12] <= ycnt[2];
						ramAddress[11] <= ycnt[1];
						ramAddress[10] <= ycnt[5];
						ramAddress[ 9] <= ycnt[4];
						ramAddress[ 8] <= ycnt[3];
						ramAddress[ 7] <= ycnt[7];
						ramAddress[ 6] <= ycnt[6];
						ramAddress[ 5] <= ycnt[7];
						ramAddress[ 4] <= ycnt[6];
						ramAddress[3:0] <= 0;
					end
				end
				else begin
					// TEXT 80 and TEXT 40      
					ramAddress[13] <= 1;
					ramAddress[12] <= 1;
					ramAddress[11] <= 1;         
					ramAddress[10] <= ycnt[5];
					ramAddress[ 9] <= ycnt[4];
					ramAddress[ 8] <= ycnt[3];
					ramAddress[ 7] <= ycnt[7];
					ramAddress[ 6] <= ycnt[6];
					ramAddress[ 5] <= ycnt[7];
					ramAddress[ 4] <= ycnt[6];
					ramAddress[3:0] <= 0;
				end
			end	
			else begin
				ramAddress <= ramAddress + 1;  
			end 			
		end

		// T=7 move saved latch to the pixel register 
		if(vdc_graphic_mode_enabled) begin
			// gr modes
			if(vdc_graphic_mode_number == 5) begin
				if(xcnt[2:0] == 7) begin
					char <= ramData;             
				end
			end else if(vdc_graphic_mode_number == 4) begin
				// GR 4
				if(xcnt[3:0] == 7) begin
					ramDataD <= ramData;             
				end   
				else if(xcnt[3:0] == 15) begin
					char <= ramDataD;
					fgbg <= ramData;             
				end   
			end else if(vdc_graphic_mode_number == 3 || vdc_graphic_mode_number == 0) begin
				// GR 3
				if(xcnt[2:0] == 7) begin
					char <= ramData;             
				end
			end else if(vdc_graphic_mode_number == 2) begin
				if(xcnt[3:0] == 15) begin
					char <= ramData;             
				end
			end else if(vdc_graphic_mode_number == 1) begin
				if(xcnt[4:0] == 15) begin
					ramDataD <= ramData;             
				end   
				else if(xcnt[4:0] == 31) begin
					char <= ramDataD;
					fgbg <= ramData;             
				end   
			end            
		end
		else if(vdc_text80_enabled) begin
			// TEXT 80
			if(xcnt[2:0] == 7) begin
				char <= charsetQ;
			end   
		end
		else begin
			// TEXT 40
			if(xcnt[3:0] == 7) begin
				ramDataD <= charsetQ;
			end   
			else if(xcnt[3:0] == 15) begin
				char <= ramDataD;
				fgbg <= ramData;          
			end   
		end   
	end
end 


assign r = 
	pixel == 4'h0 ? { col0[11:8], 2'b00 } : 
	pixel == 4'h1 ? { col1[11:8], 2'b00 } : 
	pixel == 4'h2 ? { col2[11:8], 2'b00 } : 
	pixel == 4'h3 ? { col3[11:8], 2'b00 } : 
	pixel == 4'h4 ? { col4[11:8], 2'b00 } : 
	pixel == 4'h5 ? { col5[11:8], 2'b00 } : 
	pixel == 4'h6 ? { col6[11:8], 2'b00 } : 
	pixel == 4'h7 ? { col7[11:8], 2'b00 } : 
	pixel == 4'h8 ? { col8[11:8], 2'b00 } : 
	pixel == 4'h9 ? { col9[11:8], 2'b00 } : 
	pixel == 4'ha ? { cola[11:8], 2'b00 } : 
	pixel == 4'hb ? { colb[11:8], 2'b00 } : 
	pixel == 4'hc ? { colc[11:8], 2'b00 } : 
	pixel == 4'hd ? { cold[11:8], 2'b00 } : 
	pixel == 4'he ? { cole[11:8], 2'b00 } : 
                   { colf[11:8], 2'b00 } ;

assign g = 
	pixel == 4'h0 ? { col0[7:4], 2'b00 } : 
	pixel == 4'h1 ? { col1[7:4], 2'b00 } : 
	pixel == 4'h2 ? { col2[7:4], 2'b00 } : 
	pixel == 4'h3 ? { col3[7:4], 2'b00 } : 
	pixel == 4'h4 ? { col4[7:4], 2'b00 } : 
	pixel == 4'h5 ? { col5[7:4], 2'b00 } : 
	pixel == 4'h6 ? { col6[7:4], 2'b00 } : 
	pixel == 4'h7 ? { col7[7:4], 2'b00 } : 
	pixel == 4'h8 ? { col8[7:4], 2'b00 } : 
	pixel == 4'h9 ? { col9[7:4], 2'b00 } : 
	pixel == 4'ha ? { cola[7:4], 2'b00 } : 
	pixel == 4'hb ? { colb[7:4], 2'b00 } : 
	pixel == 4'hc ? { colc[7:4], 2'b00 } : 
	pixel == 4'hd ? { cold[7:4], 2'b00 } : 
	pixel == 4'he ? { cole[7:4], 2'b00 } : 
						 { colf[7:4], 2'b00 } ;
					 									 
assign b = 
	pixel == 4'h0 ? { col0[3:0], 2'b00 } : 
	pixel == 4'h1 ? { col1[3:0], 2'b00 } : 
	pixel == 4'h2 ? { col2[3:0], 2'b00 } : 
	pixel == 4'h3 ? { col3[3:0], 2'b00 } : 
	pixel == 4'h4 ? { col4[3:0], 2'b00 } : 
	pixel == 4'h5 ? { col5[3:0], 2'b00 } : 
	pixel == 4'h6 ? { col6[3:0], 2'b00 } : 
	pixel == 4'h7 ? { col7[3:0], 2'b00 } : 
	pixel == 4'h8 ? { col8[3:0], 2'b00 } : 
	pixel == 4'h9 ? { col9[3:0], 2'b00 } : 
	pixel == 4'ha ? { cola[3:0], 2'b00 } : 
	pixel == 4'hb ? { colb[3:0], 2'b00 } : 
	pixel == 4'hc ? { colc[3:0], 2'b00 } : 
	pixel == 4'hd ? { cold[3:0], 2'b00 } : 
	pixel == 4'he ? { cole[3:0], 2'b00 } : 
						 { colf[3:0], 2'b00 } ;

	// ******************************************************************************						 					

	// bank switching
	reg   [3:0] banks[3:0];   // 4 switchable banks (16K each, 0 to F)
	wire  [3:0] bank          = banks[bank_bits];
	wire  [1:0] bank_bits     = A[15:14];  
	wire [13:0] base_addr     = A[13:0];	
	wire        bank_is_ram   = bank == 3; //(bank >= 4 && bank <=7);  // TODO 350/700 ram config
	wire        mapped_io     = bank == 2 && (base_addr >= 14'h2800 && base_addr <= 14'h2FFF);
	
	wire [24:0] videoAddress   = (vdc_page_7 == 1) ? { 7'd0, 4'h7, ramAddress } : { 7'd0, 4'h3, ramAddress };
	wire [24:0] cpuReadAddress = { 7'd0, bank, base_addr };		
	
	assign sdram_addr = (clk_div == 0 || clk_div == 1 || clk_div == 2 || clk_div == 7) ? videoAddress :
						     (clk_div == 3 || clk_div == 4 || clk_div == 5 || clk_div == 6) ? cpuReadAddress : 0 ;

endmodule



/*
TODO
- memory init
- joystick, printer emulation
- decode (make sense out of) vdc_graphic_mode_number bits
- ena signal on the cpu
- scandoubler / vga resolution?
*/

