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

  SIGNAL log_hist_value : INTEGER RANGE 0 TO 255;
  SIGNAL current_hist_value : UNSIGNED(15 DOWNTO 0);

  -- 绘制控制信号
  SIGNAL draw_bar : BOOLEAN;
  SIGNAL draw_grid : BOOLEAN;
  SIGNAL draw_axis : BOOLEAN;
  -- SIGNAL draw_label : BOOLEAN;

  -- 直方图颜色 (RGB565格式)
  SIGNAL hist_color : STD_LOGIC_VECTOR(15 DOWNTO 0);
  -- SIGNAL label_color : STD_LOGIC_VECTOR(15 DOWNTO 0);

  -- 对数换算函数 (简化版本，适合硬件实现)
  FUNCTION log2_approx(value : UNSIGNED) RETURN INTEGER IS
    VARIABLE temp : UNSIGNED(15 DOWNTO 0);
    VARIABLE result : INTEGER RANGE 0 TO 16;
  BEGIN
    temp := value;
    result := 0;

    -- 简化的对数近似：找到最高位的位置
    FOR i IN 15 DOWNTO 0 LOOP
      IF temp(i) = '1' THEN
        result := i;
        EXIT;
      END IF;
    END LOOP;

    RETURN result;
  END FUNCTION;

BEGIN
  -- 根据直方图类型设置颜色
  WITH hist_type SELECT
    hist_color <=
    x"FFFF" WHEN "00", -- 亮度: 白色
    x"F800" WHEN "01", -- R: 红色
    x"07E0" WHEN "10", -- G: 绿色
    x"001F" WHEN "11", -- B: 蓝色
    x"FFFF" WHEN OTHERS;

  -- 标签颜色设置（与直方图颜色相同但稍暗）
  -- WITH hist_type SELECT
  --   label_color <=
  --   x"C618" WHEN "00", -- 亮度: 浅灰色
  --   x"C000" WHEN "01", -- R: 暗红色
  --   x"0560" WHEN "10", -- G: 暗绿色
  --   x"0012" WHEN "11", -- B: 暗蓝色
  --   x"C618" WHEN OTHERS;

  -- 计算直方图区域内的相对坐标
  hist_x <= TO_INTEGER(UNSIGNED(x_pos)) - HIST_X_OFFSET;
  hist_y <= TO_INTEGER(UNSIGNED(y_pos)) - HIST_Y_OFFSET;
  in_hist_area <= (hist_x >= 0) AND (hist_x < HIST_WIDTH) AND
    (hist_y >= 0) AND (hist_y < HIST_HEIGHT);

  -- 计算当前像素对应的直方图bin
  hist_bin <= hist_x * 256 / HIST_WIDTH WHEN in_hist_area ELSE 0;
  hist_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(hist_bin, 8));

  current_hist_value <= UNSIGNED(hist_data);

  -- 对数刻度处理进程
  PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        max_hist_value <= (OTHERS => '0');
        log_hist_value <= 0;
      ELSE
        -- 更新最大值用于参考
        IF current_hist_value > max_hist_value THEN
          max_hist_value <= current_hist_value;
        END IF;

        -- 计算对数高度
        IF current_hist_value > 0 THEN
          -- 使用对数刻度：log_height = log2(value) * scale_factor
          -- 将16位的对数范围(0-16)映射到显示高度(0-255)
          log_hist_value <= log2_approx(current_hist_value) * 16;
        ELSE
          log_hist_value <= 0;
        END IF;
      END IF;
    END IF;
  END PROCESS;

  -- 使用对数高度
  normalized_height <= log_hist_value;

  -- 确定是否绘制直方图条形
  draw_bar <= in_hist_area AND (HIST_HEIGHT - hist_y <= normalized_height);

  -- 绘制网格和轴
  draw_grid <= in_hist_area AND
    ((hist_x MOD 64 = 0) OR (hist_y MOD 32 = 0)); -- 更密的水平网格

  draw_axis <= in_hist_area AND
    ((hist_x = 0) OR (hist_y = HIST_HEIGHT - 1));

  -- 标签区域检测（在直方图区域的顶部显示类型标签）
  -- draw_label <= in_hist_area AND 
  --               (hist_y < 24) AND 
  --               (hist_x >= 8) AND (hist_x < 96); -- 标签显示区域

  -- 根据不同条件确定输出像素颜色（按优先级排序）
  PROCESS (active, in_hist_area, draw_axis, draw_grid, draw_bar, hist_color)
  BEGIN
    IF active = '1' THEN
      IF in_hist_area THEN
        -- 按优先级顺序检查绘制条件
        IF draw_axis THEN
          pixel_out <= x"FFFF"; -- 白色轴线（最高优先级）
        ELSIF draw_grid THEN
          pixel_out <= x"4208"; -- 深灰色网格（第三优先级）
        ELSIF draw_bar THEN
          pixel_out <= hist_color; -- 直方图条形颜色（第四优先级）
        ELSE
          pixel_out <= x"0000"; -- 黑色背景（最低优先级）
        END IF;
      ELSE
        pixel_out <= x"0000"; -- 显示区域外为黑色
      END IF;
    ELSE
      pixel_out <= x"0000"; -- 非活动区域为黑色
    END IF;
  END PROCESS;

END Behavioral;