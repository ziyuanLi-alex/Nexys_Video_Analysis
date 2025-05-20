library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_framebuffer is
port (
    -- Framebuffer interface
    data : in std_logic_vector(15 downto 0);
    wraddress : in std_logic_vector(12 downto 0);
    wrclock : in std_logic;
    wren : in std_logic;
    rdaddress : in std_logic_vector(12 downto 0);
    rdclock : in std_logic;
    q : out std_logic_vector(15 downto 0);

    -- DDR interface
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

component Ram2Ddr is
   port (
      clk_200MHz_i : in std_logic;
      rst_i : in std_logic;
      device_temp_i : in std_logic_vector(11 downto 0);
      
      ram_a : in std_logic_vector(26 downto 0);
      ram_dq_i : in std_logic_vector(15 downto 0);
      ram_dq_o : out std_logic_vector(15 downto 0);
      ram_cen : in std_logic;
      ram_oen : in std_logic;
      ram_wen : in std_logic;
      ram_ub : in std_logic;
      ram_lb : in std_logic;
      
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

-- Constants
constant CACHE_SIZE : integer := 32;
constant CACHE_ADDR_BITS : integer := 5; -- 2^5 = 32
constant CACHE_LINE_BITS : integer := 8; -- Line address width

-- Simple state machine
type state_type is (IDLE, READ_PREP, READING, WRITE_PREP, WRITING);
signal state : state_type := IDLE;

-- Line cache
type cache_type is array(0 to CACHE_SIZE-1) of std_logic_vector(15 downto 0);
signal cache_data : cache_type;
signal cache_line : std_logic_vector(CACHE_LINE_BITS-1 downto 0) := (others => '1');
signal cache_valid : std_logic := '0';

-- Write domain signals
signal wr_data_reg : std_logic_vector(15 downto 0);
signal wr_addr_reg : std_logic_vector(12 downto 0);
signal wr_request_flag : std_logic := '0';

-- Read domain signals
signal rd_addr_reg : std_logic_vector(12 downto 0);
signal rd_line : std_logic_vector(CACHE_LINE_BITS-1 downto 0);
signal rd_pixel : std_logic_vector(CACHE_ADDR_BITS-1 downto 0);
signal rd_data_out : std_logic_vector(15 downto 0);

-- Clock domain crossing signals
signal wr_request_sync1 : std_logic := '0';
signal wr_request_sync2 : std_logic := '0';
signal wr_pending : std_logic := '0';
signal rd_addr_sync1 : std_logic_vector(12 downto 0);
signal rd_addr_sync2 : std_logic_vector(12 downto 0);
signal rd_line_needed : std_logic_vector(CACHE_LINE_BITS-1 downto 0);
signal rd_line_changed : std_logic := '0';

-- DDR controller signals
signal ram_addr : std_logic_vector(26 downto 0);
signal ram_data_in : std_logic_vector(15 downto 0);
signal ram_data_out : std_logic_vector(15 downto 0);
signal ram_cen : std_logic := '1';  -- Active low
signal ram_oen : std_logic := '1';  -- Active low
signal ram_wen : std_logic := '1';  -- Active low
signal ram_ub : std_logic := '0';   -- Upper byte enable (active low)
signal ram_lb : std_logic := '0';   -- Lower byte enable (active low)

-- Buffer filling control
signal cache_index : integer range 0 to CACHE_SIZE-1 := 0;

begin

-- RAM2DDR instance
ram2ddr_inst : Ram2Ddr
port map (
    clk_200MHz_i => clk_200MHz_i,
    rst_i => rst_i,
    device_temp_i => device_temp_i,
    
    ram_a => ram_addr,
    ram_dq_i => ram_data_in,
    ram_dq_o => ram_data_out,
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

-- Extract address components
rd_line <= rdaddress(12 downto 12-CACHE_LINE_BITS+1);
rd_pixel <= rdaddress(CACHE_ADDR_BITS-1 downto 0);

-- Register write requests in write clock domain
process(wrclock)
begin
    if rising_edge(wrclock) then
        wr_request_flag <= '0';  -- Default value
        if wren = '1' then
            wr_data_reg <= data;
            wr_addr_reg <= wraddress;
            wr_request_flag <= '1';
        end if;
    end if;
end process;

-- Handle read requests in read clock domain
process(rdclock)
begin
    if rising_edge(rdclock) then
        rd_addr_reg <= rdaddress;
        
        -- Output data from cache if valid
        if cache_valid = '1' and rd_line = cache_line then
            q <= cache_data(to_integer(unsigned(rd_pixel)));
        else
            q <= (others => '0');
        end if;
    end if;
end process;

-- Main DDR controller in 200MHz domain
process(clk_200MHz_i)
begin
    if rising_edge(clk_200MHz_i) then
        if rst_i = '1' then
            state <= IDLE;
            ram_cen <= '1';
            ram_oen <= '1';
            ram_wen <= '1';
            cache_valid <= '0';
            cache_line <= (others => '1');
            wr_pending <= '0';
            rd_line_changed <= '0';
            cache_index <= 0;
        else
            -- Synchronize signals from other clock domains
            wr_request_sync1 <= wr_request_flag;
            wr_request_sync2 <= wr_request_sync1;
            rd_addr_sync1 <= rd_addr_reg;
            rd_addr_sync2 <= rd_addr_sync1;
            
            -- Detect new write request
            if wr_request_sync2 = '1' and wr_pending = '0' then
                wr_pending <= '1';
            end if;
            
            -- Detect new line request
            rd_line_needed <= rd_addr_sync2(12 downto 12-CACHE_LINE_BITS+1);
            if rd_line_needed /= cache_line then
                rd_line_changed <= '1';
                cache_valid <= '0';
            end if;
            
            -- Default values
            ram_cen <= '1';
            ram_oen <= '1';
            ram_wen <= '1';
            
            -- State machine
            case state is
                when IDLE =>
                    -- Handle read line changes with higher priority
                    if rd_line_changed = '1' then
                        state <= READ_PREP;
                        cache_index <= 0;
                        cache_line <= rd_line_needed;
                        rd_line_changed <= '0';
                    -- Handle pending writes
                    elsif wr_pending = '1' then
                        state <= WRITE_PREP;
                    end if;
                    
                when READ_PREP =>
                    -- Calculate RAM address for start of line
                    ram_addr(26 downto CACHE_LINE_BITS+CACHE_ADDR_BITS) <= (others => '0');
                    ram_addr(CACHE_LINE_BITS+CACHE_ADDR_BITS-1 downto CACHE_ADDR_BITS) <= cache_line;
                    ram_addr(CACHE_ADDR_BITS-1 downto 0) <= std_logic_vector(to_unsigned(0, CACHE_ADDR_BITS));
                    
                    -- Start read cycle
                    ram_cen <= '0';
                    ram_oen <= '0';
                    state <= READING;
                    
                when READING =>
                    -- Store read data to cache
                    cache_data(cache_index) <= ram_data_out;
                    
                    -- Check if we completed filling the buffer
                    if cache_index = CACHE_SIZE-1 then
                        cache_valid <= '1';
                        state <= IDLE;
                    else
                        -- Prepare to read next position
                        cache_index <= cache_index + 1;
                        ram_addr(CACHE_ADDR_BITS-1 downto 0) <= std_logic_vector(to_unsigned(cache_index + 1, CACHE_ADDR_BITS));
                        ram_cen <= '0';
                        ram_oen <= '0';
                    end if;
                    
                when WRITE_PREP =>
                    -- Set up write address
                    ram_addr(26 downto 13) <= (others => '0');
                    ram_addr(12 downto 0) <= wr_addr_reg;
                    ram_data_in <= wr_data_reg;
                    
                    -- Start write cycle
                    ram_cen <= '0';
                    ram_wen <= '0';
                    state <= WRITING;
                    
                when WRITING =>
                    -- Complete write cycle
                    wr_pending <= '0';
                    state <= IDLE;
                    
                    -- Update cache if writing to current line
                    if wr_addr_reg(12 downto 12-CACHE_LINE_BITS+1) = cache_line and cache_valid = '1' then
                        cache_data(to_integer(unsigned(wr_addr_reg(CACHE_ADDR_BITS-1 downto 0)))) <= wr_data_reg;
                    end if;
            end case;
        end if;
    end if;
end process;

end rtl;