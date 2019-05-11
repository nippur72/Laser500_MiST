// Video Technology Laser 350/500/700 for the MiST
//
// Antonino Porcino, nino.porcino@gmail.com
//
// Derived from source code by Till Harbaum (c) 2015
//
/*									  
module laser500_mist 
( 
   input [1:0] 	CLOCK_27,      // 27 MHz board clock 
	
	// SDRAM interface
	inout  [15:0] 	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output        	SDRAM_nWE, 		// SDRAM Write Enable
	output       	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output        	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output        	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output 			SDRAM_CLK, 		// SDRAM Clock
	output        	SDRAM_CKE, 		// SDRAM Clock Enable
  
   // SPI (serial-parallel) interface to ARM io controller
   output      	SPI_DO,
	input       	SPI_DI,
   input       	SPI_SCK,
   input 			SPI_SS2,
   input 			SPI_SS3,
   input 			SPI_SS4,
	input       	CONF_DATA0, 

	// VGA interface
   output 			VGA_HS,
   output 	 		VGA_VS,
   output [5:0] 	VGA_R,
   output [5:0] 	VGA_G,
   output [5:0] 	VGA_B,
	
	// other
	output         LED,
	input          UART_RX,
	output         AUDIO_L,
	output         AUDIO_R
);

// menu configuration string passed to user_io
localparam CONF_STR = {
	"Laser500;;",
	"O1,Scanlines,On,Off;",
	"T2,Reset"
};

localparam CONF_STR_LEN = $size(CONF_STR)>>3;

wire [7:0] status;       // the status register is controlled by the on screen display (OSD)

wire st_poweron  = status[0];
wire st_scalines = status[1];
wire st_reset    = status[2];

// on screen display

osd osd (
   .clk_sys    ( F14M         ),

   // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS3      ),

   .R_in       ( video_r      ),
   .G_in       ( video_g      ),
   .B_in       ( video_b      ),
   .HSync      ( video_hs     ),
   .VSync      ( video_vs     ),

   .R_out      ( VGA_R        ),
   .G_out      ( VGA_G        ),
   .B_out      ( VGA_B        )   
);
       
wire [7:0] joystick_0;
wire [7:0] joystick_1;

// include user_io module for arm controller communication
user_io #(.STRLEN(CONF_STR_LEN)) user_io ( 
	.conf_str   ( CONF_STR   ),

	.SPI_CLK    ( SPI_SCK    ),
	.SPI_SS_IO  ( CONF_DATA0 ),
	.SPI_MISO   ( SPI_DO     ),
	.SPI_MOSI   ( SPI_DI     ),

	.status     ( status     ),
	 
	// ps2 interface
	.ps2_clk        ( ps2_clock      ),
	.ps2_kbd_clk    ( ps2_kbd_clk    ),
	.ps2_kbd_data   ( ps2_kbd_data   ),
	.ps2_mouse_clk  ( ps2_mouse_clk  ),
	.ps2_mouse_data ( ps2_mouse_data ),
	 
	.joystick_0 ( joystick_0 ),
	.joystick_1 ( joystick_1 )
);

// the MiST emulates a PS2 keyboard and mouse
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [13:0] KA;
wire [ 7:0] KD;

keyboard keyboard 
(
	.reset    ( cpu_reset    ),
	.clk      ( F14M         ),

	.ps2_clk  ( ps2_kbd_clk  ),
	.ps2_data ( ps2_kbd_data ),
	
	.KD     ( KD         ),
	.KA     ( KA         )
);
		 
//
// data_io
//

wire        dio_download;
wire [24:0] dio_addr;
wire [7:0]  dio_data;
wire        dio_write;

// include ROM download helper
data_io data_io (
	// io controller spi interface
   .sck	( SPI_SCK ),
   .ss	( SPI_SS2 ),
   .sdi	( SPI_DI  ),

	.downloading ( dio_download ),  // signal indicating an active rom download
	         
   // external ram interface
   .clk   ( F14M      ),
   .wr    ( dio_write ),
   .addr  ( dio_addr  ),
   .data  ( dio_data  )
);
		 
//
// Z80 CPU
//
	
// CPU control signals
wire        CPUCK;
wire        CPUENA;
wire [15:0] cpu_addr;
wire [7:0]  cpu_din;
wire [7:0]  cpu_dout;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_mreq_n;
wire        cpu_m1_n;
wire        cpu_iorq_n;
wire        cpu_wait_n;

// include Z80 CPU
T80se T80se (
	.RESET_n  ( !cpu_reset    ),   // TODO connect to RESET key
	.CLK_n    ( F14M          ),   // we use system clock (F14M & CPUENA in place of CPUCK); TODO is it negated?
	.CLKEN    ( CPUENA        ),   // CPU enable
	.WAIT_n   ( cpu_wait_n    ),   // TODO connect to wait line
	.INT_n    ( vsync         ),   // VSYNC interrupt
	.NMI_n    ( 1'b1          ),   // connected to VCC
	.BUSRQ_n  ( 1'b1          ),   // connected to VCC
	.MREQ_n   ( cpu_mreq_n    ),   // MEMORY REQUEST, idicates the bus has a valid memory address
	.M1_n     ( cpu_m1_n      ),   // M1==0 && MREQ==0 cpu is fetching, M1==0 && IORQ==0 ack interrupt
	.IORQ_n   ( cpu_iorq_n    ),   // IO REQUEST 0=read from I/O
	.RD_n     ( cpu_rd_n      ),   // READ       0=cpu reads
	.WR_n     ( cpu_wr_n      ),   // WRITE      0=cpu writes
	.A        ( cpu_addr      ),   // 16 bit address bus
	.DI       ( cpu_din       ),   // 8 bit data bus (input)
	.DO       ( cpu_dout      )    // 8 bit data bus (output)
);

//
// VTL CHIP GA1
//
								  
wire       F14M;
wire [5:0] video_r;
wire [5:0] video_g; 
wire [5:0] video_b;
wire       video_hs;
wire       video_vs;
		  
// VTL custom chip
VTL_chip VTL_chip 
(	
	.RESET  ( cpu_reset   ),
	.F14M   ( F14M        ),
	
	// cpu
   .CPUCK    ( CPUCK         ),
	.CPUENA   ( CPUENA        ),
	.MREQ_n   ( cpu_mreq_n    ),	
	.IORQ_n   ( cpu_iorq_n    ),
	.RD_n     ( cpu_rd_n      ), 
	.WR_n     ( cpu_wr_n      ),
	.A        ( cpu_addr      ),
	.DI       ( cpu_din       ),
	.DO       ( cpu_dout      ),
		
	// video
	.hsync  ( video_hs    ),
	.vsync  ( video_vs    ),
	.r      ( video_r     ),
	.g      ( video_g     ),
	.b      ( video_b     )
);

// TODO add scandoubler
assign VGA_HS = ~(~video_hs | ~video_vs);
assign VGA_VS = 1;

// The CPU is kept in reset for further 256 cycles after the PLL is generating stable clocks
// to make sure things like the SDRAM have some time to initialize
*/

