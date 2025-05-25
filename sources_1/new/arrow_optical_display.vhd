----------------------------------------------------------------------------------
-- 箭头式光流显示系统
-- 
-- 功能：
-- 1. 在原始图像上叠加小箭头显示光流矢量
-- 2. 支持多种箭头样式和颜色
-- 3. 可调节显示密度和阈值
-- 4. 实时320x240显示，箭头网格可配置
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY arrow_optical_flow_display IS
    GENERIC (
        IMAGE_WIDTH : INTEGER := 320;
        IMAGE_HEIGHT : INTEGER := 240;
        ARROW_GRID_X : INTEGER := 16;     -- 水平方向箭头数量 (20像素间距)
        ARROW_GRID_Y : INTEGER := 12;     -- 垂直方向箭头数量 (20像素间距)
        ARROW_SIZE : INTEGER := 8;        -- 箭头长度 (像素)
        MIN_THRESHOLD : INTEGER := 10     -- 最小显示阈值
    );
    PORT (
        -- 时钟和控制
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        
        -- 原始图像输入
        bg_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
        bg_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        bg_valid : IN STD_LOGIC;
        
        -- 光流矢量输入 (来自矢量计算模块)
        vector_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- 192个矢量 (16x12)
        vector_x : IN SIGNED(7 DOWNTO 0);
        vector_y : IN SIGNED(7 DOWNTO 0);
        vector_valid : IN STD_LOGIC;
        
        -- VGA显示接口
        vga_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        vga_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        vga_pixel : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        vga_valid : OUT STD_LOGIC;
        
        -- 控制参数
        display_mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- 00:原图 01:箭头 10:叠加 11:纯矢量
        arrow_color : IN STD_LOGIC_VECTOR(2 DOWNTO 0);   -- 箭头颜色选择
        motion_threshold : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 运动阈值
        
        -- 状态输出
        arrow_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)   -- 当前显示的箭头数量
    );
END arrow_optical_flow_display;

ARCHITECTURE rtl OF arrow_optical_flow_display IS

    -- 箭头图案存储器 (8x8像素的箭头模板)
    TYPE arrow_pattern_type IS ARRAY (0 TO 7, 0 TO 7) OF STD_LOGIC;
    
    -- 8方向箭头模板
    CONSTANT ARROW_RIGHT : arrow_pattern_type := (
        "00000000",
        "00001000", 
        "00001100",
        "11111110",  -- 主干
        "11111110",  -- 主干
        "00001100",
        "00001000",
        "00000000"
    );
    
    CONSTANT ARROW_LEFT : arrow_pattern_type := (
        "00000000",
        "00010000",
        "00110000", 
        "01111111",  -- 主干
        "01111111",  -- 主干
        "00110000",
        "00010000",
        "00000000"
    );
    
    CONSTANT ARROW_UP : arrow_pattern_type := (
        "00011000",
        "00111100",
        "01111110",
        "00011000",
        "00011000",
        "00011000",
        "00011000",
        "00000000"
    );
    
    CONSTANT ARROW_DOWN : arrow_pattern_type := (
        "00000000",
        "00011000",
        "00011000",
        "00011000",
        "00011000",
        "01111110",
        "00111100",
        "00011000"
    );

    -- 矢量存储器
    TYPE vector_memory_type IS ARRAY (0 TO ARROW_GRID_X*ARROW_GRID_Y-1) OF SIGNED(7 DOWNTO 0);
    SIGNAL stored_vector_x : vector_memory_type := (OTHERS => (OTHERS => '0'));
    SIGNAL stored_vector_y : vector_memory_type := (OTHERS => (OTHERS => '0'));
    SIGNAL vector_magnitude : vector_memory_type := (OTHERS => (OTHERS => '0'));
    signal vector_addr_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- VGA坐标处理
    SIGNAL vga_x_int : INTEGER RANGE 0 TO IMAGE_WIDTH-1;
    SIGNAL vga_y_int : INTEGER RANGE 0 TO IMAGE_HEIGHT-1;
    
    -- 当前处理的箭头
    SIGNAL current_arrow_x : INTEGER RANGE 0 TO ARROW_GRID_X-1;
    SIGNAL current_arrow_y : INTEGER RANGE 0 TO ARROW_GRID_Y-1;
    SIGNAL current_arrow_index : INTEGER RANGE 0 TO ARROW_GRID_X*ARROW_GRID_Y-1;
    
    -- 箭头渲染信号
    SIGNAL arrow_pixel_x : INTEGER RANGE 0 TO 7;
    SIGNAL arrow_pixel_y : INTEGER RANGE 0 TO 7;
    SIGNAL arrow_center_x : INTEGER RANGE 0 TO IMAGE_WIDTH-1;
    SIGNAL arrow_center_y : INTEGER RANGE 0 TO IMAGE_HEIGHT-1;
    SIGNAL arrow_active : STD_LOGIC;
    SIGNAL arrow_pixel_on : STD_LOGIC;
    
    -- 颜色定义
    TYPE color_array IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    CONSTANT ARROW_COLORS : color_array := (
        x"F800",  -- 红色
        x"07E0",  -- 绿色  
        x"001F",  -- 蓝色
        x"FFE0",  -- 黄色
        x"F81F",  -- 紫色
        x"07FF",  -- 青色
        x"FFFF",  -- 白色
        x"0000"   -- 黑色
    );
    
    SIGNAL selected_arrow_color : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL background_pixel : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL final_pixel : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    SIGNAL active_arrow_count : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');

    -- 计算矢量幅度
    FUNCTION compute_magnitude(vx, vy : SIGNED(7 DOWNTO 0)) RETURN SIGNED IS
        VARIABLE abs_x, abs_y : UNSIGNED(7 DOWNTO 0);
        VARIABLE magnitude : UNSIGNED(7 DOWNTO 0);
    BEGIN
        abs_x := UNSIGNED(abs(vx));
        abs_y := UNSIGNED(abs(vy));
        magnitude := abs_x + abs_y;  -- Manhattan距离
        RETURN SIGNED(magnitude);
    END FUNCTION;

    -- 选择箭头模板
    FUNCTION get_arrow_pattern(vx, vy : SIGNED(7 DOWNTO 0); px, py : INTEGER) 
        RETURN STD_LOGIC IS
        VARIABLE pattern_bit : STD_LOGIC := '0';
    BEGIN
        -- 根据矢量方向选择箭头模板
        IF abs(vx) > abs(vy) THEN
            IF vx > 0 THEN
                pattern_bit := ARROW_RIGHT(py, px);  -- 向右
            ELSE
                pattern_bit := ARROW_LEFT(py, px);   -- 向左
            END IF;
        ELSE
            IF vy > 0 THEN
                pattern_bit := ARROW_DOWN(py, px);   -- 向下
            ELSE
                pattern_bit := ARROW_UP(py, px);     -- 向上
            END IF;
        END IF;
        RETURN pattern_bit;
    END FUNCTION;

