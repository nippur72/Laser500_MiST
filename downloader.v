module downloader (	

	// new SPI interface
   input SPI_DO,
	input SPI_DI,
   input SPI_SCK,
   input SPI_SS2,
   input SPI_SS3,
   input SPI_SS4,
	
	input 			   clk,
	output reg        wr,
	output reg [24:0] addr,
	output reg [7:0]  data,

	output reg        downloading,   // signal indicating an active download
	output            ROM_done       // indicates the ROM has already been loaded at boot up
);

wire        dio_dowloading;
wire [7:0]  dio_index;      
wire        dio_wr;
wire [24:0] dio_addr;
wire [7:0]  dio_data;

data_io data_io (
	.clk_sys ( clk  ),
	.clkref_n( 0    ),  // keep this to zero
	
	// io controller spi interface
	.SPI_SCK( SPI_SCK ),
	.SPI_SS2( SPI_SS2 ),
	.SPI_SS4( SPI_SS4 ),
	.SPI_DI ( SPI_DI  ),
	.SPI_DO ( SPI_DO  ), 	  

	.ioctl_download ( dio_dowloading ),  // signal indicating an active rom download
	.ioctl_index    ( dio_index      ),  // 0=rom download, 1=prg dowload
   .ioctl_wr       ( dio_wr         ),
   .ioctl_addr     ( dio_addr       ),
   .ioctl_dout     ( dio_data       )
);

assign ROM_done = ROM_loaded;

reg ROM_loaded = 0;

reg dio_dowloading_old = 0;
reg [2:0] cnt = 0;   

// cnt = 0  paused or downloading data
// cnt = 1  writing low byte pointer
// cnt = 2  writing high byte pointer
// cnt = 3  end

wire  rom_download = dio_index == 0;
wire  prg_download = dio_index == 8'h01 || dio_index == 8'h41;

localparam ROM_START  = 25'h0;                 // 0x0000 start of Laser 500 ROM 
localparam PTR_TEXT   = 25'h10000 + 25'h995;   // 0x8995 start of BASIC free RAM (aka TEXT)
localparam PTR_VARTAB = 25'h10000 + 25'h3E9;   // 0x83E9 (aka VARTAB)

wire [24:0] PRG_END_ADDRESS = 25'h8995 + dio_addr;   // TODO substitute with file lenght
wire [24:0] VARTAB_VALUE = PRG_END_ADDRESS + 1;      // VARTAB points to the byte after the BASIC program

always @(posedge clk) begin
	
	// detect change in dio_dowloading
	dio_dowloading_old <= dio_dowloading;	
	
	if(dio_dowloading) begin
	   // main downloading, save into ROM or RAM (*.prg)
		downloading <= 1;
		wr          <= dio_wr;
		data        <= dio_data;
		cnt         <= 0;
		
		     if(rom_download) addr <= ROM_START  + dio_addr;				
		else if(prg_download) addr <= PTR_TEXT + dio_addr;
	end
	else if(dio_dowloading == 0 && dio_dowloading_old == 1) begin
		// main download done
		if(prg_download) cnt <= 1;  // continue writing VARTAB pointer
		else             cnt <= 3;  // no further steps for ROM 
	end 
	else if(dio_dowloading == 0 && dio_dowloading_old == 0) begin
		if(cnt == 1) begin
			// write low byte 
			downloading <= 1;
			wr          <= 1;
			addr        <= PTR_VARTAB;
			data        <= VARTAB_VALUE[ 7:0];
			cnt         <= 2;
		end
		if(cnt == 2) begin
			// write hi byte
			downloading <= 1;
			wr          <= 1;
			addr        <= PTR_VARTAB+1;
			data        <= VARTAB_VALUE[15:8];
			cnt         <= 3;			
		end
		if(cnt == 3) begin
			// turn off dowload
			downloading <= 0;
			wr          <= 0;
			cnt         <= 0;
			if(rom_download) ROM_loaded <= 1;
		end
	end	
end

endmodule

