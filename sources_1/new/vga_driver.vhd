LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY vga_driver IS
    GENERIC (
        -- VGA时序参数 (默认640x480 @ 60Hz)
        H_VISIBLE_AREA : INTEGER := 640;
        H_FRONT_PORCH  : INTEGER := 16;
        H_SYNC_PULSE   : INTEGER := 96;
        H_BACK_PORCH   : INTEGER := 48;
        H_WHOLE_LINE   : INTEGER := 800;
        V_VISIBLE_AREA : INTEGER := 480;
        V_FRONT_PORCH  : INTEGER := 10;
        V_SYNC_PULSE   : INTEGER := 2;
        V_BACK_PORCH   : INTEGER := 33;
        V_WHOLE_FRAME  : INTEGER := 525;
        
        -- 帧缓冲区尺寸 - 已更新为320x240
        FB_WIDTH       : INTEGER := 320;
        FB_HEIGHT      : INTEGER := 240;
        
        -- 颜色格式 (默认RGB565)
        RED_BITS       : INTEGER := 5;
        GREEN_BITS     : INTEGER := 6;
        BLUE_BITS      : INTEGER := 5;
        
        -- 输出颜色深度 (VGA输出每种颜色的位数)
        OUTPUT_BITS    : INTEGER := 4
    );
    PORT (
        -- 时钟和复位
        clk            : IN  STD_LOGIC;  -- 像素时钟
        rst            : IN  STD_LOGIC;  -- 复位信号
        
        -- 帧缓冲区接口 - 已更新为17位地址宽度
        fb_addr        : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);  -- 对应320x240 = 76800像素
        fb_data        : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);  -- RGB565像素数据
        
        -- VGA输出
        hsync          : OUT STD_LOGIC;
        vsync          : OUT STD_LOGIC;
        red            : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        green          : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        blue           : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        
        -- 显示分辨率选择 (可选，用于未来扩展)
        resolution_sel : IN  STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"  -- 00: 640x480, 01: 320x240, 10: 800x600
    );
END ENTITY vga_driver;

ARCHITECTURE Behavioral OF vga_driver IS
    -- 水平和垂直计数器
    SIGNAL h_count    : INTEGER RANGE 0 TO H_WHOLE_LINE-1 := 0;
    SIGNAL v_count    : INTEGER RANGE 0 TO V_WHOLE_FRAME-1 := 0;
    
    -- 显示活动区域标志
    SIGNAL h_active   : STD_LOGIC := '0';
    SIGNAL v_active   : STD_LOGIC := '0';
    SIGNAL display_on : STD_LOGIC := '0';
    
    -- 显示区域内的像素坐标
    SIGNAL x_pos      : INTEGER RANGE 0 TO H_VISIBLE_AREA-1 := 0;
    SIGNAL y_pos      : INTEGER RANGE 0 TO V_VISIBLE_AREA-1 := 0;
    
    -- 帧缓冲区地址计算
    SIGNAL fb_x       : INTEGER RANGE 0 TO FB_WIDTH-1 := 0;
    SIGNAL fb_y       : INTEGER RANGE 0 TO FB_HEIGHT-1 := 0;
    SIGNAL fb_index   : INTEGER RANGE 0 TO FB_WIDTH*FB_HEIGHT-1 := 0;
    
    -- 颜色分量提取
    SIGNAL r_data     : STD_LOGIC_VECTOR(RED_BITS-1 DOWNTO 0);
    SIGNAL g_data     : STD_LOGIC_VECTOR(GREEN_BITS-1 DOWNTO 0);
    SIGNAL b_data     : STD_LOGIC_VECTOR(BLUE_BITS-1 DOWNTO 0);
    
    -- 缩放因子 - 根据新的帧缓冲区分辨率更新
    SIGNAL scale_x    : INTEGER := 2;  -- 640/320 = 2
    SIGNAL scale_y    : INTEGER := 2;  -- 480/240 = 2
    
    -- 预计算地址流水线
    SIGNAL addr_valid : STD_LOGIC := '0';
    SIGNAL fb_addr_reg : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
    
