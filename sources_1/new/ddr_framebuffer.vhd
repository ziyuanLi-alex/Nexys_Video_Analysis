library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_framebuffer is
port (
  -- 保持与原framebuffer相同的接口
  data : in std_logic_vector(15 downto 0);
  wraddress : in std_logic_vector(12 downto 0);
  wrclock : in std_logic;
  wren : in std_logic;
  rdaddress : in std_logic_vector(12 downto 0);
  rdclock : in std_logic;
  q : out std_logic_vector(15 downto 0);
  
  -- 新增系统接口
  clk_200MHz_i : in std_logic;
  rst_i : in std_logic;
  
  -- DDR2物理接口
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
end entity;

architecture Behavioral of ddr_framebuffer is
  -- 内部信号声明
  signal ram_a : std_logic_vector(26 downto 0);
  signal ram_dq_i : std_logic_vector(15 downto 0);
  signal ram_dq_o : std_logic_vector(15 downto 0);
  signal ram_cen : std_logic;
  signal ram_oen : std_logic;
  signal ram_wen : std_logic;
  signal ram_ub : std_logic;
  signal ram_lb : std_logic;
  
  -- 状态机信号
  type state_type is (IDLE, READ_OP, WRITE_OP, WAIT_READ, WAIT_WRITE);
  signal current_state, next_state : state_type;
  
  -- 读写状态信号
  signal read_pending : std_logic := '0';
  signal write_pending : std_logic := '0';
  signal read_addr_reg : std_logic_vector(12 downto 0);
  signal write_addr_reg : std_logic_vector(12 downto 0);
  signal write_data_reg : std_logic_vector(15 downto 0);

begin
  -- RAM2DDR实例化
  Inst_RAM2DDR: entity work.ram2ddr
  port map (
    clk_200MHz_i => clk_200MHz_i,
    rst_i => rst_i,
    device_temp_i => x"000", -- 可连接温度传感器或设为0
    
    -- RAM接口连接到内部信号
    ram_a => ram_a,
    ram_dq_i => ram_dq_i,
    ram_dq_o => ram_dq_o,
    ram_cen => ram_cen,
    ram_oen => ram_oen,
    ram_wen => ram_wen,
    ram_ub => ram_ub,
    ram_lb => ram_lb,
    
    -- DDR2物理接口直接连接
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
  
  -- 写请求处理
  process(wrclock)
  begin
    if rising_edge(wrclock) then
      if rst_i = '1' then
        write_pending <= '0';
      elsif wren = '1' then
        write_pending <= '1';
        write_addr_reg <= wraddress;
        write_data_reg <= data;
      elsif current_state = WRITE_OP then
        write_pending <= '0';
      end if;
    end if;
  end process;
  
  -- 读请求处理
  process(rdclock)
  begin
    if rising_edge(rdclock) then
      if rst_i = '1' then
        read_pending <= '0';
      else
        read_pending <= '1';
        read_addr_reg <= rdaddress;
      end if;
    end if;
  end process;
  
  -- 状态机时序逻辑
  process(clk_200MHz_i)
  begin
    if rising_edge(clk_200MHz_i) then
      if rst_i = '1' then
        current_state <= IDLE;
      else
        current_state <= next_state;
      end if;
    end if;
  end process;
  
  -- 状态机组合逻辑
  process(current_state, read_pending, write_pending)
  begin
    next_state <= current_state;
    
    case current_state is
      when IDLE =>
        if write_pending = '1' then
          next_state <= WRITE_OP;
        elsif read_pending = '1' then
          next_state <= READ_OP;
        end if;
        
      when WRITE_OP =>
        next_state <= WAIT_WRITE;
        
      when READ_OP =>
        next_state <= WAIT_READ;
        
      when WAIT_WRITE =>
        next_state <= IDLE;
        
      when WAIT_READ =>
        next_state <= IDLE;
        
      when others =>
        next_state <= IDLE;
    end case;
  end process;
  
  -- RAM2DDR控制信号生成
  process(clk_200MHz_i)
  begin
    if rising_edge(clk_200MHz_i) then
      -- 默认值
      ram_cen <= '1';
      ram_oen <= '1';
      ram_wen <= '1';
      ram_ub <= '0';
      ram_lb <= '0';
      
      case current_state is
        when WRITE_OP =>
          -- 写操作设置
          ram_a <= "00000000000000" & write_addr_reg;
          ram_dq_i <= write_data_reg;
          ram_cen <= '0';
          ram_wen <= '0';
          ram_ub <= '0'; -- 启用高字节
          ram_lb <= '0'; -- 启用低字节
          
        when READ_OP =>
          -- 读操作设置
          ram_a <= "00000000000000" & read_addr_reg;
          ram_cen <= '0';
          ram_oen <= '0';
          ram_ub <= '0'; -- 启用高字节
          ram_lb <= '0'; -- 启用低字节
          
        when WAIT_READ =>
          -- 在读等待状态保持读取信号
          ram_cen <= '0';
          ram_oen <= '0';
          ram_ub <= '0';
          ram_lb <= '0';
          
        when others =>
          -- 其他状态保持高阻态
          ram_cen <= '1';
          ram_oen <= '1';
          ram_wen <= '1';
      end case;
    end if;
  end process;
  
  -- 输出数据连接
  q <= ram_dq_o;
  
end Behavioral;