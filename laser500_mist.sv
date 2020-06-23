// Video Technology Laser 350/500/700 for the MiST
//
// Antonino Porcino, nino.porcino@gmail.com
//
// Derived from source code by Till Harbaum (c) 2015
//

// TODO implement or not delay line on the HYSNC?
// TODO fix sdram jitter problem
// TODO true VGA resolution with downscaler (VESA 720x400@85 Hz pixel clock 35.5 MHz) http://tinyvga.com/vga-timing/720x400@85Hz
// TODO laser 350/500/700 conf
// TODO tape sounds ON/OFF
// TODO disk emulation
// TODO eng/ger/fra keyboard
// TODO eng/ger/fra video rom
// TODO eng/ita keyboard
// TODO tap/wav player?
// TODO add LP filter to tape out?
// TODO bandpass tape in
// TODO debug LED on port 0xFF
								   
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


/******************************************************************************************/
/******************************************************************************************/
/***************************************** @osd *******************************************/
/******************************************************************************************/
/******************************************************************************************/

mist_video 
#
(
	.SYNC_AND(1)
) 
mist_video
(
	.clk_sys(F14Mx2),           // twice the F14M clock for the scandoubler

	// OSD SPI interface
   .SPI_DI(SPI_DI),
   .SPI_SCK(SPI_SCK),
   .SPI_SS3(SPI_SS3),

	.scanlines(2'b00),           // scanlines (00-none 01-25% 10-50% 11-75%)	
	.ce_divider(1),              // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2

	.scandoubler_disable(scandoubler_disable),  // 0 = HVSync 31KHz, 1 = CSync 15KHz	
	.no_csync(no_csync),                        // 1 = disable csync without scandoubler	
	.ypbpr(ypbpr),                              // 1 = YPbPr output on composite sync
	
	.rotate(2'b00),              // Rotate OSD [0] - rotate [1] - left or right	
	.blend(0),                   // composite-like blending

	// video input
	.R(video_r),
	.G(video_g),
	.B(video_b),
	.HSync(video_hs),
	.VSync(video_vs),
	
	// MiST video output signals
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS)
);


/******************************************************************************************/
/******************************************************************************************/
/***************************************** @user_io ***************************************/
/******************************************************************************************/
/******************************************************************************************/

// menu configuration string passed to user_io
localparam CONF_STR = {
	"LASER500;PRG;", // must be UPPERCASE        
	"S,DSK,Mount disk;",
	"O2,Custom charset ROM,Off,On;",
	"T3,Reset"
};

localparam CONF_STR_LEN = $size(CONF_STR)>>3;

wire [7:0] status;       
wire [1:0] buttons;
wire [1:0] switches;

wire st_power_on = status[0];
wire st_scalines = status[1];
wire st_alt_font = status[2];
wire st_reset    = status[3] | buttons[1];
       
wire [31:0] joystick_0;
wire [31:0] joystick_1;

wire scandoubler_disable;
wire ypbpr;
wire no_csync;


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
	.buttons    ( buttons    ),
	.switches   ( switches   ),
		
	.scandoubler_disable ( scandoubler_disable ),
	.ypbpr               ( ypbpr               ),
	.no_csync            ( no_csync            ),	
	
	.clk_sys    ( F14M ),
	.clk_sd     ( F14M ),
	 
	// ps2 interface
	.ps2_kbd_clk    ( ps2_kbd_clk    ),
	.ps2_kbd_data   ( ps2_kbd_data   ),
		
	.joystick_0 ( joystick_0 ),
	.joystick_1 ( joystick_1 ),
	
	.img_mounted( img_mounted ),
	.img_size   ( img_size    ) 
);

wire          img_mounted; //rising edge if a new image is mounted
wire   [31:0] img_size;    // size of image in bytes



/******************************************************************************************/
/******************************************************************************************/
/***************************************** @keyboard **************************************/
/******************************************************************************************/
/******************************************************************************************/
		 
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [ 6:0] KD;
wire        reset_key;

keyboard keyboard 
(
	.reset    ( !pll_locked ),
	.clk      ( F14M  ),

	.ps2_clk  ( ps2_kbd_clk  ),
	.ps2_data ( ps2_kbd_data ),
	
	.address  ( cpu_addr  ),
	.KD       ( KD        ),
	.reset_key( reset_key )	
);


		 
/******************************************************************************************/
/******************************************************************************************/
/***************************************** @downloader ************************************/
/******************************************************************************************/
/******************************************************************************************/

wire        is_downloading;
wire [24:0] download_addr;
wire [7:0]  download_data;
wire        download_wr;
wire        boot_completed;

