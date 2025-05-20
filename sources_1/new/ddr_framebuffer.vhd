-------------------------------------------------------------------------------
--                                                                 
--  DDR Framebuffer - Simple Implementation
--                                                                  
-------------------------------------------------------------------------------
-- FILE NAME      : ddr_framebuffer.vhd
-- DESCRIPTION    : Framebuffer implementation using DDR memory with identical
--                  interface to the original framebuffer
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_framebuffer is
port (
    -- Original framebuffer interface
    data : in std_logic_vector(15 downto 0);
    wraddress : in std_logic_vector(12 downto 0);
    wrclock : in std_logic;
    wren : in std_logic;
    rdaddress : in std_logic_vector(12 downto 0);
    rdclock : in std_logic;
    q : out std_logic_vector(15 downto 0);
    
    -- DDR interface (add to port map in top level)
    clk_200MHz_i : in std_logic;
    rst_i : in std_logic;
    device_temp_i : in std_logic_vector(11 downto 0);
    
    -- DDR2 physical interface
    ddr2_addr : out std_logic_vector(12 downto 0);
    ddr2_ba : out std_logic_vector(2 downto 0);
    ddr2_ras_n : out std_logic;
    ddr2_cas_n : out std_logic;
    ddr2_we_n : out std_logic;
    ddr2_ck_p : out std_logic_vector(0 downto 0);
    ddr2_ck_n : out std_logic_vector(0 downto 0);
    ddr2_cke : out std_logic_vector(0 downto 0);
    ddr2_cs_n : out std_logic_vector(0 downto 0);
    ddr2_dm : out std_logic_vector(1 downto 0);
    ddr2_odt : out std_logic_vector(0 downto 0);
    ddr2_dq : inout std_logic_vector(15 downto 0);
    ddr2_dqs_p : inout std_logic_vector(1 downto 0);
    ddr2_dqs_n : inout std_logic_vector(1 downto 0)
);
end ddr_framebuffer;

architecture rtl of ddr_framebuffer is

-- Component declaration for Ram2Ddr
component Ram2Ddr is
   port (
      -- Common
      clk_200MHz_i : in std_logic;
      rst_i : in std_logic;
      device_temp_i : in std_logic_vector(11 downto 0);
      
      -- RAM interface
      ram_a : in std_logic_vector(26 downto 0);
      ram_dq_i : in std_logic_vector(15 downto 0);
      ram_dq_o : out std_logic_vector(15 downto 0);
      ram_cen : in std_logic;
      ram_oen : in std_logic;
      ram_wen : in std_logic;
      ram_ub : in std_logic;
      ram_lb : in std_logic;
      
      -- DDR2 interface
      ddr2_addr : out std_logic_vector(12 downto 0);
      ddr2_ba : out std_logic_vector(2 downto 0);
      ddr2_ras_n : out std_logic;
      ddr2_cas_n : out std_logic;
      ddr2_we_n : out std_logic;
      ddr2_ck_p : out std_logic_vector(0 downto 0);
      ddr2_ck_n : out std_logic_vector(0 downto 0);
      ddr2_cke : out std_logic_vector(0 downto 0);
      ddr2_cs_n : out std_logic_vector(0 downto 0);
      ddr2_dm : out std_logic_vector(1 downto 0);
      ddr2_odt : out std_logic_vector(0 downto 0);
      ddr2_dq : inout std_logic_vector(15 downto 0);
      ddr2_dqs_p : inout std_logic_vector(1 downto 0);
      ddr2_dqs_n : inout std_logic_vector(1 downto 0)
   );
end component;

-- Simple state machine
type state_type is (IDLE, WRITING, READING);
signal state : state_type := IDLE;

-- Registers for synchronization
signal wr_data_reg : std_logic_vector(15 downto 0);
signal wr_addr_reg : std_logic_vector(12 downto 0);
signal wr_en_reg : std_logic;
signal rd_addr_reg : std_logic_vector(12 downto 0);
signal rd_data_reg : std_logic_vector(15 downto 0);

