--
-- Copyright (C) 2009-2012 Chris McClelland
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level is
	port(
      clk           : in std_logic;
--      rst_n         : in std_logic;
   
		-- FX2 interface -----------------------------------------------------------------------------
		fx2Clk_in     : in    std_logic;                    -- 48MHz clock from FX2
		fx2Addr_out   : out   std_logic_vector(1 downto 0); -- select FIFO: "10" for EP6OUT, "11" for EP8IN
		fx2Data_io    : inout std_logic_vector(7 downto 0); -- 8-bit data to/from FX2

		-- When EP6OUT selected:
		fx2Read_out   : out   std_logic;                    -- asserted (active-low) when reading from FX2
		fx2OE_out     : out   std_logic;                    -- asserted (active-low) to tell FX2 to drive bus
		fx2GotData_in : in    std_logic;                    -- asserted (active-high) when FX2 has data for us

		-- When EP8IN selected:
		fx2Write_out  : out   std_logic;                    -- asserted (active-low) when writing to FX2
		fx2GotRoom_in : in    std_logic;                    -- asserted (active-high) when FX2 has room for more data from us
		fx2PktEnd_out : out   std_logic;                    -- asserted (active-low) when a host read needs to be committed early

		-- Onboard peripherals -----------------------------------------------------------------------
		--sseg_out      : out   std_logic_vector(7 downto 0); -- seven-segment display cathodes (one for each segment)
		--anode_out     : out   std_logic_vector(3 downto 0); -- seven-segment display anodes (one for each digit)
		led_out       : out   std_logic_vector(7 downto 0); -- eight LEDs
		sw_in         : in    std_logic_vector(7 downto 0)  -- eight switches
	);
end top_level;