/*
reg [9:0] cpu_reset_cnt = 0;
wire cpu_reset = (cpu_reset_cnt != 1023);
always @(posedge F14M) begin
	if(!pll_locked || st_poweron || st_reset || dio_download)
		cpu_reset_cnt <= 0;
	else 
		if(cpu_reset_cnt != 1023)
			cpu_reset_cnt <= cpu_reset_cnt + 1;
end
*/

/*
reg [7:0] cpu_reset_cnt = 8'h00;
wire cpu_reset = (cpu_reset_cnt != 255);
always @(posedge cpu_clock) begin
	if(!pll_locked)
		cpu_reset_cnt <= 8'd0;
	else 
		if(cpu_reset_cnt != 255)
			cpu_reset_cnt <= cpu_reset_cnt + 8'd1;
end

reg [22:0] sdram_addr;
reg sdram_wr;
reg sdram_rd;
wire [7:0] sdram_dout;
reg [7:0] sdram_din;

//
// RAM tester
//
reg [63:0] long_counter;
reg LEDStatus;

assign LED = LEDStatus;

always @(posedge ram_clock) begin
	if(cpu_reset) begin
		long_counter <= 0;
	end else begin			
		long_counter <= long_counter + 1;
					
		if(long_counter[23:0] == 0) begin
			LEDStatus <= 1;
			sdram_rd <= 0;
			sdram_wr <= 1;
			sdram_addr <= 'h3800 | ('h7 << 14) ;
			sdram_din <= 65;
		end 
		if(long_counter[23:0] == 200) begin
			LEDStatus <= 1;
			sdram_rd <= 0;
			sdram_wr <= 1;
			sdram_addr <= 'h3801 | ('h7 << 14) ;
			sdram_din <= 66;
		end 
		if(long_counter[23:0] == 400) begin
			LEDStatus <= 1;
			sdram_rd <= 1;
			sdram_wr <= 0;
			sdram_addr <= 'h3801 | ('h7 << 14) ;			
		end 
		else if(long_counter[23:0] == 2097152) begin				
			sdram_rd <= 1;
			sdram_wr <= 0;
			sdram_addr <= 'h3800 | ('h7 << 14) ;				
		end 
		else if(long_counter[23:0] == 2097152+7) begin
			if(sdram_dout == 65)	LEDStatus <= 0;
		end
	end
end
*/
	
/*	
//
// RAM (SDRAM)
//
						
// SDRAM control signals
wire ram_clock;
assign SDRAM_CKE = 1'b1;
assign SDRAM_CLK = ram_clock;

// derive 4Mhz cpu clock from 32Mhz sdram clock
assign cpu_clock = clk_div[2];
reg [2:0] clk_div;
always @(posedge ram_clock)
	clk_div <= clk_div + 3'd1;
*/