-- RAM to DDR interface signals
signal ram_addr : std_logic_vector(26 downto 0);
signal ram_dq_i : std_logic_vector(15 downto 0);
signal ram_dq_o : std_logic_vector(15 downto 0);
signal ram_cen : std_logic := '1';  -- Active low
signal ram_oen : std_logic := '1';  -- Active low
signal ram_wen : std_logic := '1';  -- Active low
signal ram_ub : std_logic := '0';   -- Active low
signal ram_lb : std_logic := '0';   -- Active low

begin

-- Instantiate the Ram2Ddr module
ram2ddr_inst : Ram2Ddr
port map (
    clk_200MHz_i => clk_200MHz_i,
    rst_i => rst_i,
    device_temp_i => device_temp_i,
    
    ram_a => ram_addr,
    ram_dq_i => ram_dq_i,
    ram_dq_o => ram_dq_o,
    ram_cen => ram_cen,
    ram_oen => ram_oen,
    ram_wen => ram_wen,
    ram_ub => ram_ub,
    ram_lb => ram_lb,
    
    ddr2_addr => ddr2_addr,
    ddr2_ba => ddr2_ba,
    ddr2_ras_n => ddr2_ras_n,
    ddr2_cas_n => ddr2_cas_n,
    ddr2_we_n => ddr2_we_n,
    ddr2_ck_p => ddr2_ck_p,
    ddr2_ck_n => ddr2_ck_n,
    ddr2_cke => ddr2_cke,
    ddr2_cs_n => ddr2_cs_n,
    ddr2_dm => ddr2_dm,
    ddr2_odt => ddr2_odt,
    ddr2_dq => ddr2_dq,
    ddr2_dqs_p => ddr2_dqs_p,
    ddr2_dqs_n => ddr2_dqs_n
);

-- Capture write requests
process(wrclock)
begin
    if rising_edge(wrclock) then
        if wren = '1' then
            wr_data_reg <= data;
            wr_addr_reg <= wraddress;
            wr_en_reg <= '1';
        else
            wr_en_reg <= '0';
        end if;
    end if;
end process;

-- Capture read requests
process(rdclock)
begin
    if rising_edge(rdclock) then
        rd_addr_reg <= rdaddress;
        q <= rd_data_reg;
    end if;
end process;

-- Main state machine to handle DDR operations
process(clk_200MHz_i)
begin
    if rising_edge(clk_200MHz_i) then
        if rst_i = '1' then
            state <= IDLE;
            ram_cen <= '1';
            ram_oen <= '1';
            ram_wen <= '1';
            ram_ub <= '0';
            ram_lb <= '0';
        else
            case state is
                when IDLE =>
                    ram_cen <= '1';
                    ram_oen <= '1';
                    ram_wen <= '1';
                    
                    -- Priority to write operations
                    if wr_en_reg = '1' then
                        state <= WRITING;
                        ram_addr <= "00000000000000" & wr_addr_reg;
                        ram_dq_i <= wr_data_reg;
                        ram_cen <= '0';
                        ram_wen <= '0';
                        ram_ub <= '0';
                        ram_lb <= '0';
                    -- Then handle reads
                    elsif rd_addr_reg /= rdaddress then
                        state <= READING;
                        ram_addr <= "00000000000000" & rd_addr_reg;
                        ram_cen <= '0';
                        ram_oen <= '0';
                        ram_ub <= '0';
                        ram_lb <= '0';
                    end if;
                
                when WRITING =>
                    -- Write operation completed
                    ram_cen <= '1';
                    ram_wen <= '1';
                    state <= IDLE;
                
                when READING =>
                    -- Read operation completed
                    ram_cen <= '1';
                    ram_oen <= '1';
                    rd_data_reg <= ram_dq_o;
                    state <= IDLE;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end if;
end process;

end rtl;