architecture behavioural of top_level is

	-- Channel read/write interface -----------------------------------------------------------------
	signal chanAddr  : std_logic_vector(6 downto 0);  -- the selected channel (0-127)

	-- Host >> FPGA pipe:
	signal h2fData   : std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
	signal h2fValid  : std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
	signal h2fReady  : std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

	-- Host << FPGA pipe:
	signal f2hData   : std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
	signal f2hValid  : std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
	signal f2hReady  : std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"
	-- ----------------------------------------------------------------------------------------------

	-- Needed so that the comm_fpga_fx2 module can drive both fx2Read_out and fx2OE_out
	signal fx2Read                 : std_logic;

	-- FIFOs implementing the channels
	signal fifoCount               : std_logic_vector(15 downto 0); -- MSB=writeFifo, LSB=readFifo

	-- Write FIFO:
	signal writeFifoInputData      : std_logic_vector(7 downto 0);  -- producer: data
	signal writeFifoInputValid     : std_logic;                     --           valid flag
	signal writeFifoInputReady     : std_logic;                     --           ready flag
	signal writeFifoOutputData     : std_logic_vector(7 downto 0);  -- consumer: data
	signal writeFifoOutputValid    : std_logic;                     --           valid flag
	signal writeFifoOutputReady    : std_logic;                     --           ready flag

	-- Read FIFO:
	signal readFifoInputData       : std_logic_vector(7 downto 0);  -- producer: data
	signal readFifoInputValid      : std_logic;                     --           valid flag
	signal readFifoInputReady      : std_logic;                     --           ready flag
	signal readFifoOutputData      : std_logic_vector(7 downto 0);  -- consumer: data
	signal readFifoOutputValid     : std_logic;                     --           valid flag
	signal readFifoOutputReady     : std_logic;                     --           ready flag

	-- Counter which endlessly puts items into the read FIFO for the host to read
	signal count, count_next       : std_logic_vector(7 downto 0) := (others => '0');

	-- Producer and consumer timers
	signal producerSpeed           : std_logic_vector(3 downto 0);
	signal consumerSpeed           : std_logic_vector(3 downto 0);
   
   signal clkImg, clkDisp, clkTempl, clkMin : std_logic := '0';
   signal clkSAD0, clkSAD1, clkSAD2 : std_logic := '0';
   signal ena, enTempl, enaMin, enOut : std_logic := '1';
   signal enSAD0, enSAD1, enSAD2 : std_logic := '1';
   signal weImg, wedDisp, weTempl : std_logic_vector(0 downto 0);
   signal addrImg, addrTempl : std_logic_vector(3 downto 0) := "0000";
   signal addrDisp : std_logic_vector(1 downto 0) := "00";
   signal dinImg, dinDisp, dinTempl : std_logic_vector(7 downto 0) := x"00";
   signal doutImg, doutDisp, doutTempl : std_logic_vector(7 downto 0);
   
   -- Window size, i.e. "3" -> 3x3 window
   CONSTANT window : integer := 3;
   -- win is the number of pixels above, below, right, & left of center pixel
   CONSTANT win : integer := 1;
   -- len is the number of comparisons between the template and search image
   --signal len : std_logic_vector(3 downto 0) := "0011";
   -- position is the current position of the corresponding window in the 
   --    search image, in regards to its starting spot
   signal position : std_logic_vector(3 downto 0) := "0000";
   
   signal tbyte_I, sbyte_I, sad_O : std_logic_vector(7 downto 0);
   
   -- Arrays
	-- first define the type of array
   -- Array to represent 3x3 template
	type array_type_templ is array (0 to 56) of std_logic_vector(7 downto 0);
	signal templateArray : array_type_templ := (x"02", x"05", x"05", x"03", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",
                                               x"04", x"00", x"07", x"01", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",
                                               x"07", x"05", x"09", x"06", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");
   -- Array to represent 3x5 search image 
   type array_type_search is array (0 to 56) of std_logic_vector(7 downto 0);
	signal searchArray : array_type_search := (x"02", x"07", x"05", x"08", x"06", x"00", x"02", x"07", x"05", x"08", x"06", x"00", x"02", x"07", x"05", x"08", x"06", x"00", x"00",
                                              x"01", x"07", x"04", x"02", x"07", x"09", x"01", x"07", x"04", x"02", x"07", x"09", x"01", x"07", x"04", x"02", x"07", x"09", x"00",
                                              x"08", x"04", x"06", x"08", x"05", x"03", x"08", x"04", x"06", x"08", x"05", x"03", x"08", x"04", x"06", x"08", x"05", x"03", x"00");
   
--   signal img3x3_0 : std_logic_vector(71 downto 0) := x"020705010704080406";
--   signal img3x3_1 : std_logic_vector(71 downto 0) := x"070508070402040608";
--   signal img3x3_2 : std_logic_vector(71 downto 0) := x"050806040207060805";

--   type array_type_search is array (0 to 2) of std_logic_vector(71 downto 0);
--   signal search3x3 : array_type_search := (x"020705010704080406",
--                                            x"070508070402040608",
--                                            x"050806040207060805");
   
   -- Array to represent disparities
   type array_type_disp is array (0 to 2) of std_logic_vector(3 downto 0);
	signal disparityArray : array_type_disp;-- := (x"ff", x"ff", x"ff", x"ff");
   --signal disparityVector : std_logic_vector(23 downto 0) := x"000000";
   
   -- Array to represent SAD values, total of 16 SAD values to compare for each pixel
   type array_type_sad is array (0 to 1, 0 to 15) of std_logic_vector(7 downto 0);
	signal sadArray : array_type_sad; --:= (x"ff", x"ff", x"ff");
   
   -- Index locations for each array above
   --signal ndxTempl, ndxImg, ndxDisp : integer := 0; -- WHAT IS THEIR RANGE?
   -- Number of columns in the search image
   CONSTANT ncol : INTEGER := 19;     
   -- Number of rows in the search image
   CONSTANT nrow : INTEGER := 3;
   
--   signal template3x3 : std_logic_vector(71 downto 0) := x"020505040007070509";
   --signal template3x3_1 : std_logic_vector(71 downto 0) := x"020505040007070509";
   --signal template3x3_2 : std_logic_vector(71 downto 0) := x"020505040007070509";
   --signal search3x3_0, search3x3_1, search3x3_2 : std_logic_vector(71 downto 0);
   --signal disparity : std_logic_vector(7 downto 0) := x"00";
   
   -- 2D Array for the min SAD values in the min comparator
   TYPE array_type_minSad IS ARRAY (0 TO 1, 0 TO 15) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL minSad : array_type_minSad;
   --signal minSad0, minSad1, minSad2 : std_logic_vector(7 downto 0) := x"00";
   
   -- 2D Array for the pos of the sad values in the min comparator
   TYPE array_type_minPos IS ARRAY (0 TO 1, 0 TO 15) OF STD_LOGIC_VECTOR(3 DOWNTO 0);
   SIGNAL minPos : array_type_minPos;
   --signal minPos0, minPos1, minPos2 : std_logic_vector(1 downto 0) := "00";
   --signal sadrtn0, sadrtn1, sadrtn2 : std_logic_vector(7 downto 0) := x"00";
   
   -- Currently for output of values over fpgalink
--   signal pos : std_logic_vector(1 downto 0) := "00";
   SIGNAL pos      : INTEGER RANGE 0 to 3 := 0;
   SIGNAL pos_next : INTEGER RANGE 0 to 3 := 0;
   
--   type array_type_add is array (0 to 2) of std_logic_vector(71 downto 0);
--   signal b : array_type_add := (x"020705010704080406", x"070508070402040608", x"050806040207060805");
--   type array_type_add is array (0 to 2) of std_logic_vector(7 downto 0);
--   signal b : array_type_add := (x"14", x"01", x"55");
--   signal a : STD_LOGIC_VECTOR(71 downto 0) := x"020505040007070509";
   
   -- 2D array of signed values that are outputed from the SAD algorithm
   type array_type_signed is array (0 to 1, 0 to 15) of SIGNED(8 downto 0);
   SIGNAL summer : array_type_signed;
   
begin                                                                     --BEGIN_SNIPPET(fifos)
	-- Infer registers
	process(fx2Clk_in)
	begin
		if ( rising_edge(fx2Clk_in) ) then
			count <= count_next;
         IF (pos = 3) THEN
            pos <= 0;
         ELSE
            pos <= pos_next;
         END IF;
		end if;
	end process;

	-- Wire up write FIFO to channel 0 writes:
	--   flags(2) driven by writeFifoOutputValid
	--   writeFifoOutputReady driven by consumer_timer
	--   LEDs driven by writeFifoOutputData
	writeFifoInputData <= h2fData;
	writeFifoInputValid <=
		'1' when h2fValid = '1' and chanAddr = "0000000"
		else '0';
	h2fReady <=
		'0' when writeFifoInputReady = '0' and chanAddr = "0000000"
		else '1';

	-- Wire up read FIFO to channel 0 reads:
	--   readFifoInputValid driven by producer_timer
	--   flags(0) driven by readFifoInputReady
	
   -- Ideally, count_next will get the next vector from disparityArray when readFifoInpuValid = '1'
   count_next <= sadArray(0, pos+1) when readFifoInputValid = '1'
		else sadArray(0, pos);
      
   pos_next <= pos+1 WHEN readFifoInputValid = '1'
      ELSE pos;
      
--   count_next <= sadArray(0, to_integer(unsigned(pos)));
--   pos <= std_logic_vector(unsigned(pos) + 1) when readFifoInputValid = '1'
--		else pos;
   
--		std_logic_vector(unsigned(count) + 1) when readFifoInputValid = '1'
--		else count;
	readFifoInputData <= count;
--	f2hValid <=
--		'0' when readFifoOutputValid = '0' and chanAddr = "0000000"
--		else '1';
--	readFifoOutputReady <=
--		'1' when f2hReady = '1' and chanAddr = "0000000"
--		else '0';
	
	f2hValid <=
		'1';
	readFifoOutputReady <=
		'1' when f2hReady = '1' and chanAddr = "0000000"
		else '0';
	
	-- Select values to return for each channel when the host is reading
	with chanAddr select f2hData <=
		readFifoOutputData     when "0000000",  -- get data from read FIFO
		fifoCount(15 downto 8) when "0000001",  -- read the depth of the write FIFO
		fifoCount(7 downto 0)  when "0000010",  -- read the depth of the read FIFO
		x"00"                  when others;                                   --END_SNIPPET(fifos)
	
	-- CommFPGA module
	fx2Read_out <= fx2Read;
	fx2OE_out <= fx2Read;
	fx2Addr_out(1) <= '1';  -- Use EP6OUT/EP8IN, not EP2OUT/EP4IN.
	comm_fpga_fx2 : entity work.comm_fpga_fx2
		port map(
			-- FX2 interface
			fx2Clk_in      => fx2Clk_in,
			fx2FifoSel_out => fx2Addr_out(0),
			fx2Data_io     => fx2Data_io,
			fx2Read_out    => fx2Read,
			fx2GotData_in  => fx2GotData_in,
			fx2Write_out   => fx2Write_out,
			fx2GotRoom_in  => fx2GotRoom_in,
			fx2PktEnd_out  => fx2PktEnd_out,

			-- Channel read/write interface
			chanAddr_out   => chanAddr,
			h2fData_out    => h2fData,
			h2fValid_out   => h2fValid,
			h2fReady_in    => h2fReady,
			f2hData_in     => f2hData,
			f2hValid_in    => f2hValid,
			f2hReady_out   => f2hReady
		);

	-- Write FIFO: written by host, read by LEDs
	write_fifo : entity work.fifo_wrapper
		port map(
			clk_in          => fx2Clk_in,
			depth_out       => fifoCount(15 downto 8),

			-- Production end
			inputData_in    => writeFifoInputData,
			inputValid_in   => writeFifoInputValid,
			inputReady_out  => writeFifoInputReady,

			-- Consumption end
			outputData_out  => writeFifoOutputData,
			outputValid_out => writeFifoOutputValid,
			outputReady_in  => writeFifoOutputReady
		);
	
	-- Read FIFO: written by counter, read by host
	read_fifo : entity work.fifo_wrapper
		port map(
			clk_in          => fx2Clk_in,
			depth_out       => fifoCount(7 downto 0),

			-- Production end
			inputData_in    => readFifoInputData,
			inputValid_in   => readFifoInputValid,
			inputReady_out  => readFifoInputReady,

			-- Consumption end
			outputData_out  => readFifoOutputData,
			outputValid_out => readFifoOutputValid,
			outputReady_in  => readFifoOutputReady
		);

	-- Producer timer: how fast stuff is put into the read FIFO
	producerSpeed <= not("0000");--sw_in(3 downto 0));
	producer_timer : entity work.timer
		port map(
			clk_in     => fx2Clk_in,
			ceiling_in => producerSpeed,
			tick_out   => readFifoInputValid
		);

	-- Consumer timer: how fast stuff is drained from the write FIFO
	consumerSpeed <= not("0000");--sw_in(7 downto 4));
	consumer_timer : entity work.timer
		port map(
			clk_in     => fx2Clk_in,
			ceiling_in => consumerSpeed,
			tick_out   => writeFifoOutputReady
		);
   
   -- Drives other internal clocks with fx2Clk_in
   clocks : PROCESS (fx2Clk_in)
   BEGIN
      clkImg   <= NOT(clkImg);
      clkDisp  <= NOT(clkDisp);
      clkTempl <= NOT(clkTempl);
      clkMin   <= NOT(clkMin);
   END PROCESS clocks;

   -- LED output for SAD and disparity values, display dependent on switches
   WITH sw_in SELECT led_out <=
      sadArray(0, 0)                   WHEN x"00",
      sadArray(0, 1)                   WHEN x"01",
      sadArray(0, 2)                   WHEN x"02",
      sadArray(0, 3)                   WHEN x"03",
      sadArray(0, 4)                   WHEN x"04",
      sadArray(0, 5)                   WHEN x"05",
      sadArray(0, 6)                   WHEN x"06",
      sadArray(0, 7)                   WHEN x"07",
      sadArray(0, 8)                   WHEN x"08",
      sadArray(0, 9)                   WHEN x"09",
      sadArray(0, 10)                  WHEN x"0a",
      sadArray(0, 11)                  WHEN x"0b",
      sadArray(0, 12)                  WHEN x"0c",
      sadArray(0, 13)                  WHEN x"0d",
      sadArray(0, 14)                  WHEN x"0e",
      sadArray(0, 15)                  WHEN x"0f",
      
      sadArray(1, 0)                   WHEN x"10",
      sadArray(1, 1)                   WHEN x"11",
      sadArray(1, 2)                   WHEN x"12",
      
      minSad(0, 0)                     WHEN x"13",
      "0000" & minPos(0, 0)            WHEN x"14",
      minSad(0, 1)                     WHEN x"15",
      "0000" & minPos(0, 1)            WHEN x"16",
      minSad(0, 2)                     WHEN x"17",
      "0000" & minPos(0, 2)            WHEN x"18",
      minSad(0, 3)                     WHEN x"19",
      "0000" & minPos(0, 3)            WHEN x"1a",
      minSad(0, 4)                     WHEN x"1b",
      "0000" & minPos(0, 4)            WHEN x"1c",
      minSad(0, 5)                     WHEN x"1d",
      "0000" & minPos(0, 5)            WHEN x"1e",
      minSad(0, 6)                     WHEN x"1f",
      "0000" & minPos(0, 6)            WHEN x"20",
      minSad(0, 7)                     WHEN x"21",
      "0000" & minPos(0, 7)            WHEN x"22",
      minSad(0, 8)                     WHEN x"23",
      "0000" & minPos(0, 8)            WHEN x"24",
      minSad(0, 9)                     WHEN x"25",
      "0000" & minPos(0, 9)            WHEN x"26",
      minSad(0, 10)                    WHEN x"27",
      "0000" & minPos(0, 10)           WHEN x"28",
      minSad(0, 11)                    WHEN x"29",
      "0000" & minPos(0, 11)           WHEN x"2a",
      minSad(0, 12)                    WHEN x"2b",
      "0000" & minPos(0, 12)           WHEN x"2c",
      minSad(0, 13)                    WHEN x"2d",
      "0000" & minPos(0, 13)           WHEN x"2e",
      minSad(0, 14)                    WHEN x"2f",
      "0000" & minPos(0, 14)           WHEN x"30",
      
      "0000" & disparityArray(0)       WHEN x"31",
      "0000" & disparityArray(1)       WHEN x"32",
		x"00"                            WHEN OTHERS;

