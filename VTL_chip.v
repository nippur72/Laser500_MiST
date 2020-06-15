// Video Technology Laser 500 video chip
// "VTL 0390-00-00 MD52701" ("MD61800" on Laser 700)

module VTL_chip 
(	
	input    F14M,	           // pixel clock 14.77873   (14688000 in laser500emu)
	input    RESET,           // initialize at power up
	input    BLANK,           // blank signal - nothing is done	
		
	// cpu interface
   output           CPUCK,       // CPU clock to CPU (F14M / 4) - (not used on the MiST, we use F14M & CPUENA)
	output reg       CPUENA,      // CPU enabled signal
	output           WAIT_n,      // WAIT (TODO handle wait states)
	input            MREQ_n,      // MEMORY REQUEST (not used--yet) indicates the bus holds a valid memory address
	input            IORQ_n,      // IO REQUEST 0=read from I/O
	input            RD_n,        // READ       0=cpu reads
	input            WR_n,        // WRITE      0=cpu writes
	input     [15:0] A,           // 16 bit address bus
	input      [7:0] DO,          // 8 bit data output from cpu
	output reg [7:0] DI,          // 8 bit data input for cpu
	
	// keyboard 	
	input [ 6:0] KD,  
   input        CASIN,

   input [31:0] joystick_0,
	input [31:0] joystick_1,
	
	// sdram interface
	output reg [24:0] sdram_addr, // sdram address  
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
	output reg CASOUT,   // mapped I/O bit 2  		
	
	input  alt_font,
	output [2:0] cnt,
	
	input          img_mounted, 
   input   [31:0] img_size    
);

reg [7:0] hfp = 10;         // horizontal front porch, unused time before hsync
reg [7:0] hsw = 66;         // hsync width
reg [7:0] hbp = 70;         // horizontal back porch, unused time after hsync


//parameter hfp = 10;         // horizontal front porch, unused time before hsync
//parameter hsw = 66;         // hsync width
//parameter hbp = 70;         // horizontal back porch, unused time after hsync

parameter HEIGHT              = 192;  // height of active area  
parameter TOP_BORDER_WIDTH    =  65;  // top border
parameter BOTTOM_BORDER_WIDTH =  55;  // bottom
parameter V                   = 313;  // number of lines

parameter WIDTH               = 640;  // width of active area  
parameter LEFT_BORDER_WIDTH   =  72;  // left border
parameter RIGHT_BORDER_WIDTH  =  86;  // right border
parameter H                   = 798;  // width of visible area

// F14M / (row_length * 312) = ~49.7 Hz

reg[9:0]   hcnt;          // horizontal pixel counter
reg[9:0]   vcnt;          // vertical pixel counter
wire[12:0] xcnt;          // active area x TODO, replace with hcnt?
wire[12:0] xcnt1;         // active area x TODO, replace with hcnt?
wire[12:0] xcnt2;         // active area x TODO, replace with hcnt?
wire[12:0] xcnt3;         // active area x TODO, replace with hcnt?
wire[9:0]  ycnt;          // active area y

reg[7:0]  char;           // bitmap graphic data to display
reg[7:0]  fgbg;           // foreground-background colors for the graphic to display
reg[7:0]  ramData;        // data read from RAM
reg[7:0]  ramDataD;       // data read from RAM at previous step
reg[13:0] ramAddress;     // address in video RAM to read from

reg[7:0]  ramQ;    // test

reg [3:0] pixel;          // pixel to draw (color index in the palette)

reg [2:0] vdc_graphic_mode_number; // graphic mode number 0..5
reg       vdc_text80_enabled     ; // TEX80 mode, otherwise TEXT40
reg [3:0] vdc_text80_foreground  ; // foreground color for TEXT80 &c.
reg [3:0] vdc_text80_background  ; // background color for TEXT80 &c.
reg [3:0] vdc_border_color       ; // border color
reg       vdc_page_7             ; // 1=video RAM is in page 7 (Laser 500/700), 3 otherwise (Laser 350)

// memory mapped I/O write registers 
reg caps_lock_bit           ; // mapped to bit 6
reg vdc_graphic_mode_enabled; // mapped to bit 3


