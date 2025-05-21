
----------------------------------------------------------------------------------
-- Purpose:
-- Activate reset button on transition of 0 to 1 letgo
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY debounce IS
   PORT (
      clk : IN STD_LOGIC;
      i : IN STD_LOGIC;
      o : OUT STD_LOGIC);
END debounce;

ARCHITECTURE Behavioral OF debounce IS
   SIGNAL i2 : STD_LOGIC;
BEGIN
   PROCESS (clk)
   BEGIN
      IF rising_edge(clk) THEN
         IF i = '0' THEN
            i2 <= '1';
            o <= '0';
         ELSE
            IF i2 = '1' THEN
               o <= '1';
            ELSE
               o <= '0';
            END IF;
            i2 <= '0';
         END IF;
      END IF;
   END PROCESS;
END Behavioral;