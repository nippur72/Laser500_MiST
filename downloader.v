// mem_read_word(0x83E9)-1;

module downloader (
	// io controller spi interface
	input         sck,
	input         ss,
	input         sdi,

	output reg    downloading,   // signal indicating an active download
	 
	// external ram interface
	input 			   clk,
	output reg        wr,
	output reg [24:0] addr,
	output reg [7:0]  data
);

wire        dio_dowloading;
wire [4:0]  dio_index;
wire        dio_wr;
wire [24:0] dio_addr;
wire [7:0]  dio_data;

data_io data_io (
	// io controller spi interface
   .sck	( sck  ),
   .ss	( ss   ),
   .sdi	( sdi  ),

	.downloading ( dio_dowloading ),  // signal indicating an active rom download
	.index       ( dio_index      ),  // 0=rom download, 1=prg dowload
	         
   // external ram interface
   .clk   ( clk      ),
   .wr    ( dio_wr   ),
   .addr  ( dio_addr ),
   .data  ( dio_data )
);

reg dio_dowloading_old = 0;
reg [2:0] cnt = 0;   

// cnt = 0  paused or downloading data
// cnt = 1  writing low byte pointer
// cnt = 2  writing high byte pointer
// cnt = 3  end

wire  rom_download = dio_index == 0;
wire  prg_download = dio_index == 8'h01 || dio_index == 8'h41;

localparam ROM_START  = 25'h0;                 // 0x0000 start of Laser 500 ROM 
localparam BASIC_TEXT = 25'h10000 + 25'h995;   // 0x8995 start of BASIC free RAM (aka TEXT)
localparam BASIC_END  = 25'h10000 + 25'h3E9;   // 0x83E9 (aka VARTAB)

wire [24:0] PRG_END_ADDRESS = 25'h8995 + dio_addr;   // TODO substitute with file lenght

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
		else if(prg_download) addr <= BASIC_TEXT + dio_addr;
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
			addr        <= BASIC_END;
			data        <= PRG_END_ADDRESS[ 7:0];
			cnt         <= 2;
		end
		if(cnt == 2) begin
			// write hi byte
			downloading <= 1;
			wr          <= 1;
			addr        <= BASIC_END+1;
			data        <= PRG_END_ADDRESS[15:8];
			cnt         <= 3;			
		end
		if(cnt == 3) begin
			// turn off dowload
			downloading <= 0;
			wr          <= 0;
			cnt         <= 0;
		end
	end	
end

endmodule