parameter col0 = 12'h000;  // black 
parameter col1 = 12'h00f;  // blue 
parameter col2 = 12'h080;  // green 
parameter col3 = 12'h08f;  // cyan 
parameter col4 = 12'ha00;  // red 
parameter col5 = 12'hf0f;  // magenta 
parameter col6 = 12'h780;  // yellow 
parameter col7 = 12'h999;  // bright grey 
parameter col8 = 12'h555;  // dark grey 
parameter col9 = 12'h88f;  // bright blue 
parameter cola = 12'h0f0;  // bright green 
parameter colb = 12'h4ff;  // bright cyan 
parameter colc = 12'hf45;  // bright red 
parameter cold = 12'hf9f;  // bright magenta 
parameter cole = 12'hcf0;  // bright yellow 
parameter colf = 12'hfff;  // white 

reg[12:0] charsetAddress;

wire[7:0] charsetQ;
wire[7:0] charsetQ_alt;
wire[7:0] charsetQ_std; 

assign charsetQ = (!alt_font) ? charsetQ_std : charsetQ_alt;

rom_charset rom_charset (
	.address(charsetAddress),
	.clock(F14M),
	.q(charsetQ_std)
);							  						

rom_charset_alternate rom_charset_alternate (
	.address(charsetAddress),
	.clock(F14M),
	.q(charsetQ_alt)
);							  						

wire [3:0] fg;
wire [3:0] bg;

// generate negative hsync and vsync signals
assign hsync = (hcnt < hsw) ? 0 : 1;
assign vsync = (vcnt <   4) ? 0 : 1;

wire non_visible_area = hcnt < hsw+hbp || vcnt < 2 || hcnt >= hsw+hbp+H;
						  
// calculate foreground and background colors						  
assign fg = (vdc_graphic_mode_enabled && (vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 2)) || (!vdc_graphic_mode_enabled && vdc_text80_enabled) ? vdc_text80_foreground : fgbg[7:4];
assign bg = (vdc_graphic_mode_enabled && (vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 2)) || (!vdc_graphic_mode_enabled && vdc_text80_enabled) ? vdc_text80_background : fgbg[3:0];

// calculate x offset (TODO replace with hcnt or VDC_cnt?)
assign xcnt = hcnt - (hsw+hbp+LEFT_BORDER_WIDTH);

assign xcnt1 = xcnt + 8 +8; // text80, gr0, gr2, gr3, gr5             
assign xcnt2 = xcnt + 16+8; // text40 and gr4
assign xcnt3 = xcnt + 24+8; // gr1   

assign ycnt = vcnt - TOP_BORDER_WIDTH;

wire [2:0] VDC_cnt = hcnt[2:0];   // clock divider and bus slot assignment
wire [1:0] CPU_cnt = hcnt[1:0];   // 

assign cnt = VDC_cnt;

assign CPUCK  = VDC_cnt[1];   // derive CPUCK by dividing F14M by 4
// warning: CPUCK not used, F14M is fed into T80

// negated signals (easier to read)
wire MREQ   = ~MREQ_n;
wire WR     = ~WR_n;
wire RD     = ~RD_n;
wire IORQ   = ~IORQ_n;

/*
reg WAIT;
assign WAIT_n = ~WAIT;
*/

reg MREQ_old;
reg skip_beat;

