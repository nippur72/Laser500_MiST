// Video Technology Laser 350/500/700 for the MiST
//
// Antonino Porcino, nino.porcino@gmail.com
//
// Derived from source code by Till Harbaum (c) 2015
//

// TODO fix sdram jitter problem
// TODO joysticks
// TODO true cpu cycle
// TODO laser 350/500/700 conf
// TODO eng/ger/fra keyboard
// TODO eng/ger/fra video rom
// TODO fix GR 1 and GR 2
									  
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
	"T0,Reset"
};

localparam CONF_STR_LEN = $size(CONF_STR)>>3;

wire [7:0] status;       // the status register is controlled by the user_io module

wire st_reset = /*st_poweron  =*/ status[0];
wire st_scalines = status[1];
wire st_xreset    = status[2];

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

user_io #
(
	.STRLEN(CONF_STR_LEN),
	.PS2DIV(100)
)
user_io ( 
	.conf_str   ( CONF_STR   ),

	.SPI_CLK    ( SPI_SCK    ),
	.SPI_SS_IO  ( CONF_DATA0 ),
	.SPI_MISO   ( SPI_DO     ),
	.SPI_MOSI   ( SPI_DI     ),

	.status     ( status     ),
	
	.clk_sys    ( F14M ),
	.clk_sd     ( F14M ),
	 
	// ps2 interface
	.ps2_kbd_clk    ( ps2_kbd_clk    ),
	.ps2_kbd_data   ( ps2_kbd_data   ),
	
	/*
	.ps2_mouse_clk  ( ps2_mouse_clk  ),
	.ps2_mouse_data ( ps2_mouse_data ),
	*/ 
	
	.joystick_0 ( joystick_0 ),
	.joystick_1 ( joystick_1 )
);

/*
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
*/

// the MiST emulates a PS2 keyboard and mouse

/*
// 15kHz ps2 clock from 14Mhz  clock
wire ps2_clock = xclk_div[13];
reg [13:0] xclk_div;
always @(posedge F14M)
        xclk_div <= xclk_div + 14'd1;
*/
		  
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [ 6:0] KD;
wire        reset_key;