--------------------------------------------------------------------------------
-- Sum of the Absolute Differences Algorithm
--------------------------------------------------------------------------------
   -- Sum of the Absolute Difference between the template 3x3 and search 3x3, range 0 to 2
   -- It currently does two sets of three SADs at the same time
   sum_abs_diff : PROCESS(templateArray, searchArray)
   BEGIN
      FOR i IN 0 TO 1 LOOP     -- For each center template pixel/group of SADs
         FOR j IN 0 TO 15 LOOP -- For the 16 SAD values to compare for disparity
            summer(i, j) <= 
               abs(SIGNED('0' & templateArray(0+i))           - SIGNED('0' & searchArray(0+i+j))) + 
               abs(SIGNED('0' & templateArray(1+i))           - SIGNED('0' & searchArray(1+i+j))) + 
               abs(SIGNED('0' & templateArray(2+i))           - SIGNED('0' & searchArray(2+i+j))) + 
               abs(SIGNED('0' & templateArray(0+ncol+i))      - SIGNED('0' & searchArray(0+ncol+i+j))) +
               abs(SIGNED('0' & templateArray(1+ncol+i))      - SIGNED('0' & searchArray(1+ncol+i+j))) +
               abs(SIGNED('0' & templateArray(2+ncol+i))      - SIGNED('0' & searchArray(2+ncol+i+j))) +
               abs(SIGNED('0' & templateArray(0+ncol+ncol+i)) - SIGNED('0' & searchArray(0+ncol+ncol+i+j))) +
               abs(SIGNED('0' & templateArray(1+ncol+ncol+i)) - SIGNED('0' & searchArray(1+ncol+ncol+i+j))) +
               abs(SIGNED('0' & templateArray(2+ncol+ncol+i)) - SIGNED('0' & searchArray(2+ncol+ncol+i+j)));
         END LOOP;
      END LOOP;
   END PROCESS sum_abs_diff;

   -- Assigns the values from summer array to sad array
   sad_assign : PROCESS(summer)
   BEGIN
      FOR i IN 0 TO 1 LOOP
         FOR j IN 0 TO 15 LOOP
            sadArray(i, j) <= STD_LOGIC_VECTOR(summer(i, j)(7 DOWNTO 0));
         END LOOP;
         --sadArray(i, 3) <= x"ff"; -- Figure out better way to do/get rid of this if still needed
      END LOOP;
   END PROCESS sad_assign;

   
   
   
