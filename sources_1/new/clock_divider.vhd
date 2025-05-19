library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_div_50MHz is
Port (
clk_in : in STD_LOGIC; -- 100 MHz 输入
clk_out : out STD_LOGIC -- 50 MHz 输出
);
end clk_div_50MHz;

architecture Behavioral of clk_div_50MHz is
signal clk_div : std_logic := '0';
begin

process(clk_in)
begin
if rising_edge(clk_in) then
clk_div <= not clk_div;
end if;
end process;

clk_out <= clk_div;

end Behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_div_50MHz is
Port (
clk_in : in STD_LOGIC; -- 100 MHz 输入
clk_out : out STD_LOGIC -- 50 MHz 输出
);
end clk_div_50MHz;

architecture Behavioral of clk_div_50MHz is
signal clk_div : std_logic := '0';
begin

process(clk_in)
begin
if rising_edge(clk_in) then
clk_div <= not clk_div;
end if;
end process;

clk_out <= clk_div;

end Behavioral;