LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY histogram_generator IS
  PORT (
    clk : IN STD_LOGIC; -- 时钟信号
    reset : IN STD_LOGIC; -- 复位信号
    
    -- 视频输入接口
    pixel_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 输入像素数据 (RGB565格式)
    pixel_valid : IN STD_LOGIC; -- 像素有效信号
    frame_start : IN STD_LOGIC; -- 帧开始信号
    
    -- 直方图存储接口
    hist_bin_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图读取地址 (0-255)
    hist_bin_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据输出
    
    -- 控制接口
    mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0) -- 00: Y亮度直方图, 01: R直方图, 10: G直方图, 11: B直方图
  );
END histogram_generator;

ARCHITECTURE Behavioral OF histogram_generator IS
  -- 定义256个bins的直方图存储
  TYPE histogram_array IS ARRAY (0 TO 255) OF UNSIGNED(15 DOWNTO 0);
  SIGNAL hist_bins : histogram_array := (OTHERS => (OTHERS => '0'));
  
  -- 用于计算亮度的常量
  CONSTANT R_WEIGHT : INTEGER := 77; -- 0.299 * 256
  CONSTANT G_WEIGHT : INTEGER := 150; -- 0.587 * 256
  CONSTANT B_WEIGHT : INTEGER := 29; -- 0.114 * 256
  
  -- 内部信号
  SIGNAL r_value : UNSIGNED(7 DOWNTO 0);
  SIGNAL g_value : UNSIGNED(7 DOWNTO 0);
  SIGNAL b_value : UNSIGNED(7 DOWNTO 0);
  SIGNAL y_value : UNSIGNED(7 DOWNTO 0);
  SIGNAL bin_index : INTEGER RANGE 0 TO 255;
  
BEGIN
  -- 从RGB565提取RGB值
  r_value <= RESIZE(UNSIGNED(pixel_data(15 DOWNTO 11)) * 8, 8); -- 扩展到8位
  g_value <= RESIZE(UNSIGNED(pixel_data(10 DOWNTO 5)) * 4, 8);  -- 扩展到8位
  b_value <= RESIZE(UNSIGNED(pixel_data(4 DOWNTO 0)) * 8, 8);   -- 扩展到8位
  
  -- 计算亮度 Y = 0.299*R + 0.587*G + 0.114*B
  y_value <= TO_UNSIGNED((TO_INTEGER(r_value) * R_WEIGHT + 
                         TO_INTEGER(g_value) * G_WEIGHT + 
                         TO_INTEGER(b_value) * B_WEIGHT) / 256, 8);
  
  -- 根据模式选择要统计的值
  process(mode, r_value, g_value, b_value, y_value)
  begin
    case mode is
      when "00" => bin_index <= TO_INTEGER(y_value); -- 亮度直方图
      when "01" => bin_index <= TO_INTEGER(r_value); -- R通道直方图
      when "10" => bin_index <= TO_INTEGER(g_value); -- G通道直方图
      when "11" => bin_index <= TO_INTEGER(b_value); -- B通道直方图
      when others => bin_index <= TO_INTEGER(y_value);
    end case;
  end process;
  
  -- 直方图计算进程
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' or frame_start = '1' then
        -- 重置直方图
        for i in 0 to 255 loop
          hist_bins(i) <= (others => '0');
        end loop;
      elsif pixel_valid = '1' then
        -- 增加对应bin的计数
        if hist_bins(bin_index) < x"FFFF" then -- 防止溢出
          hist_bins(bin_index) <= hist_bins(bin_index) + 1;
        end if;
      end if;
      
      -- 输出请求的直方图数据
      hist_bin_data <= STD_LOGIC_VECTOR(hist_bins(to_integer(unsigned(hist_bin_addr))));
    end if;
  end process;
  
END Behavioral;