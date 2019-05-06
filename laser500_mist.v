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
parameter CONF_STR = {
	"Laser500;;",
	"O1,Scanlines,On,Off;",
	"T2,Reset"
};

parameter CONF_STR_LEN = 10+20+8;

wire [7:0] status;       // the status register is controlled by the on screen display (OSD)

wire st_poweron  = status[0];
wire st_scalines = status[1];
wire st_reset    = status[2];

// include user_io module for arm controller communication
user_io #(.STRLEN(CONF_STR_LEN)) user_io ( 
	.conf_str   ( CONF_STR   ),

	.SPI_CLK    ( SPI_SCK    ),
	.SPI_SS_IO  ( CONF_DATA0 ),
	.SPI_MISO   ( SPI_DO     ),
	.SPI_MOSI   ( SPI_DI     ),

	.status     ( status     )
);

// include the on screen display

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
VTL_chip VTL_chip (	
	.F14M   ( F14M        ),
   .CPUCK  ( CPUCK       ),
	.hsync  ( hsync       ),
	.vsync  ( vsync       ),
	.r      ( video_r     ),
	.g      ( video_g     ),
	.b      ( video_b     )
);

// The CPU is kept in reset for further 256 cyckes after the PLL is generating stable clocks
// to make sure things like the SDRAM have some time to initialize

reg [7:0] cpu_reset_cnt = 8'h00;
wire cpu_reset = (cpu_reset_cnt != 255);
always @(posedge CPUCK) begin
	if(!pll_locked || st_poweron || st_reset || dio_download)
		cpu_reset_cnt <= 8'd0;
	else 
		if(cpu_reset_cnt != 255)
			cpu_reset_cnt <= cpu_reset_cnt + 8'd1;
end
			
//
// RAM (SDRAM)
//
			
// bank switching
reg  [3:0]  banks[1:0];
wire        bank          = cpu_addr[15:14];
wire        base_addr     = cpu_addr[13:0];
wire [19:0] paged_address = { 7'd0, banks[bank], base_addr };
wire        bank_is_ram   = (bank >= 4 && bank <=7);  // TODO mapped io, TODO 350/700 ram config
wire        mapped_io     = bank == 2;
			
// SDRAM control signals
wire ram_clock;
assign SDRAM_CKE = 1'b1;

// during ROM download data_io writes the ram. Otherwise the CPU
wire [7:0]  sdram_din  = dio_download ? dio_data  : cpu_dout;
wire [24:0] sdram_addr = dio_download ? dio_addr  : paged_address;
wire        sdram_wr   = dio_download ? dio_write : bank_is_ram;    // TODO ROM write only management
wire        sdram_cs   = dio_download ? 1'b1 : !cpu_rd_n;

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
   .oe         	 ( sdram_cs                  ),
   .dout           ( sdram_dout                )
);
	
//
// Z80 CPU
//
	
// CPU control signals
wire        CPUCK;
wire [15:0] cpu_addr;
wire [7:0]  cpu_din;
wire [7:0]  cpu_dout;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_mreq_n;
wire        cpu_m1_n;
wire        cpu_iorq_n;

// include Z80 CPU
T80s T80s (
	.RESET_n  ( !cpu_reset    ),   // TODO connect to RESET key
	.CLK_n    ( CPUCK         ),   // TODO is it negated or not? is it in phase with F14M ?
	.WAIT_n   ( 1'b1          ),   // TODO connect to wait line
	.INT_n    ( vsync         ),   // VSYNC interrupt
	.NMI_n    ( 1'b1          ),   // connected to VCC
	.BUSRQ_n  ( 1'b1          ),   // connected to VCC
	.MREQ_n   ( cpu_mreq_n    ),
	.M1_n     ( cpu_m1_n      ),
	.IORQ_n   ( cpu_iorq_n    ),
	.RD_n     ( cpu_rd_n      ), 
	.WR_n     ( cpu_wr_n      ),
	.A        ( cpu_addr      ),
	.DI       ( cpu_din       ),
	.DO       ( cpu_dout      )
);

wire [7:0] sdram_dout;
assign cpu_din = sdram_dout;

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
// clocks
//

wire pll_locked;

pll pll (
	 .inclk0 ( CLOCK_27[0]   ),
	 .locked ( pll_locked    ),        // PLL is running stable
	 .c0     ( F14M          ),        // video generator clock frequency 14.77873 MHz
	 .c1     ( ram_clock     ),        // RAM clock 81 MHz  
	 .c2     ( SDRAM_CLK     )         // RAM clock 81 MHz slightly phase shifted
);

endmodule
