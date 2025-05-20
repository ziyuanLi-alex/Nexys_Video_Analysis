library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity histogram_generator is
  Port ( 
    pclk : in STD_LOGIC;
    vsync : in STD_LOGIC;
    pixel_data : in STD_LOGIC_VECTOR(15 downto 0);
    pixel_valid : in STD_LOGIC;
    vga_clk : in STD_LOGIC;
    vga_x : in STD_LOGIC_VECTOR(9 downto 0);
    vga_y : in STD_LOGIC_VECTOR(9 downto 0);
    hist_pixel : out STD_LOGIC_VECTOR(11 downto 0)  -- R(4),G(4),B(4)
  );
end histogram_generator;

architecture Behavioral of histogram_generator is
  -- 简化直方图，只使用16个亮度级别
  type hist_array is array(0 to 15) of unsigned(8 downto 0);
  signal histogram : hist_array := (others => (others => '0'));
  signal prev_vsync : STD_LOGIC := '1';
  
  -- 缩放因子和网格颜色
  constant BAR_WIDTH : integer := 40;  -- 每个柱子宽度
  constant GRID_COLOR : STD_LOGIC_VECTOR(11 downto 0) := X"555";
  constant BAR_COLOR : STD_LOGIC_VECTOR(11 downto 0) := X"FF0";
begin
  -- 亮度计算和直方图更新
  process(pclk)
    variable brightness : unsigned(3 downto 0);
    variable r, g, b : unsigned(4 downto 0);
  begin
    if rising_edge(pclk) then
      -- 检测新帧
      prev_vsync <= vsync;
      
      if prev_vsync = '0' and vsync = '1' then
        -- 新帧开始，重置直方图
        histogram <= (others => (others => '0'));
      elsif pixel_valid = '1' then
        -- 从RGB565计算简化亮度
        r := unsigned('0' & pixel_data(15 downto 12));
        g := unsigned('0' & pixel_data(10 downto 7));
        b := unsigned('0' & pixel_data(4 downto 1));
        
        -- 简化亮度计算：(r+g+b)/3 缩放到0-15
        brightness := resize(r+g+b, 5)(4 downto 1);
        
        -- 更新直方图
        if histogram(to_integer(brightness)) < 400 then
          histogram(to_integer(brightness)) <= histogram(to_integer(brightness)) + 1;
        end if;
      end if;
    end if;
  end process;
  
  -- 直方图显示生成
  process(vga_clk)
    variable hist_index : integer;
    variable bar_height : integer;
  begin
    if rising_edge(vga_clk) then
      -- 默认背景色
      hist_pixel <= X"000";
      
      -- 计算当前像素对应哪个柱子
      hist_index := to_integer(unsigned(vga_x)) / BAR_WIDTH;
      
      if hist_index < 16 then
        -- 获取柱高
        bar_height := to_integer(histogram(hist_index));
        
        if to_integer(unsigned(vga_y)) > (480 - bar_height) then
          -- 绘制柱状图
          hist_pixel <= BAR_COLOR;
        end if;
      end if;
      
      -- 绘制网格
      if (to_integer(unsigned(vga_y)) mod 40 = 0) or 
         (to_integer(unsigned(vga_x)) mod BAR_WIDTH = 0) then
        hist_pixel <= GRID_COLOR;
      end if;
    end if;
  end process;
end Behavioral;