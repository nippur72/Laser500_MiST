// Video Technology Laser 350/500/700 for the MiST
//
// Antonino Porcino, nino.porcino@gmail.com
//
// Derived from source code by Till Harbaum (c) 2015
//
									  
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
	"LASER500;;", // must be UPPERCASE        
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

// 15kHz ps2 clock from 14Mhz  clock
wire ps2_clock = xclk_div[12];
reg [12:0] xclk_div;
always @(posedge F14M)
        xclk_div <= xclk_div + 14'd1;
		  
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [11:0] KA;
wire [ 7:0] KD;

wire kaa;

wire [7:0] keys;
keyboard keyboard (
	.reset    ( !cpuStarted ),
	.clk      ( F14M         ),

	.ps2_clk  ( ps2_kbd_clk  ),
	.ps2_data ( ps2_kbd_data ),
	
	.keys     ( keys         )
);

/*
keyboard keyboard 
(
	.reset    ( cpu_reset    ),
	.clk      ( F14M  ),

	.ps2_clk  ( ps2_kbd_clk  ),
	.ps2_data ( ps2_kbd_data ),
	
	.KD     ( KD         ),
	.KA     ( KA         ),
	.kaa    ( kaa        )
);
*/
		 
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
   .clk   ( F3M       ),
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
wire        WAIT_n;
wire [15:0] cpu_addr;
wire [7:0]  cpu_din;
wire [7:0]  cpu_dout;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_mreq_n;
wire        cpu_m1_n;
wire        cpu_iorq_n;