--------------------------------------------------------------------------------
-- Minimum Comparators between SAD values to obtain disparity values
--------------------------------------------------------------------------------
   -- For Loop for minimum comparator between two SAD values from the sad array
   g_sadComp8 : FOR i IN 0 TO 1 GENERATE    -- For each center template pixel/group of SADs
   BEGIN
      g_minComp8 : FOR j IN 0 TO 7 GENERATE -- For the initial 8 comp. of the 16 SAD values
      BEGIN
         i_minComp8 : ENTITY work.minComparator 
            PORT MAP (
               sad0 => sadArray(i, j*2),
               pos0 => STD_LOGIC_VECTOR(TO_UNSIGNED(j*2, 4)),--"00",--std_logic_vector(to_unsigned(0, 2)),
               sad1 => sadArray(i, (j*2)+1),
               pos1 => STD_LOGIC_VECTOR(TO_UNSIGNED((j*2)+1, 4)),--"01",--std_logic_vector(to_unsigned(1, 2)),
               sad  => minSad(i, j), -- 0 to 7 of minSad
               pos  => minPos(i, j)  -- 0 to 7 of minPos
         );
      END GENERATE g_minComp8;
   END GENERATE g_sadComp8;

   -- For Loop for minimum comparator between two SAD values from the sad array
   g_sadComp4 : FOR i IN 0 TO 1 GENERATE    -- For each center template pixel/group of SADs
   BEGIN
      g_minComp4 : FOR j IN 0 TO 3 GENERATE -- For the 2nd 4 comp. of the 8 SAD remaining values
      BEGIN
         i_minComp4 : ENTITY work.minComparator 
            PORT MAP (
               sad0 => minSad(i, j*2),
               pos0 => minPos(i, j*2),
               sad1 => minSad(i, (j*2)+1),
               pos1 => minPos(i, (j*2)+1),
               sad  => minSad(i, j+8), -- 8 to 11 of minSad
               pos  => minPos(i, j+8)  -- 8 to 11 of minPos
         );
      END GENERATE g_minComp4;
   END GENERATE g_sadComp4;

   -- For Loop for minimum comparator between two SAD values from the sad array
   g_sadComp2 : FOR i IN 0 TO 1 GENERATE    -- For each center template pixel/group of SADs
   BEGIN
      g_minComp2 : FOR j IN 0 TO 1 GENERATE -- For the 2nd 4 comp. of the 8 SAD remaining values
      BEGIN
         i_minComp2 : ENTITY work.minComparator 
            PORT MAP (
               sad0 => minSad(i, j*2 + 8),
               pos0 => minPos(i, j*2 + 8),
               sad1 => minSad(i, (j*2)+1 + 8),
               pos1 => minPos(i, (j*2)+1 + 8),
               sad  => minSad(i, j+12), -- 12 to 13 of minSad
               pos  => minPos(i, j+12)  -- 12 to 13 of minPos
         );
      END GENERATE g_minComp2;
   END GENERATE g_sadComp2;

   -- Minimum Comparator, which compares the min outputs from minComp0 & minComp1
   g_minResult : FOR i IN 0 TO 1 GENERATE
   BEGIN
      i_minResult : ENTITY work.minComparator 
         PORT MAP ( 
            sad0 => minSad(i, 12),
            pos0 => minPos(i, 12),
            sad1 => minSad(i, 13),
            pos1 => minPos(i, 13),
            sad  => minSad(i, 14),
            pos  => minPos(i, 14)
      );
   END GENERATE g_minResult;

   -- Assign disparity values from minPos array to disparity array
   disparity_assign : PROCESS(minPos)
   BEGIN
      FOR i IN 0 TO 1 LOOP
         disparityArray(i) <= minPos(i, 14);
      END LOOP;
   END PROCESS disparity_assign;











