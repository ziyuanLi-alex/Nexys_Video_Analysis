LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY histogram_display IS
  PORT (
    clk : IN STD_LOGIC; -- 时钟信号
    reset : IN STD_LOGIC; -- 复位信号

    -- 视频输出接口 (连接到input_selector)
    hist_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位视频地址输入 (来自VGA控制器)
    hist_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式视频数据输出 (到VGA)
    
    -- 直方图数据源接口 (连接到histogram_generator)
    hist_bin_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图bin读取地址 (0-255)
    hist_bin_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图bin数据输入 (来自histogram_generator)

    -- 直方图类型控制
    hist_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0) -- 00: Y, 01: R, 10: G, 11: B
  );
END histogram_display;

ARCHITECTURE Behavioral OF histogram_display IS
  -- 分辨率常量
  CONSTANT SCREEN_WIDTH : INTEGER := 320;
  CONSTANT SCREEN_HEIGHT : INTEGER := 240;
  
  -- 直方图全屏显示参数
  CONSTANT HIST_WIDTH : INTEGER := 320; -- 直方图宽度 (全屏宽度)
  CONSTANT HIST_HEIGHT : INTEGER := 200; -- 直方图高度 (留40像素给标题和标签)
  CONSTANT HIST_X_OFFSET : INTEGER := 0; -- X偏移量 (全屏)
  CONSTANT HIST_Y_OFFSET : INTEGER := 40; -- Y偏移量 (留顶部空间给标题)

  -- 内部信号
  SIGNAL x_pos : INTEGER RANGE 0 TO SCREEN_WIDTH-1;
  SIGNAL y_pos : INTEGER RANGE 0 TO SCREEN_HEIGHT-1;
  SIGNAL hist_x : INTEGER RANGE 0 TO SCREEN_WIDTH-1;
  SIGNAL hist_y : INTEGER RANGE 0 TO SCREEN_HEIGHT-1;
  SIGNAL in_hist_area : BOOLEAN;
  SIGNAL hist_bin : INTEGER RANGE 0 TO 255;
  SIGNAL normalized_height : INTEGER RANGE 0 TO HIST_HEIGHT;
  SIGNAL max_hist_value : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
  
  SIGNAL log_hist_value : INTEGER RANGE 0 TO HIST_HEIGHT;
  SIGNAL current_hist_value : UNSIGNED(15 DOWNTO 0);

  -- 绘制控制信号
  SIGNAL draw_bar : BOOLEAN;
  SIGNAL draw_grid : BOOLEAN;
  SIGNAL draw_axis : BOOLEAN;
  SIGNAL draw_title : BOOLEAN;

  -- 直方图颜色 (RGB565格式)
  SIGNAL hist_color : STD_LOGIC_VECTOR(15 DOWNTO 0);

  -- 地址转换函数：将线性地址转换为x,y坐标
  FUNCTION addr_to_xy(addr_val : STD_LOGIC_VECTOR(16 DOWNTO 0)) 
    RETURN INTEGER IS
    VARIABLE addr_int : INTEGER;
    VARIABLE x_coord : INTEGER;
    VARIABLE y_coord : INTEGER;
  BEGIN
    addr_int := TO_INTEGER(UNSIGNED(addr_val));
    x_coord := addr_int MOD SCREEN_WIDTH;
    y_coord := addr_int / SCREEN_WIDTH;
    -- 返回打包的坐标 (y*1000 + x 用于区分)
    RETURN y_coord * 1000 + x_coord;
  END FUNCTION;

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
  -- 地址转换 (将线性视频地址转换为x,y坐标)
  PROCESS (hist_addr)
    VARIABLE coord_pack : INTEGER;
  BEGIN
    coord_pack := addr_to_xy(hist_addr);
    y_pos <= coord_pack / 1000;
    x_pos <= coord_pack MOD 1000;
  END PROCESS;

  -- 根据直方图类型设置颜色
  WITH hist_type SELECT
    hist_color <=
    x"FFFF" WHEN "00", -- 亮度: 白色
    x"F800" WHEN "01", -- R: 红色
    x"07E0" WHEN "10", -- G: 绿色
    x"001F" WHEN "11", -- B: 蓝色
    x"FFFF" WHEN OTHERS;

  -- 计算直方图区域内的相对坐标
  hist_x <= x_pos - HIST_X_OFFSET;
  hist_y <= y_pos - HIST_Y_OFFSET;
  in_hist_area <= (hist_x >= 0) AND (hist_x < HIST_WIDTH) AND
                  (hist_y >= 0) AND (hist_y < HIST_HEIGHT);

  -- 计算当前像素对应的直方图bin索引，输出到histogram_generator
  hist_bin <= (hist_x * 256) / HIST_WIDTH WHEN in_hist_area AND (hist_x >= 0) ELSE 0;
  hist_bin_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(hist_bin, 8));

  -- 获取当前bin的直方图数据
  current_hist_value <= UNSIGNED(hist_bin_data);

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
          -- 将16位的对数范围(0-16)映射到显示高度(0-200)
          log_hist_value <= log2_approx(current_hist_value) * (HIST_HEIGHT / 16);
          IF log_hist_value > HIST_HEIGHT THEN
            log_hist_value <= HIST_HEIGHT;
          END IF;
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
               ((hist_x MOD 40 = 0) OR (hist_y MOD 25 = 0)); -- 全屏网格密度

  draw_axis <= in_hist_area AND
               ((hist_x = 0) OR (hist_y = HIST_HEIGHT - 1) OR (hist_x = HIST_WIDTH - 1));

  -- 标题区域 (屏幕顶部显示类型标识和刻度标签)
  draw_title <= (y_pos >= 5) AND (y_pos < 35) AND 
                (x_pos >= 10) AND (x_pos < 200);

  -- 根据不同条件确定输出像素颜色（按优先级排序）
  PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      -- 按优先级顺序检查绘制条件
      IF draw_title THEN
        hist_data <= hist_color; -- 标题区域用直方图颜色
      ELSIF in_hist_area THEN
        IF draw_axis THEN
          hist_data <= x"FFFF"; -- 白色轴线（最高优先级）
        ELSIF draw_grid THEN
          hist_data <= x"4208"; -- 深灰色网格
        ELSIF draw_bar THEN
          hist_data <= hist_color; -- 直方图条形颜色
        ELSE
          hist_data <= x"0000"; -- 黑色背景
        END IF;
      ELSE
        hist_data <= x"0000"; -- 显示区域外为黑色
      END IF;
    END IF;
  END PROCESS;

END Behavioral;