// include Z80 CPU
T80se T80se (
	.RESET_n  ( cpuStarted /*!cpu_reset*/    ),   // TODO connect to RESET key
	.CLK_n    ( ~F14M          ),   // we use system clock (F14M & CPUENA in place of CPUCK); TODO is it negated?
	.CLKEN    ( CPUENA /*& cpuStarted*/ ),   // CPU enable
	.WAIT_n   ( /*1'b1*/ cpuStarted /*WAIT_n*/        ),   // WAIT 
	.INT_n    ( /*1'b1*/ video_vs      ),   // VSYNC interrupt
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
					
wire       F3M;					
wire       F14M;
wire [5:0] video_r;
wire [5:0] video_g; 
wire [5:0] video_b;
wire       video_hs;
wire       video_vs;

wire [24:0] vdc_sdram_addr; 
wire        vdc_sdram_wr;
wire        vdc_sdram_rd;
wire  [7:0] vdc_sdram_din;
		  
// VTL custom chip
VTL_chip VTL_chip 
(	
	.RESET  ( cpu_reset   ),
	.F14M   ( F14M        ),
	.WAIT_n ( WAIT_n      ),
	
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
	.b      ( video_b     ),
	
	// other inputs
	.blank  ( dio_download ),

	//	SDRAM interface
	.sdram_addr   ( vdc_sdram_addr   ), 
	.sdram_din    ( vdc_sdram_din    ),
	.sdram_rd     ( vdc_sdram_rd     ),
	.sdram_wr     ( vdc_sdram_wr     ),
	.sdram_dout   ( sdram_dout       ), 
	
	// keyboard
	.KA           ( KA ),
	.KD           ( KD )
);

// TODO add scandoubler
assign VGA_HS = ~(~video_hs | ~video_vs);
assign VGA_VS = 1;

// The CPU is kept in reset for further 256 cycles after the PLL is generating stable clocks
// to make sure things like the SDRAM have some time to initialize

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



reg [7:0] cpu_reset_cnt = 8'h00;
wire cpu_reset = (cpu_reset_cnt != 255);
always @(posedge F14M) begin
	if(!pll_locked) 
		cpu_reset_cnt <= 8'd0;			
	else 
		if(cpu_reset_cnt != 255)
			cpu_reset_cnt <= cpu_reset_cnt + 8'd1;
end

reg st_resetD;


reg [64:0] cpu_started_cnt = 0;
wire cpuStarted = (cpu_started_cnt == 9000000);
always @(posedge F14M) begin
	if(!pll_locked || (st_reset == 1 && st_resetD == 0)) 
		cpu_started_cnt <= 0;			
	else 
		if(cpu_started_cnt != 9000000)
			cpu_started_cnt <= cpu_started_cnt + 1;
end

always @(posedge F14M) begin
	st_resetD <= st_reset;

	/*
	if(st_reset == 1 && st_resetD == 0) begin
		cpuStarted <= !cpuStarted;		
	end		
	*/

	/*if(cpuStarted && cpu_addr == 'h66C8)
		LEDStatus <= 0;	*/

	LEDStatus <= ~keys[2];
end

//
// RAM tester
//
reg [63:0] long_counter;
reg LEDStatus = 1;

assign LED = LEDStatus;

/*
always @(posedge F3M) begin
	LEDStatus <= 1;
	if(dio_download == 1 && LEDStatus == 1) LEDStatus <= 0;
end
*/

/*
reg [24:0] test_addr;
reg        test_wr;
reg        test_rd;
wire [7:0] test_dout;
reg  [7:0] test_din;

always @(posedge F3M) begin
	if(cpu_reset) begin
		long_counter <= 0;
	end else begin			
		long_counter <= long_counter + 1;
					
		if(long_counter[23:0] == 0) begin
			LEDStatus <= 1;
			test_rd <= 0;
			test_wr <= 1;
			test_addr <= 'h3800 | ('h7 << 14) ;
			test_din <= 65;
		end 
		if(long_counter[23:0] == 200) begin
			LEDStatus <= 1;
			test_rd <= 0;
			test_wr <= 1;
			test_addr <= 'h3801 | ('h7 << 14) ;
			test_din <= 66;
		end 
		if(long_counter[23:0] == 400) begin
			LEDStatus <= 1;
			test_rd <= 1;
			test_wr <= 0;
			test_addr <= 'h3801 | ('h7 << 14) ;			
		end 
		else if(long_counter[23:0] == 2097152) begin				
			test_rd <= 1;
			test_wr <= 0;
			test_addr <= 0; //'h3800 | ('h7 << 14) ;				
		end 
		else if(long_counter[23:0] == 2097152+4) begin  
			if(test_dout == 'hf3)	LEDStatus <= 0;   // 65
		end
	end
end
*/
	
	
//
// RAM (SDRAM)
//
						
// SDRAM control signals
wire ram_clock;
assign SDRAM_CKE = 1'b1;
assign SDRAM_CLK = ram_clock;


wire [24:0] sdram_addr ;
wire        sdram_wr   ;
wire        sdram_rd   ;
wire [7:0]  sdram_dout ; 
wire [7:0]  sdram_din  ; 


assign sdram_din  = dio_download ? dio_data  : vdc_sdram_din;
assign sdram_addr = dio_download ? dio_addr  : vdc_sdram_addr;
assign sdram_wr   = dio_download ? dio_write : vdc_sdram_wr;
assign sdram_rd   = dio_download ? 1'b1      : vdc_sdram_rd;


/*
assign sdram_din  = dio_download ? dio_data  : cpu_dout;
assign sdram_addr = dio_download ? dio_addr  : { 9'd0, cpu_addr };
assign sdram_wr   = dio_download ? dio_write : ~cpu_wr_n;
assign sdram_rd   = dio_download ? 1'b1      : ~cpu_rd_n;
*/

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
   .clkref         ( F14M                      ),
   .init           ( !pll_locked               ),

   // cpu interface	
   .din            ( sdram_din                 ),
   .addr           ( sdram_addr                ),
   .we             ( sdram_wr                  ),
   .oe         	 ( sdram_rd                  ),
   .dout           ( sdram_dout                )	
);
	
//
// clocks
//

wire pll_locked;

pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( F14M          ),        // video generator clock frequency 14.77873 MHz
	 .c1     ( ram_clock     ),        // F14M x 4 	 
	 .c2     ( F3M           )         // F14M / 4 	 
);

endmodule