--   -- minimum comparator between two SAD values from the sad array
--   --    Combine with minComp1 into a For Loop.
--   minComp0 : ENTITY work.minComparator 
--      PORT MAP ( 
--         clk  => clkMin,
--         ena  => enaMin,
--         sad0 => sadArray(0),
--         pos0 => "00",--std_logic_vector(to_unsigned(0, 2)),
--         sad1 => sadArray(1),
--         pos1 => "01",--std_logic_vector(to_unsigned(1, 2)),
--         sad  => minSad0,
--         pos  => minPos0
--	);
   
--   -- minimum comparator between two SAD values from the sad array
--   --    Combine with minComp0 into a For Loop.
--   minComp1 : ENTITY work.minComparator
--      PORT MAP ( 
--         clk  => clkMin,
--         ena  => enaMin,
--         sad0 => sadArray(2),
--         pos0 => "10",--std_logic_vector(to_unsigned(2, 2)),
--         sad1 => x"ff",
--         pos1 => "11",
--         sad  => minSad1,
--         pos  => minPos1
--	);
   
--   -- Minimum Comparator, which compares the min outputs from minComp0 & minComp1
--   minComp2 : ENTITY work.minComparator 
--      PORT MAP ( 
--         clk  => clkMin,
--         ena  => enaMin,
--         sad0 => minSad0,
--         pos0 => minPos0,
--         sad1 => minSad1,
--         pos1 => minPos1,
--         sad  => minSad2,
--         pos  => minPos2
--	);

   -- Assigns the disparity (offset position) from minComp2 into the disparity array
--   disparity_assign : PROCESS(minPos2)
--   BEGIN
--      FOR i IN 0 TO 0 LOOP
--         disparityArray(i) <= minPos2;
--      END LOOP;
--   END PROCESS disparity_assign;

END behavioural;