keyboard keyboard 
(
	.reset    ( RESET ),
	.clk      ( F14M  ),

	.ps2_clk  ( ps2_kbd_clk  ),
	.ps2_data ( ps2_kbd_data ),
	
	.address  ( cpu_addr  ),
	.KD       ( KD        ),
	.reset_key( reset_key ),
	
	.debug    ( debug     )
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

/*
scandoubler scandoubler (
	.clk_sys( F14M ),

	
	// scanlines (00-none 01-25% 10-50% 11-75%)
	//input      [1:0] scanlines,
	//input            ce_x1,
	//input            ce_x2,
		
	.hs_in ( video_hs ),
	.vs_in ( video_vs ),
	.r_in  ( osd_r_out ),
	.g_in  ( osd_g_out ),
	.b_in  ( osd_b_out ),
	
	.hs_out( scandoubler_hs_out ),
	.vs_out( scandoubler_vs_out ),
	.r_out ( scandoubler_r_out  ),
	.g_out ( scandoubler_r_out  ),
	.b_out ( scandoubler_r_out  )
);
*/
	
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/***************************************** CPU ********************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
	
//
// Z80 CPU
//
	
// CPU control signals
wire        CPUCK;          // CPU Clock not used yet
wire        CPUENA;         // CPU enable
wire        WAIT_n;         // CPU WAIT (not implemented)
wire [15:0] cpu_addr;
wire [7:0]  cpu_din;
wire [7:0]  cpu_dout;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_mreq_n;
wire        cpu_m1_n;
wire        cpu_iorq_n;


// include Z80 CPU
T80se 
#( 
  .Mode(0),     // : integer := 0;	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
  .T2Write(0),  // : integer := 0;	-- 0 => WR_n active in T3, /=0 => WR_n active in T2
  .IOWait(0)    // : integer := 0	-- 0 => Single cycle I/O, 1 => Std I/O cycle
) 
T80se 
(
	.RESET_n  ( ~(RESET | reset_key) ),   // RESET
	.CLK_n    ( ~F14M         ),   // we use system clock (F14M & CPUENA in place of CPUCK); TODO is it negated?
	.CLKEN    ( CPUENA        ),   // CPU enable
	.WAIT_n   ( ~RESET        ),   // WAIT (TODO implement wait states?)
	.INT_n    ( video_vs      ),   // VSYNC interrupt
	.NMI_n    ( 1'b1          ),   // connected to VCC on the Laser 500
	.BUSRQ_n  ( 1'b1          ),   // connected to VCC on the Laser 500
	.MREQ_n   ( cpu_mreq_n    ),   // MEMORY REQUEST, idicates the bus has a valid memory address
	.M1_n     ( 1'b1          ),   // connected to expansion port on the Laser 500
	.IORQ_n   ( cpu_iorq_n    ),   // IO REQUEST 0=read from I/O
	.RD_n     ( cpu_rd_n      ),   // READ       0=cpu reads
	.WR_n     ( cpu_wr_n      ),   // WRITE      0=cpu writes
	.A        ( cpu_addr      ),   // 16 bit address bus
	.DI       ( cpu_din       ),   // 8 bit data bus (input)
	.DO       ( cpu_dout      )    // 8 bit data bus (output)
);


/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/***************************************** VTL CHIP ***************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

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
	.RESET  ( RESET       ),
	.F14M   ( F14M        ),
	.WAIT_n ( WAIT_n      ),   // wait state for the CPU (TODO to be implemented yet)
	
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
		
	.KD           ( KD     ),	
	.BUZZER       ( BUZZER ),
	.CASOUT       ( CASOUT )
);

// TODO add scandoubler
assign VGA_HS = ~(~video_hs | ~video_vs);
assign VGA_VS = 1;


/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/***************************************** CLOCK AND PLL **********************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

// F14M is the main 14MHz clock
// ram_clock is faster clock for the SDRAM chip, 1 complete read/write cycle in two F14M cyles
// pll_locked flags PLL is locked

wire pll_locked;

pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( F14M          ),        // video generator clock frequency 14.77873 MHz
	 .c1     ( ram_clock     ),        // F14M x 4 	 
	 .c2     ( F3M           )         // F14M / 4 	 
);


// holds RESET=1 until 9,000,000 clock cycles so that pll is locked and ROM is downloaded

wire RESET = (cpu_counter != 9000000);
reg [64:0] cpu_counter = 0;
always @(posedge F14M) begin
	if(!pll_locked || reset_pressed) 
		cpu_counter <= 0;			
	else 
		if(cpu_counter != 9000000)
			cpu_counter <= cpu_counter + 1;
end


// detects menu reset button press on the OSD menu
wire reset_pressed = (st_reset == 1 && st_resetD == 0);
reg st_resetD;
always @(posedge F14M) begin
	st_resetD <= st_reset;
end


wire debug;

/*
// debug keyboard on the LED
always @(posedge F14M) begin
	if(!RESET) LED_ON <= debug;
end
*/

/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/***************************************** RAM ********************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

reg LED_ON = 0;
assign LED = ~LED_ON;

	
//
// RAM (SDRAM)
//
						
// SDRAM control signals
wire ram_clock;
assign SDRAM_CKE = pll_locked; // was: 1'b1;
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

// sdram from zx spectrum core	
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


/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/***************************************** AUDIO ******************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

wire BUZZER;
wire CASOUT;
wire audio;

dac #(.C_bits(8)) dac
(
	.clk_i   ( F14M   ),
   .res_n_i ( ~RESET ),	
	.dac_i   ( { BUZZER ^ CASOUT, 7'b0000000 } ),
	.dac_o   ( audio )
);

always @(posedge F14M) begin
	if(RESET) begin
		AUDIO_L <= 0;
		AUDIO_R <= 0;
	end
	else begin
		AUDIO_L <= audio;
		AUDIO_R <= audio;
		LED_ON <= 1;
	end
end

endmodule
