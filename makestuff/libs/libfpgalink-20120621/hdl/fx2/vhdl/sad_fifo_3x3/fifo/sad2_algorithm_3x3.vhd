----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:46:35 04/20/2014 
-- Design Name: 
-- Module Name:    sad - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sad2_algorithm_3x3 is
   Port ( 
--      TBYTE_I : in  STD_LOGIC_VECTOR (7 downto 0);
--      SBYTE_I : in  STD_LOGIC_VECTOR (7 downto 0);
--      SAD_O   : out STD_LOGIC_VECTOR (7 downto 0)
--      t_tl : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_tc : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_tr : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_cl : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_cc : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_cr : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_bl : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_bc : in  STD_LOGIC_VECTOR (7 downto 0);
--      t_br : in  STD_LOGIC_VECTOR (7 downto 0);
--      
--      s_tl : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_tc : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_tr : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_cl : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_cc : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_cr : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_bl : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_bc : in  STD_LOGIC_VECTOR (7 downto 0);
--      s_br : in  STD_LOGIC_VECTOR (7 downto 0);

      clk : in std_logic;
      ena : in std_logic;
      
      template3x3 : in std_logic_vector (71 downto 0);
      search3x3   : in std_logic_vector (71 downto 0);
      
      SAD_O : out STD_LOGIC_VECTOR (7 downto 0)
   );
end sad2_algorithm_3x3;

architecture Behavioral of sad2_algorithm_3x3 is

   signal t_tl_s : signed(8 downto 0);
   signal t_tc_s : signed(8 downto 0);
   signal t_tr_s : signed(8 downto 0);
   signal t_cl_s : signed(8 downto 0);
   signal t_cc_s : signed(8 downto 0);
   signal t_cr_s : signed(8 downto 0);
   signal t_bl_s : signed(8 downto 0);
   signal t_bc_s : signed(8 downto 0);
   signal t_br_s : signed(8 downto 0);

   signal s_tl_s : signed(8 downto 0);
   signal s_tc_s : signed(8 downto 0);
   signal s_tr_s : signed(8 downto 0);
   signal s_cl_s : signed(8 downto 0);
   signal s_cc_s : signed(8 downto 0);
   signal s_cr_s : signed(8 downto 0);
   signal s_bl_s : signed(8 downto 0);
   signal s_bc_s : signed(8 downto 0);
   signal s_br_s : signed(8 downto 0);
   
   signal sad_tl_s : signed(8 downto 0);
   signal sad_tc_s : signed(8 downto 0);
   signal sad_tr_s : signed(8 downto 0);
   signal sad_cl_s : signed(8 downto 0);
   signal sad_cc_s : signed(8 downto 0);
   signal sad_cr_s : signed(8 downto 0);
   signal sad_bl_s : signed(8 downto 0);
   signal sad_bc_s : signed(8 downto 0);
   signal sad_br_s : signed(8 downto 0);

--   signal TBYTEs : signed(8 downto 0);
--	signal SBYTEs : signed(8 downto 0);
	--signal SADs   : signed(8 downto 0);

begin

--   TBYTEs <= signed ('0' & TBYTE_I);
--	SBYTEs <= signed ('0' & SBYTE_I);
--	SADs <= abs(TBYTEs - SBYTEs);
--	SAD_O <= std_logic_vector(SADs(7 downto 0));
   
   -- top left pixel
   t_tl_s   <= signed ('0' & template3x3(71 downto 64));
	s_tl_s   <= signed ('0' & search3x3(71 downto 64));
	sad_tl_s <= abs(t_tl_s - s_tl_s);
   
   -- top center pixel
   t_tc_s   <= signed ('0' & template3x3(63 downto 56));
	s_tc_s   <= signed ('0' & search3x3(63 downto 56));
	sad_tc_s <= abs(t_tc_s - s_tc_s);
   
   -- top right pixel
   t_tr_s   <= signed ('0' & template3x3(55 downto 48));
	s_tr_s   <= signed ('0' & search3x3(55 downto 48));
	sad_tr_s <= abs(t_tr_s - s_tr_s);
   
   -- center left pixel
   t_cl_s   <= signed ('0' & template3x3(47 downto 40));
	s_cl_s   <= signed ('0' & search3x3(47 downto 40));
	sad_cl_s <= abs(t_cl_s - s_cl_s);
   
   -- center center pixel
   t_cc_s   <= signed ('0' & template3x3(39 downto 32));
	s_cc_s   <= signed ('0' & search3x3(39 downto 32));
	sad_cc_s <= abs(t_cc_s - s_cc_s);
   
   -- center right pixel
   t_cr_s   <= signed ('0' & template3x3(31 downto 24));
	s_cr_s   <= signed ('0' & search3x3(31 downto 24));
	sad_cr_s <= abs(t_cr_s - s_cr_s);
   
   -- bottom left pixel
   t_bl_s   <= signed ('0' & template3x3(23 downto 16));
	s_bl_s   <= signed ('0' & search3x3(23 downto 16));
	sad_bl_s <= abs(t_bl_s - s_bl_s);
   
   -- bottom center pixel
   t_bc_s   <= signed ('0' & template3x3(15 downto 8));
	s_bc_s   <= signed ('0' & search3x3(15 downto 8));
	sad_bc_s <= abs(t_bc_s - s_bc_s);
   
   -- bottom right pixel
   t_br_s   <= signed ('0' & template3x3(7 downto 0));
	s_br_s   <= signed ('0' & search3x3(7 downto 0));
	sad_br_s <= abs(t_br_s - s_br_s);
   
   -- Sum up the absolute differences for each corresponding pair of pixels
--   SAD_O <= std_logic_vector(sad_tl_s(7 downto 0)) +
--            std_logic_vector(sad_tc_s(7 downto 0)) +
--            std_logic_vector(sad_tr_s(7 downto 0)) +
--            std_logic_vector(sad_cl_s(7 downto 0)) +
--            std_logic_vector(sad_cc_s(7 downto 0)) +
--            std_logic_vector(sad_cr_s(7 downto 0)) +
--            std_logic_vector(sad_bl_s(7 downto 0)) +
--            std_logic_vector(sad_bc_s(7 downto 0)) +
--            std_logic_vector(sad_br_s(7 downto 0));
   SAD_O <= std_logic_vector(sad_tl_s(7 downto 0) +
                             sad_tc_s(7 downto 0) +
                             sad_tr_s(7 downto 0) +
                             sad_cl_s(7 downto 0) +
                             sad_cc_s(7 downto 0) +
                             sad_cr_s(7 downto 0) +
                             sad_bl_s(7 downto 0) +
                             sad_bc_s(7 downto 0) +
                             sad_br_s(7 downto 0));

end Behavioral;