BEGIN
    -- 根据分辨率选择更新缩放因子
    resolution_process: PROCESS(resolution_sel)
    BEGIN
        CASE resolution_sel IS
            WHEN "00" =>  -- 640x480显示，320x240缓冲区
                scale_x <= 2;  -- 640/320
                scale_y <= 2;  -- 480/240
            WHEN "01" =>  -- 320x240显示，320x240缓冲区 (1:1映射)
                scale_x <= 1;
                scale_y <= 1;
            WHEN "10" =>  -- 800x600显示，320x240缓冲区
                scale_x <= 2;  -- 将像素复制更多次以填充更大的显示器
                scale_y <= 2;
            WHEN OTHERS =>
                scale_x <= 2;
                scale_y <= 2;
        END CASE;
    END PROCESS resolution_process;
    
    -- VGA时序生成进程
    vga_timing: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                h_count <= 0;
                v_count <= 0;
                hsync <= '1';  -- 同步脉冲为低电平有效
                vsync <= '1';
                h_active <= '0';
                v_active <= '0';
                display_on <= '0';
            ELSE
                -- 水平计数器
                IF h_count < H_WHOLE_LINE-1 THEN
                    h_count <= h_count + 1;
                ELSE
                    h_count <= 0;
                    -- 垂直计数器
                    IF v_count < V_WHOLE_FRAME-1 THEN
                        v_count <= v_count + 1;
                    ELSE
                        v_count <= 0;
                    END IF;
                END IF;
                
                -- 生成HSYNC
                IF (h_count >= H_VISIBLE_AREA + H_FRONT_PORCH) AND 
                   (h_count < H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE) THEN
                    hsync <= '0';  -- 低电平有效同步脉冲
                ELSE
                    hsync <= '1';
                END IF;
                
                -- 生成VSYNC
                IF (v_count >= V_VISIBLE_AREA + V_FRONT_PORCH) AND 
                   (v_count < V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE) THEN
                    vsync <= '0';  -- 低电平有效同步脉冲
                ELSE
                    vsync <= '1';
                END IF;
                
                -- 确定活动显示区域
                IF h_count < H_VISIBLE_AREA THEN
                    h_active <= '1';
                    x_pos <= h_count;
                ELSE
                    h_active <= '0';
                END IF;
                
                IF v_count < V_VISIBLE_AREA THEN
                    v_active <= '1';
                    y_pos <= v_count;
                ELSE
                    v_active <= '0';
                END IF;
                
                display_on <= h_active AND v_active;
            END IF;
        END IF;
    END PROCESS vga_timing;
    
    -- 帧缓冲区地址计算 - 单独进程确保正确的时序
    address_calc: PROCESS(clk)
        VARIABLE scaled_x : INTEGER;
        VARIABLE scaled_y : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            IF h_active = '1' AND v_active = '1' THEN
                -- 根据选择的缩放模式计算帧缓冲区坐标
                IF scale_x = 1 THEN
                    -- 1:1映射模式 (无缩放)
                    scaled_x := x_pos;
                    -- 确保不超出帧缓冲区边界
                    IF scaled_x >= FB_WIDTH THEN
                        scaled_x := FB_WIDTH - 1;
                    END IF;
                ELSE
                    -- 缩放模式
                    scaled_x := x_pos / scale_x;
                    -- 确保不超出帧缓冲区边界
                    IF scaled_x >= FB_WIDTH THEN
                        scaled_x := FB_WIDTH - 1;
                    END IF;
                END IF;
                
                IF scale_y = 1 THEN
                    -- 1:1映射模式 (无缩放)
                    scaled_y := y_pos;
                    -- 确保不超出帧缓冲区边界
                    IF scaled_y >= FB_HEIGHT THEN
                        scaled_y := FB_HEIGHT - 1;
                    END IF;
                ELSE
                    -- 缩放模式
                    scaled_y := y_pos / scale_y;
                    -- 确保不超出帧缓冲区边界
                    IF scaled_y >= FB_HEIGHT THEN
                        scaled_y := FB_HEIGHT - 1;
                    END IF;
                END IF;
                
                -- 计算帧缓冲区的线性地址
                fb_index <= scaled_y * FB_WIDTH + scaled_x;
                addr_valid <= '1';
            ELSE
                addr_valid <= '0';
            END IF;
            
            -- 寄存地址确保稳定输出
            fb_addr_reg <= STD_LOGIC_VECTOR(TO_UNSIGNED(fb_index, 17));
        END IF;
    END PROCESS address_calc;
    
    -- 输出计算的地址
    fb_addr <= fb_addr_reg;
    
    -- 颜色输出进程
    color_output: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF display_on = '1' THEN
                -- 从RGB565像素数据中提取颜色分量
                r_data <= fb_data(15 DOWNTO 11);  -- 红色5位
                g_data <= fb_data(10 DOWNTO 5);   -- 绿色6位
                b_data <= fb_data(4 DOWNTO 0);    -- 蓝色5位
                
                -- 输出适当位宽转换的颜色
                -- 对于4位输出 (取最高有效位)
                red   <= r_data(RED_BITS-1 DOWNTO RED_BITS-OUTPUT_BITS);
                green <= g_data(GREEN_BITS-1 DOWNTO GREEN_BITS-OUTPUT_BITS);
                blue  <= b_data(BLUE_BITS-1 DOWNTO BLUE_BITS-OUTPUT_BITS);
            ELSE
                -- 在可见区域外输出黑色
                red   <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue  <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS color_output;
    
END Behavioral;