BEGIN

    -- VGA坐标转换
    vga_x_int <= TO_INTEGER(UNSIGNED(vga_x)) WHEN UNSIGNED(vga_x) < IMAGE_WIDTH 
                 ELSE IMAGE_WIDTH-1;
    vga_y_int <= TO_INTEGER(UNSIGNED(vga_y)) WHEN UNSIGNED(vga_y) < IMAGE_HEIGHT 
                 ELSE IMAGE_HEIGHT-1;
    vector_addr <= vector_addr_reg;

    -- 矢量存储过程
    vector_storage_process : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                stored_vector_x <= (OTHERS => (OTHERS => '0'));
                stored_vector_y <= (OTHERS => (OTHERS => '0'));
                vector_magnitude <= (OTHERS => (OTHERS => '0'));
                active_arrow_count <= (OTHERS => '0');
                
            ELSIF vector_valid = '1' THEN
                -- 存储矢量数据
                IF TO_INTEGER(UNSIGNED(vector_addr_reg)) < ARROW_GRID_X*ARROW_GRID_Y THEN
                    stored_vector_x(TO_INTEGER(UNSIGNED(vector_addr_reg))) <= vector_x;
                    stored_vector_y(TO_INTEGER(UNSIGNED(vector_addr_reg))) <= vector_y;
                    vector_magnitude(TO_INTEGER(UNSIGNED(vector_addr_reg))) <= 
                        compute_magnitude(vector_x, vector_y);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- 实时箭头渲染过程
    arrow_render_process : PROCESS(clk)
        VARIABLE grid_spacing_x : INTEGER;
        VARIABLE grid_spacing_y : INTEGER;
        VARIABLE in_arrow_region : STD_LOGIC;
        VARIABLE current_vx, current_vy : SIGNED(7 DOWNTO 0);
        VARIABLE current_magnitude : SIGNED(7 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            -- 计算网格间距
            grid_spacing_x := IMAGE_WIDTH / ARROW_GRID_X;   -- 20像素
            grid_spacing_y := IMAGE_HEIGHT / ARROW_GRID_Y;  -- 20像素
            
            -- 确定当前像素属于哪个箭头网格
            current_arrow_x <= vga_x_int / grid_spacing_x;
            current_arrow_y <= vga_y_int / grid_spacing_y;
            current_arrow_index <= (vga_y_int / grid_spacing_y) * ARROW_GRID_X + 
                                  (vga_x_int / grid_spacing_x);
            
            -- 计算箭头中心坐标
            arrow_center_x <= (current_arrow_x * grid_spacing_x) + (grid_spacing_x / 2);
            arrow_center_y <= (current_arrow_y * grid_spacing_y) + (grid_spacing_y / 2);
            
            -- 计算当前像素在箭头模板中的位置
            arrow_pixel_x <= (vga_x_int - arrow_center_x + ARROW_SIZE/2) MOD ARROW_SIZE;
            arrow_pixel_y <= (vga_y_int - arrow_center_y + ARROW_SIZE/2) MOD ARROW_SIZE;
            
            -- 检查是否在箭头显示区域内
            in_arrow_region := '0';
            IF (vga_x_int >= arrow_center_x - ARROW_SIZE/2) AND 
               (vga_x_int < arrow_center_x + ARROW_SIZE/2) AND
               (vga_y_int >= arrow_center_y - ARROW_SIZE/2) AND 
               (vga_y_int < arrow_center_y + ARROW_SIZE/2) THEN
                in_arrow_region := '1';
            END IF;
            
            -- 获取当前位置的矢量数据
            IF current_arrow_index < ARROW_GRID_X*ARROW_GRID_Y THEN
                current_vx := stored_vector_x(current_arrow_index);
                current_vy := stored_vector_y(current_arrow_index);
                current_magnitude := vector_magnitude(current_arrow_index);
            ELSE
                current_vx := (OTHERS => '0');
                current_vy := (OTHERS => '0');
                current_magnitude := (OTHERS => '0');
            END IF;
            
            -- 判断是否显示箭头
            arrow_active <= '0';
            IF in_arrow_region = '1' AND 
               current_magnitude > SIGNED(motion_threshold) THEN
                arrow_active <= '1';
                arrow_pixel_on <= get_arrow_pattern(current_vx, current_vy, 
                                                   arrow_pixel_x, arrow_pixel_y);
            ELSE
                arrow_pixel_on <= '0';
            END IF;
        END IF;
    END PROCESS;

    -- 背景图像读取
    background_process : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            bg_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(vga_y_int * IMAGE_WIDTH + vga_x_int, 17));
            background_pixel <= bg_data;
        END IF;
    END PROCESS;

    -- 颜色选择
    selected_arrow_color <= ARROW_COLORS(TO_INTEGER(UNSIGNED(arrow_color)));

    -- 最终像素合成
    pixel_composition_process : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            CASE display_mode IS
                WHEN "00" =>  -- 仅原图
                    final_pixel <= background_pixel;
                    
                WHEN "01" =>  -- 仅箭头
                    IF arrow_active = '1' AND arrow_pixel_on = '1' THEN
                        final_pixel <= selected_arrow_color;
                    ELSE
                        final_pixel <= x"0000";  -- 黑色背景
                    END IF;
                    
                WHEN "10" =>  -- 叠加模式 (推荐)
                    IF arrow_active = '1' AND arrow_pixel_on = '1' THEN
                        final_pixel <= selected_arrow_color;
                    ELSE
                        final_pixel <= background_pixel;
                    END IF;
                    
                WHEN "11" =>  -- 半透明叠加
                    IF arrow_active = '1' AND arrow_pixel_on = '1' THEN
                        -- 简单的颜色混合 (50% 透明度)
                        final_pixel(15 DOWNTO 11) <= 
                            STD_LOGIC_VECTOR((UNSIGNED(selected_arrow_color(15 DOWNTO 11)) + 
                                            UNSIGNED(background_pixel(15 DOWNTO 11))) SRL 1);
                        final_pixel(10 DOWNTO 5) <= 
                            STD_LOGIC_VECTOR((UNSIGNED(selected_arrow_color(10 DOWNTO 5)) + 
                                            UNSIGNED(background_pixel(10 DOWNTO 5))) SRL 1);
                        final_pixel(4 DOWNTO 0) <= 
                            STD_LOGIC_VECTOR((UNSIGNED(selected_arrow_color(4 DOWNTO 0)) + 
                                            UNSIGNED(background_pixel(4 DOWNTO 0))) SRL 1);
                    ELSE
                        final_pixel <= background_pixel;
                    END IF;
                    
                WHEN OTHERS =>
                    final_pixel <= background_pixel;
            END CASE;
        END IF;
    END PROCESS;

    -- 输出连接
    vga_pixel <= final_pixel;
    vga_valid <= bg_valid;
    arrow_count <= STD_LOGIC_VECTOR(active_arrow_count);

END rtl;