/*
// during ROM download data_io writes the ram. Otherwise the CPU
wire [7:0]  sdram_din  = dio_download ? dio_data  : cpu_dout;
wire [24:0] sdram_addr = dio_download ? dio_addr  : paged_address;
wire        sdram_wr   = dio_download ? dio_write : bank_is_ram;    // TODO ROM write only management
wire        sdram_cs   = dio_download ? 1'b1 : !cpu_rd_n;
wire [7:0]  sdram_dout;
*/

/*
sdram sdram (
	// interface to the MT48LC16M16 chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),

   // system interface
   .clk            ( ram_clock                 ),
   .clkref         ( cpu_clock                 ),
   .init           ( !pll_locked               ),

   // cpu interface
   .din            ( sdram_din                 ),
   .addr           ( sdram_addr                ),
   .we             ( sdram_wr                  ),
   .oe         	 ( sdram_rd                  ),
   .dout           ( sdram_dout                )
);
*/
	
//
// clocks
//

/*
wire pll_locked;

pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( F14M          ),        // video generator clock frequency 14.77873 MHz
	 .c1     ( ram_clock     )         // F14M x 4 	 
);

endmodule
*/
/*
endmodule
*/













































// A simple system-on-a-chip (SoC) for the MiST
// (c) 2015 Till Harbaum
									  
module laser500_mist (
   input [1:0] 	CLOCK_27,
	
	// SDRAM interface
	inout [15:0]  	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output        	SDRAM_nWE, 		// SDRAM Write Enable
	output       	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output        	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output        	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output 			SDRAM_CLK, 		// SDRAM Clock
	output        	SDRAM_CKE, 		// SDRAM Clock Enable

	
	// VGA interface
   output 			VGA_HS,
   output 	 		VGA_VS,
   output [5:0] 	VGA_R,
   output [5:0] 	VGA_G,
   output [5:0] 	VGA_B,
	
	output LED
);

wire pixel_clock;

/*
// include VGA controller
vga vga (
	.pclk     ( pixel_clock      ),	 

	.hs    (VGA_HS),
	.vs    (VGA_VS),
	.r     (VGA_R),
	.g     (VGA_G),
	.b     (VGA_B)
);
*/

// ****************************

// The CPU is kept in reset for further 256 cyckes after the PLL is
// generating stable clocks to make sure things like the SDRAM have
// some time to initialize
reg [7:0] cpu_reset_cnt = 8'h00;
wire cpu_reset = (cpu_reset_cnt != 255);
always @(posedge cpu_clock) begin
	if(!pll_locked)
		cpu_reset_cnt <= 8'd0;
	else 
		if(cpu_reset_cnt != 255)
			cpu_reset_cnt <= cpu_reset_cnt + 8'd1;
end
			
// SDRAM control signals
wire ram_clock;
assign SDRAM_CKE = 1'b1;
assign SDRAM_CLK = ram_clock;

sdram sdram (
	// interface to the MT48LC16M16 chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),

   // system interface
   .clk            ( ram_clock                 ),
   .clkref         ( cpu_clock                 ),
   .init           ( !pll_locked               ),

   // cpu/chipset interface
   .din            ( sdram_din                 ),
   .addr           ( sdram_addr                ),
   .we             ( sdram_wr                  ),
   .oe         	 ( sdram_rd                  ),
   .dout           ( sdram_dout                )
);
	
reg [22:0] sdram_addr;
reg sdram_wr;
reg sdram_rd;
wire [7:0] sdram_dout;
reg [7:0] sdram_din;
	
//
// RAM tester
//
reg [63:0] long_counter;
reg LEDStatus;
assign LED = LEDStatus;

always @(posedge ram_clock) begin
	if(cpu_reset) begin
		long_counter <= 0;
	end else begin			
		long_counter <= long_counter + 1;
					
		if(long_counter[23:0] == 0) begin
			LEDStatus <= 1;
			sdram_rd <= 0;
			sdram_wr <= 1;
			sdram_addr <= 'h3800 | ('h7 << 14) ;
			sdram_din <= 65;
		end 
		if(long_counter[23:0] == 200) begin
			LEDStatus <= 1;
			sdram_rd <= 0;
			sdram_wr <= 1;
			sdram_addr <= 'h3801 | ('h7 << 14) ;
			sdram_din <= 66;
		end 
		if(long_counter[23:0] == 400) begin
			LEDStatus <= 1;
			sdram_rd <= 1;
			sdram_wr <= 0;
			sdram_addr <= 'h3801 | ('h7 << 14) ;			
		end 
		else if(long_counter[23:0] == 2097152) begin				
			sdram_rd <= 1;
			sdram_wr <= 0;
			sdram_addr <= 'h3800 | ('h7 << 14) ;				
		end 
		else if(long_counter[23:0] == 2097152+7) begin
			if(sdram_dout == 65)	LEDStatus <= 0;
		end
	end
end


// derive 4Mhz cpu clock from 32Mhz sdram clock
assign cpu_clock = clk_div[2];
reg [2:0] clk_div;
always @(posedge ram_clock)
	clk_div <= clk_div + 3'd1;
	
wire pll_locked;
pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( pixel_clock   ),        // 25.175 MHz
	 .c1     ( ram_clock     ),        // 32 MHz
);

endmodule