// ROM download helper
downloader 
#
(
	.ROM_START_ADDR(25'h0),               // start of ROM in SDRAM
	.PRG_START_ADDR(25'h10000 + 25'h995), // start of PRG in SDRAM (0x8995)
	.PTR_END_BASE('h8995),                // base value to sum to END pointer (0x8995)
	.PTR_PROGND(25'h10000 + 25'h3E9)      // SDRAM address of END pointer (0x83e9)
)
downloader (
	
	// new SPI interface
   .SPI_DO ( SPI_DO  ),
	.SPI_DI ( SPI_DI  ),
   .SPI_SCK( SPI_SCK ),
   .SPI_SS2( SPI_SS2 ),
   .SPI_SS3( SPI_SS3 ),
   .SPI_SS4( SPI_SS4 ),
	
	// signal indicating an active rom download
	.downloading ( is_downloading  ),
   .ROM_done    ( boot_completed  ),	
	         
   // external ram interface
   .clk    ( F3M           ),
	.clk_ena( 1             ),
   .wr     ( download_wr   ),
   .addr   ( download_addr ),
   .data   ( download_data )
);


wire [2:0] hcnt;

/******************************************************************************************/
/******************************************************************************************/
/***************************************** @eraser ****************************************/
/******************************************************************************************/
/******************************************************************************************/

wire eraser_busy;
wire eraser_wr;
wire [24:0] eraser_addr;
wire [7:0]  eraser_data;

eraser 
#(
	// erases from page 3 to page 7 (all 64K RAM)
	.START_RAM( { 7'd0, 4'h3, 14'b0 }),  
	.END_RAM  ( { 7'd0, 4'h8, 14'b0 })  
)
eraser
(
	.clk      ( F3M         ),
	.ena      ( 1           ),
	.trigger  ( st_reset    ),	
	.erasing  ( eraser_busy ),
	.wr       ( eraser_wr   ),
	.addr     ( eraser_addr ),
	.data     ( eraser_data )
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
/***************************************** @t80 *******************************************/
/******************************************************************************************/
/******************************************************************************************/
	
//
// Z80 CPU
//
	
// CPU control signals
wire        CPUCK;          // CPU Clock not used yet
wire        CPUENA;         // CPU enable
wire        WAIT;           // CPU WAIT 
wire [15:0] cpu_addr;
wire [7:0]  cpu_din;
wire [7:0]  cpu_dout;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_mreq_n;
wire        cpu_m1_n;
wire        cpu_iorq_n;


// this was taken from https://github.com/sorgelig/Amstrad_MiST by sorgelig

t80pa cpu
(
	.reset_n ( ~CPU_RESET    ),  
	
	.clk     ( F14M          ),   
	.cen_p   ( CPUENA        ),   // CPU enable (positive edge)
	.cen_n   ( ~CPUENA       ),   // CPU enable (negative edge)

	.a       ( cpu_addr      ),   // 16 bit address bus
	.DO      ( cpu_dout      ),   // 8 bit data bus (output)
	.di      ( cpu_din       ),   // 8 bit data bus (input)
	
	.rd_n    ( cpu_rd_n      ),   // READ       0=cpu reads
	.wr_n    ( cpu_wr_n      ),   // WRITE      0=cpu writes
	
	.iorq_n  ( cpu_iorq_n    ),   // IO REQUEST 0=read from I/O
	.mreq_n  ( cpu_mreq_n    ),   // MEMORY REQUEST, idicates the bus has a valid memory address
	.m1_n    ( 1'b1          ),   // connected to expansion port on the Laser 500
	.rfsh_n  ( 1'b1          ),   // connected to expansion port on the Laser 500

	.busrq_n ( 1'b1          ),   // connected to VCC on the Laser 500
	.int_n   ( video_vs      ),   // VSYNC interrupt
	.nmi_n   ( 1'b1          ),   // connected to VCC on the Laser 500
	.wait_n  ( ~WAIT         )    // 
	
);


/******************************************************************************************/
/******************************************************************************************/
/***************************************** @vdc *******************************************/
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
	.F14M   ( F14M        ),
	.RESET  ( ~pll_locked ),
	.BLANK  ( BLANK       ),		
	
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
	
	//	SDRAM interface
	.sdram_addr   ( vdc_sdram_addr   ), 
	.sdram_din    ( vdc_sdram_din    ),
	.sdram_rd     ( vdc_sdram_rd     ),
	.sdram_wr     ( vdc_sdram_wr     ),
	.sdram_dout   ( sdram_dout       ), 
	
	.joystick_0   ( joystick_0 ),
	.joystick_1   ( joystick_1 ),
	
	.KD           ( KD      ),	
	.BUZZER       ( BUZZER  ),
	.CASOUT       ( CASOUT  ),
	.CASIN        ( CASIN   ),
	
	.alt_font     ( st_alt_font ),
	.cnt          ( hcnt ),
	
	.img_mounted  ( img_mounted ),
	.img_size     ( img_size    ) 
);


/******************************************************************************************/
/******************************************************************************************/
/***************************************** @pll *******************************************/
/******************************************************************************************/
/******************************************************************************************/

// F14M is the main 14MHz clock
// ram_clock is faster clock for the SDRAM chip, 1 complete read/write cycle in two F14M cyles
// pll_locked flags PLL is locked

wire pll_locked;

wire F14Mx2;

pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( F14M          ),        // video generator clock frequency 14.77873 MHz
	 .c1     ( SDRAM_CLK     ),        // F14M x 8, phase shifted 	 
	 .c2     ( F3M           ),        // F14M / 4 
    .c3     ( F14Mx2        ),        // F14M x 2 for the scandoubler 
	 .c4     ( ram_clock     )         // F14M x 8, phase shifted 	 
);

//
// F14M = 14778730 on real hardware with 6 clocks cycles skip every 944 ~= 14.698 
// F14M = 14700000 on the MiST almost close to the original 
//
localparam F14M_HZ = 14700000;

wire debug = 0;

// debug keyboard on the LED
always @(posedge F14M) begin
	LED_ON <= debug;
end

/******************************************************************************************/
/******************************************************************************************/
/***************************************** @ena *******************************************/
/******************************************************************************************/
/******************************************************************************************/


  

/******************************************************************************************/
/******************************************************************************************/
/***************************************** @sdram *****************************************/
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
//assign SDRAM_CLK = ram_clock;

wire        sdram_clkref ;
wire [24:0] sdram_addr   ;
wire        sdram_wr     ;
wire        sdram_rd     ;
wire [7:0]  sdram_dout   ; 
wire [7:0]  sdram_din    ; 

always @(*) begin
	if(is_downloading && download_wr) begin
		sdram_din    = download_data;
		sdram_addr   = download_addr;
		sdram_wr     = download_wr;
		sdram_rd     = 1'b1;
		sdram_clkref = F14M;
	end	
	else if(eraser_busy) begin		
		sdram_din    = eraser_data;
		sdram_addr   = eraser_addr;
		sdram_wr     = eraser_wr;
		sdram_rd     = 1'b1;		
		sdram_clkref = F14M;
	end	
	else begin
		sdram_din    = vdc_sdram_din;
		sdram_addr   = vdc_sdram_addr;
		sdram_wr     = vdc_sdram_wr;
		sdram_rd     = vdc_sdram_rd;
		sdram_clkref = F14M;
	end	
end


assign WAIT = 0; 

wire CPU_RESET = ~boot_completed | is_downloading | eraser_busy | reset_key | st_power_on;
wire BLANK     = ~boot_completed | is_downloading | eraser_busy;

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
   .clkref         ( sdram_clkref              ),
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
/***************************************** @audio *****************************************/
/******************************************************************************************/
/******************************************************************************************/
// latches cassette input

reg CASIN;
always @(posedge F14M) begin
	CASIN <= ~UART_RX;
end

wire BUZZER;
wire CASOUT;
wire audio;

//
// BUZZER for emulating the keyboard builtin speaker
// CASIN for tape monitor
// CASOUT for save to tape wire
//
dac #(.C_bits(16)) dac_AUDIO_L
(
	.clk_i(F14M),
   .res_n_i(pll_locked),	
	.dac_i({ BUZZER ^ CASIN ^ (~CASOUT), 15'b0000000 }),
	.dac_o(audio)
);

always @(posedge F14M) begin
	AUDIO_L <= audio;
	AUDIO_R <= audio;
end


/*
// CASOUT low pass filter (disabled for now)

wire [15:0] CASOUT_LPF_out;

rc_filter_1o #(
	//.highpass_g   ( 0       ),   // it's lowpass
	.R_ohms_g     ( 1000    ),   // 1 KOhm
	.C_p_farads_g ( 30000   ),   // 30nF    f0 = ~5Khz cutoff frequency
	.fclk_hz_g    ( F14M_HZ ),   // value in HZ of the F14M pulse 
	.cwidth_g     ( 14      ),   
	.dwidthi_g    ( 16      ),   // 1 bit input resolution
	.dwidtho_g    ( 16      )    // 16 bit output resolution
)
CASOUT_LPF
(
	.clk_i   ( F14M           ),
	.clken_i ( 1              ),
	.res_i   ( pll_locked     ),
	.din_i   ( { CASOUT, 15'b0 } ),
	.dout_o  ( CASOUT_LPF_out )
);
*/

endmodule
