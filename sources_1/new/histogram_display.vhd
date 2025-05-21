LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY histogram_display IS
  PORT (
    clk : IN STD_LOGIC; -- 时钟信号
    reset : IN STD_LOGIC; -- 复位信号
    
    -- VGA位置输入
    x_pos : IN STD_LOGIC_VECTOR(9 DOWNTO 0); -- X坐标 (0-639)
    y_pos : IN STD_LOGIC_VECTOR(9 DOWNTO 0); -- Y坐标 (0-479)
    active : IN STD_LOGIC; -- 显示区域有效信号
    
    -- 直方图数据输入
    hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据
    
    -- 直方图类型控制
    hist_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- 00: Y, 01: R, 10: G, 11: B
    
    -- 像素输出
    pixel_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式输出像素
    hist_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) -- 直方图读取地址
  );
END histogram_display;

ARCHITECTURE Behavioral OF histogram_display IS
  -- 常量定义
  CONSTANT HIST_WIDTH : INTEGER := 512; -- 直方图宽度
  CONSTANT HIST_HEIGHT : INTEGER := 256; -- 直方图高度
  CONSTANT HIST_X_OFFSET : INTEGER := 64; -- X偏移量
  CONSTANT HIST_Y_OFFSET : INTEGER := 112; -- Y偏移量
  
  -- 内部信号
  SIGNAL hist_x : INTEGER RANGE 0 TO 639;
  SIGNAL hist_y : INTEGER RANGE 0 TO 479;
  SIGNAL in_hist_area : BOOLEAN;
  SIGNAL hist_bin : INTEGER RANGE 0 TO 255;
  SIGNAL normalized_height : INTEGER RANGE 0 TO 255;
  SIGNAL max_hist_value : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
  
  -- 绘制控制信号
  SIGNAL draw_bar : BOOLEAN;
  SIGNAL draw_grid : BOOLEAN;
  SIGNAL draw_axis : BOOLEAN;
  
  -- 直方图颜色 (RGB565格式)
  SIGNAL hist_color : STD_LOGIC_VECTOR(15 DOWNTO 0);

    -- 添加标签显示
  SIGNAL draw_label : BOOLEAN;
  SIGNAL label_text : STD_LOGIC_VECTOR(15 DOWNTO 0);
  
BEGIN
  -- 根据直方图类型设置颜色
  WITH hist_type SELECT
    hist_color <=
      x"FFFF" WHEN "00", -- 亮度: 白色
      x"F800" WHEN "01", -- R: 红色
      x"07E0" WHEN "10", -- G: 绿色
      x"001F" WHEN "11", -- B: 蓝色
      x"FFFF" WHEN OTHERS;
  WITH hist_type SELECT
    label_text <=
      x"5920" WHEN "00", -- "Y "
      x"5220" WHEN "01", -- "R "
      x"4720" WHEN "10", -- "G "
      x"4220" WHEN "11", -- "B "
      x"5920" WHEN OTHERS;

  
  -- 计算直方图区域内的相对坐标
  hist_x <= TO_INTEGER(UNSIGNED(x_pos)) - HIST_X_OFFSET;
  hist_y <= TO_INTEGER(UNSIGNED(y_pos)) - HIST_Y_OFFSET;
  in_hist_area <= (hist_x >= 0) AND (hist_x < HIST_WIDTH) AND 
                 (hist_y >= 0) AND (hist_y < HIST_HEIGHT);
  
  -- 计算当前像素对应的直方图bin
  hist_bin <= hist_x * 256 / HIST_WIDTH WHEN in_hist_area ELSE 0;
  hist_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(hist_bin, 8));
  
  -- 归一化直方图高度 (动态调整以适应显示区域)
  process(clk)
  begin
    if rising_edge(clk) then
      -- 找出最大值用于归一化
      if UNSIGNED(hist_data) > max_hist_value then
        max_hist_value <= UNSIGNED(hist_data);
      end if;
      
      -- 重置最大值
      if reset = '1' then
        max_hist_value <= (OTHERS => '0');
      end if;
    end if;
  end process;
  
  -- 计算归一化高度
  normalized_height <= TO_INTEGER(UNSIGNED(hist_data) * 256 / max_hist_value) WHEN max_hist_value > 0 ELSE 0;
  
  -- 确定是否绘制直方图条形
  draw_bar <= in_hist_area AND (HIST_HEIGHT - hist_y <= normalized_height);
  
  -- 绘制网格和轴
  draw_grid <= in_hist_area AND 
              ((hist_x MOD 64 = 0) OR (hist_y MOD 64 = 0));
  draw_axis <= in_hist_area AND 
              ((hist_x = 0) OR (hist_y = HIST_HEIGHT - 1));
  

  -- 判断是否需要绘制标签
  draw_label <= (hist_y < 32) AND (hist_x < 128);
  
  -- 根据不同条件确定输出像素颜色
  process(active, in_hist_area, draw_bar, draw_grid, draw_axis, draw_label, hist_color, label_text)
  begin
    if active = '1' then
      if in_hist_area then
        if draw_axis then
          pixel_out <= x"FFFF"; -- 白色轴线
        elsif draw_grid then
          pixel_out <= x"8410"; -- 灰色网格
        elsif draw_bar then
          pixel_out <= hist_color; -- 根据直方图类型显示不同颜色
        else
          pixel_out <= x"0000"; -- 黑色背景
        end if;
      else
        pixel_out <= x"0000"; -- 显示区域外为黑色
      end if;
    else
      pixel_out <= x"0000"; -- 非活动区域为黑色
    end if;
  end process;
  
END Behavioral;