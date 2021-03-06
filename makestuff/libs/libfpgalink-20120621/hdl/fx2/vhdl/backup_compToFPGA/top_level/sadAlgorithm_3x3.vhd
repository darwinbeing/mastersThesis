----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:20:30 06/23/2014 
-- Design Name: 
-- Module Name:    sadAlgorithm_3x3 - Behavioral 
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

entity sadAlgorithm_3x3 is
   Port ( 
      ttl : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      ttc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      ttr : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tml : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tmc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tmr : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tbl : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tbc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      tbr : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      
      stl : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      stc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      str : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      sml : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      smc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      smr : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      sbl : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      sbc : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      sbr : IN  STD_LOGIC_VECTOR (7 DOWNTO 0);
      
      sad : OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
   );
end sadAlgorithm_3x3;

architecture Behavioral of sadAlgorithm_3x3 is
   
   SIGNAL sum_sign : SIGNED(10 DOWNTO 0);
   
begin
   
   -- Sum of the Absolute Difference between the template 3x3 and search 3x3
   signed_sum : PROCESS (ttl, ttc, ttr, tml, tmc, tmr, tbl, tbc, tbr, stl, stc, str, sml, smc, smr, sbl, sbc, sbr)
   BEGIN
      --sum_array_next <= sum_array;
      sum_sign <= 
         abs(SIGNED("000" & ttl) - SIGNED("000" & stl)) + 
         abs(SIGNED("000" & ttc) - SIGNED("000" & stc)) + 
         abs(SIGNED("000" & ttr) - SIGNED("000" & str)) + 
         abs(SIGNED("000" & tml) - SIGNED("000" & sml)) +
         abs(SIGNED("000" & tmc) - SIGNED("000" & smc)) +
         abs(SIGNED("000" & tmr) - SIGNED("000" & smr)) +
         abs(SIGNED("000" & tbl) - SIGNED("000" & sbl)) +
         abs(SIGNED("000" & tbc) - SIGNED("000" & sbc)) +
         abs(SIGNED("000" & tbr) - SIGNED("000" & sbr));
   END PROCESS signed_sum;
   
   -- Assigns the values from summer array to sad array
   sad_assign : PROCESS(sum_sign)
   BEGIN
      --sad_array_next <= sad_array;
      --FOR i IN 0 TO 2 LOOP
      IF (sum_sign < 256) THEN
         sad <= STD_LOGIC_VECTOR(sum_sign(9 DOWNTO 0));
      ELSE
         sad <= x"ff" & "00";
      END IF;
      --END LOOP;
   END PROCESS sad_assign;

end Behavioral;