always@(posedge F14M) begin
	if(RESET) begin
		hcnt <= 0;  
		vcnt <= 0;
		banks[0] <= 0;
	end
	else begin		   
		
		// main counters 
		if(hcnt == hsw+hbp+H+hfp-1) begin
			hcnt <= 10'd0;
			if(vcnt == V-1) begin
				vcnt <= 10'd0;				
			end
			else 
				vcnt <= vcnt + 10'd1;				
		end
		else hcnt <= hcnt + 10'd1;

		if(BLANK) begin
			if(non_visible_area) pixel <= 0;   
			else pixel <= vdc_border_color; 
		end
		else begin
			// normal VDC operation
				
			// works with 118 MHz sdram clock
				  if(VDC_cnt == 7) begin sdram_rd <= 1; sdram_addr <= videoAddress;       end 	// VDC ram reading starts; ROM reading ended, data is stored in "char" or "ramDataD"
			else if(VDC_cnt == 0) begin                                                  end 	// VDC ram reading ended; VDC saves data into "ramData"; ROM reading starts
			else if(VDC_cnt == 1) begin                                                  end 	// 
			else if(VDC_cnt == 2) begin                                                  end 	// 
			else if(VDC_cnt == 3) begin sdram_rd <= 0;                                   end 	// ram refresh cycle, apparently needed when ram_clk runs at 118Mhz	 					 	      					
			else if(VDC_cnt == 4) begin sdram_rd <= 1;                                   end 	// 
			else if(VDC_cnt == 5) begin                                                  end 	// 
			else if(VDC_cnt == 6) begin                                                  end 	// 
			
			// === CPU cyles ===
			// CPU_cnt == 3    nothing
			// CPU_cnt == 0    CPU does 1 cycle
			// CPU_cnt == 1    RAM is read or written according to MREQ, RD and WR
			// CPU_cnt == 2    CPU samples bus / turns off write
										
			// detect MREQ state changes
			if(CPU_cnt == 3) begin
				MREQ_old <= MREQ;
				if(MREQ_old == 0 && MREQ == 1) begin
					skip_beat <= 1;					
				end
				else skip_beat <= 0;
			end
			
			// CPU does one cycle
			if(CPU_cnt == 0) begin			
				CPUENA <= !skip_beat;			
			end			
			else
				CPUENA <= 0;
			
			// RAM is read or written	
			if(CPU_cnt == 1) begin
				sdram_rd <= 1; 
				sdram_addr <= cpuReadAddress;
				if(MREQ && WR && !skip_beat)	begin				
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
			end

			// CPU samples bus, written is stopped	
			if(CPU_cnt == 2) begin
				if(MREQ && !skip_beat) begin
					if(RD) begin					
						if(mapped_io) begin											
							DI[7] <= CASIN;					
							DI[6:0] <= KD;						      
						end				
						else 
							DI <= sdram_dout; // read from RAM/ROM						
					end			
					if(WR)	begin
						// terminate write
						sdram_wr <= 0;  
					end					
				end
			end
					
			// Z80 IO 
			if(CPU_cnt == 2 && IORQ && !skip_beat) begin
				if(RD) begin				
					if(A[7:0] == 'h2b) begin
						// joystick0 8 directions: ---FEWSN					
						// Mist: 0-right, 1-left, 2-down, 3-up, 4-A, 5-B, 6-SELECT, 7-START, 8-X, 9-Y, 10-L, 11-R, 12-L2, 13-R2, 15-L3, 15-R
						DI[7] <= 1;					
						DI[6] <= 1;					
						DI[5] <= 1;					
						DI[4] <= ~joystick_0[4];					
						DI[3] <= ~joystick_0[0];
						DI[2] <= ~joystick_0[1];
						DI[1] <= ~joystick_0[2];
						DI[0] <= ~joystick_0[3];
					end
					else if(A[7:0] == 'h27) begin
						// joystick0 fire buttons      				
						DI[7] <= 1;					
						DI[6] <= 1;					
						DI[5] <= 1;					
						DI[4] <= ~joystick_0[5];					
						DI[3] <= 1;
						DI[2] <= 1;
						DI[1] <= 1;
						DI[0] <= 1;
					end
					else if(A[7:0] == 'h2e) begin
						// joystick1 8 directions
						DI[7] <= 1;					
						DI[6] <= 1;					
						DI[5] <= 1;					
						DI[4] <= ~joystick_1[4];					
						DI[3] <= ~joystick_1[0];
						DI[2] <= ~joystick_1[1];
						DI[1] <= ~joystick_1[2];
						DI[0] <= ~joystick_1[3];
					end
					else if(A[7:0] == 'h2d) begin
						// joystick1 fire buttons      				
						DI[7] <= 1;					
						DI[6] <= 1;					
						DI[5] <= 1;					
						DI[4] <= ~joystick_1[5];					
						DI[3] <= 1;
						DI[2] <= 1;
						DI[1] <= 1;
						DI[0] <= 1;
					end
					/*
					else if(A[7:0] == 'ha0) DI <= img_size[ 7: 0];						
					else if(A[7:0] == 'ha1) DI <= img_size[15: 8];						
					else if(A[7:0] == 'ha2) DI <= img_size[23:16];						
					else if(A[7:0] == 'ha3) DI <= img_size[31:24];						
					else if(A[7:0] == 'ha4) DI <= { 7'b0, img_mounted };						
					*/
					else if(A[7:0] == 'ha0) DI <= hsw;						
					else if(A[7:0] == 'ha1) DI <= hbp;						
					else if(A[7:0] == 'ha2) DI <= hfp;						
					else
						DI <= { DI[7:1], 1'b1 }; // value returned from unused ports
						
					//case 0x00: return printerReady;                  				
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
					   'ha0: hsw <= DO;						
					   'ha1: hbp <= DO;						
					   'ha2: hfp <= DO;						
						
							//if(emulate_fdc) floppy_write_port(port & 0xFF, value); 
							//return;     				
					endcase				
				end
			end		
								
			// draw pixel at hcnt,vcnt, graphic data contained in "char"
			if(hcnt < hsw+hbp || vcnt < 2 || hcnt >= hsw+hbp+H) 
				pixel <= 0;   // blanking zone 
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
			if(xcnt[2:0] == 1) begin
				ramData <= sdram_dout;			
				charsetAddress <= (sdram_dout << 3) | ycnt[2:0]; // TODO eng/ger/fra				
			end		
			
			// calculate RAM address 					
			if(vdc_graphic_mode_enabled) begin					
				if(vdc_graphic_mode_number == 5 || vdc_graphic_mode_number == 4 || vdc_graphic_mode_number == 3) begin
					// GR 5, GR 4, GR 3                                                               
					ramAddress[13]  = ycnt[2];
					ramAddress[12]  = ycnt[1];
					ramAddress[11]  = ycnt[0];
					ramAddress[10]  = ycnt[5];
					ramAddress[ 9]  = ycnt[4];
					ramAddress[ 8]  = ycnt[3];
					ramAddress[ 7]  = ycnt[7];
					ramAddress[ 6]  = ycnt[6];
					ramAddress[ 5]  = ycnt[7];
					ramAddress[ 4]  = ycnt[6];
					ramAddress[3:0] = 0;
					
						  if(vdc_graphic_mode_number == 5) ramAddress = ramAddress + (xcnt1 >> 3);   
					else if(vdc_graphic_mode_number == 4) ramAddress = ramAddress + (xcnt2 >> 3);   
					else if(vdc_graphic_mode_number == 3) ramAddress = ramAddress + (xcnt1 >> 3);   

				end else if(vdc_graphic_mode_number == 2 || vdc_graphic_mode_number == 1) begin
					// GR 2 and GR 1           
					ramAddress[13]  = 1;
					ramAddress[12]  = ycnt[2];
					ramAddress[11]  = ycnt[1];
					ramAddress[10]  = ycnt[5];
					ramAddress[ 9]  = ycnt[4];
					ramAddress[ 8]  = ycnt[3];
					ramAddress[ 7]  = ycnt[0];
					ramAddress[ 6]  = ycnt[7];
					ramAddress[ 5]  = ycnt[6];
					ramAddress[ 4]  = ycnt[7];
					ramAddress[ 3]  = ycnt[6];
					ramAddress[2:0] = 0;
					
						  if(vdc_graphic_mode_number == 2) ramAddress = ramAddress + (xcnt1 >> 4);   
					else if(vdc_graphic_mode_number == 1) ramAddress = ramAddress + (xcnt3 >> 4);   

				end else if(vdc_graphic_mode_number == 0) begin
					// GR 0            
					ramAddress[13]  = 1;
					ramAddress[12]  = ycnt[2];
					ramAddress[11]  = ycnt[1];
					ramAddress[10]  = ycnt[5];
					ramAddress[ 9]  = ycnt[4];
					ramAddress[ 8]  = ycnt[3];
					ramAddress[ 7]  = ycnt[7];
					ramAddress[ 6]  = ycnt[6];
					ramAddress[ 5]  = ycnt[7];
					ramAddress[ 4]  = ycnt[6];
					ramAddress[3:0] = 0;
					
					ramAddress = ramAddress + (xcnt1 >> 3); 
				end
			end
			else begin
				// TEXT 80 and TEXT 40      
				ramAddress[13]  = 1;
				ramAddress[12]  = 1;
				ramAddress[11]  = 1;         
				ramAddress[10]  = ycnt[5];
				ramAddress[ 9]  = ycnt[4];
				ramAddress[ 8]  = ycnt[3];
				ramAddress[ 7]  = ycnt[7];
				ramAddress[ 6]  = ycnt[6];
				ramAddress[ 5]  = ycnt[7];
				ramAddress[ 4]  = ycnt[6];
				ramAddress[3:0] = 0;
				
					  if(vdc_text80_enabled) ramAddress = ramAddress + (xcnt1 >> 3);   
				else                        ramAddress = ramAddress + (xcnt2 >> 3);
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
	wire        bank_is_ram   = bank >= 4 && bank <=7;  // TODO 350/700 ram config
	wire        mapped_io     = bank == 2 && (base_addr >= 14'h2800 && base_addr <= 14'h2FFF);
	
	wire [24:0] videoAddress   = (vdc_page_7 == 1) ? { 7'd0, 4'h7, ramAddress } : { 7'd0, 4'h3, ramAddress };
	wire [24:0] cpuReadAddress = { 7'd0, bank, base_addr };		
		
endmodule


