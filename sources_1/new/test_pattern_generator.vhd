LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY test_pattern_generator IS
    PORT (
        data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- Input data (unused in this module)
        wraddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0); -- Write address (unused in this module)
        wrclock : IN STD_LOGIC; -- Write clock
        wren : IN STD_LOGIC; -- Write enable (used to select test pattern)
        rdaddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0); -- Read address from VGA controller
        rdclock : IN STD_LOGIC; -- Read clock (VGA clock)
        q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- Output pixel data for test pattern
    );
END ENTITY;

ARCHITECTURE Behavioral OF test_pattern_generator IS
    -- Pattern selection register
    SIGNAL pattern_select : unsigned(2 DOWNTO 0) := "000";

    -- Screen parameters (assuming 80x60 pixel buffer that gets scaled to 640x480)
    CONSTANT WIDTH : INTEGER := 80;
    CONSTANT HEIGHT : INTEGER := 60;

    -- Pattern colors (RGB565 format)
    CONSTANT COLOR_RED : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111100000000000"; -- F800
    CONSTANT COLOR_GREEN : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000011111100000"; -- 07E0
    CONSTANT COLOR_BLUE : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000000000011111"; -- 001F
    CONSTANT COLOR_YELLOW : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111111111100000"; -- FFE0
    CONSTANT COLOR_CYAN : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000011111111111"; -- 07FF
    CONSTANT COLOR_MAGENTA : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111100000011111"; -- F81F
    CONSTANT COLOR_BLACK : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000000000000000"; -- 0000
    CONSTANT COLOR_WHITE : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111111111111111"; -- FFFF
    CONSTANT COLOR_GRAY : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1000010000010000"; -- 8410

    -- Output register
    SIGNAL output_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

BEGIN
    -- Process for pattern selection (uses the write interface for control)
    PROCESS (wrclock)
    BEGIN
        IF rising_edge(wrclock) THEN
            IF wren = '1' THEN
                -- Use data input to select pattern
                -- Here we're using just a few bits of the data input for pattern selection
                pattern_select <= unsigned(data(2 DOWNTO 0));
            END IF;
        END IF;
    END PROCESS;

    -- Process for generating test patterns
    PROCESS (rdclock)
        VARIABLE x_pos, y_pos : INTEGER;
        VARIABLE addr_int : INTEGER;
        VARIABLE color : STD_LOGIC_VECTOR(15 DOWNTO 0);
        VARIABLE intensity : unsigned(4 DOWNTO 0);
    BEGIN
        IF rising_edge(rdclock) THEN
            -- Convert address to coordinates
            addr_int := to_integer(unsigned(rdaddress));
            x_pos := addr_int MOD WIDTH;
            y_pos := addr_int / WIDTH;

            -- Select pattern based on pattern_select
            CASE pattern_select IS
                    -- Color bars (vertical)
                WHEN "000" =>
                    IF x_pos < 10 THEN -- 1. 左边第一条：白色
                        color := COLOR_WHITE;
                    ELSIF x_pos < 20 THEN -- 2. 左边第二条：黄色
                        color := COLOR_YELLOW;
                    ELSIF x_pos < 30 THEN -- 3. 左边第三条：青色
                        color := COLOR_CYAN;
                    ELSIF x_pos < 40 THEN -- 4. 左边第四条：绿色
                        color := COLOR_GREEN;
                    ELSIF x_pos < 50 THEN -- 5. 左边第五条：品红色
                        color := COLOR_MAGENTA;
                    ELSIF x_pos < 60 THEN -- 6. 左边第六条：红色
                        color := COLOR_RED;
                    ELSIF x_pos < 70 THEN -- 7. 左边第七条：蓝色
                        color := COLOR_BLUE;
                    ELSE -- 8. 右边剩余部分：黑色
                        color := COLOR_BLACK;
                    END IF;

                    -- Checkerboard pattern
                WHEN "001" =>
                    IF ((x_pos / 10) MOD 2 = 0) XOR ((y_pos / 10) MOD 2 = 0) THEN
                        color := COLOR_WHITE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;
                WHEN "010" =>
                    -- 在屏幕中心绘制同心圆，如果是80x60分辨率会看起来很粗糙，640x480会更精细
                    IF ((x_pos - WIDTH/2) * (x_pos - WIDTH/2) + (y_pos - HEIGHT/2) * (y_pos - HEIGHT/2)) < (WIDTH/8) * (WIDTH/8) THEN
                        color := COLOR_RED;
                    ELSIF ((x_pos - WIDTH/2) * (x_pos - WIDTH/2) + (y_pos - HEIGHT/2) * (y_pos - HEIGHT/2)) < (WIDTH/6) * (WIDTH/6) THEN
                        color := COLOR_WHITE;
                    ELSIF ((x_pos - WIDTH/2) * (x_pos - WIDTH/2) + (y_pos - HEIGHT/2) * (y_pos - HEIGHT/2)) < (WIDTH/4) * (WIDTH/4) THEN
                        color := COLOR_BLUE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                    -- Crosshatch grid
                WHEN "011" =>
                    IF (x_pos MOD 8 = 0) OR (y_pos MOD 8 = 0) THEN
                        color := COLOR_WHITE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;
                    -- 模拟直方图图案 (修改"100"图案) - 类似histogram_generator的输出
                WHEN "100" =>
                    -- 分三区域：红色(左)、绿色(中)、蓝色(右)柱状图
                    IF x_pos < WIDTH/3 THEN -- 红色区域
                        -- 生成高度不同的柱状图
                        IF y_pos > (HEIGHT - 5 - (x_pos * 3) MOD HEIGHT/2) THEN
                            color := COLOR_RED;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    ELSIF x_pos < 2 * WIDTH/3 THEN -- 绿色区域
                        -- 不同的柱状模式
                        IF y_pos > (HEIGHT - 5 - ((x_pos - WIDTH/3) * 5) MOD HEIGHT/2) THEN
                            color := COLOR_GREEN;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    ELSE -- 蓝色区域
                        -- 又一种不同的柱状模式
                        IF y_pos > (HEIGHT - 5 - ((x_pos - 2 * WIDTH/3) * 4) MOD HEIGHT/2) THEN -- 计算蓝色柱子的高度
                            color := COLOR_BLUE;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    END IF;

                    -- 添加水平网格线
                    IF y_pos MOD 10 = 0 THEN -- 每隔10行绘制一条灰色水平线
                        color := COLOR_GRAY;
                    END IF;

                    -- Resolution chart (center crosshair with resolution marks)
                    -- 分辨率图表 (中心十字线和分辨率标记)
                WHEN "101" =>
                    IF x_pos = WIDTH/2 OR y_pos = HEIGHT/2 THEN -- 在屏幕中心绘制白色十字线
                        color := COLOR_WHITE;
                    ELSIF (x_pos + y_pos) MOD 2 = 0 AND -- 在中心十字线附近绘制棋盘格状的红色标记点
                        (x_pos > WIDTH/2 - 10 AND x_pos < WIDTH/2 + 10 AND
                        y_pos > HEIGHT/2 - 10 AND y_pos < HEIGHT/2 + 10) THEN
                        color := COLOR_RED;
                    ELSE
                        color := COLOR_BLACK; -- 其他区域为黑色
                    END IF;
                    
                    -- 绘制一个简单的边框图案
                WHEN "110" =>
                    IF x_pos = 0 OR x_pos = WIDTH - 1 OR y_pos = 0 OR y_pos = HEIGHT - 1 THEN -- 最外层边框为白色
                        color := COLOR_WHITE;
                    ELSIF x_pos = 1 OR x_pos = WIDTH - 2 OR y_pos = 1 OR y_pos = HEIGHT - 2 THEN -- 次外层边框为红色
                        color := COLOR_RED;
                    ELSE
                        color := COLOR_BLACK; -- 内部为黑色
                    END IF;

                    -- 黑色背景带白色边框 (用于对齐测试)
                WHEN OTHERS => -- 其他未定义的pattern_select值，默认显示此图案
                    IF x_pos = 0 OR x_pos = WIDTH - 1 OR y_pos = 0 OR y_pos = HEIGHT - 1 THEN -- 最外层边框为白色
                        color := COLOR_WHITE;
                    ELSIF x_pos = 1 OR x_pos = WIDTH - 2 OR y_pos = 1 OR y_pos = HEIGHT - 2 THEN -- 次外层边框为红色
                        color := COLOR_RED;
                    ELSE
                        color := COLOR_BLACK; -- 内部为黑色
                    END IF;
            END CASE;

            output_data <= color; -- 将计算得到的颜色值赋给输出信号
        END IF;
    END PROCESS;

    q <= output_data; -- 将内部寄存器的值连接到最终输出端口

END Behavioral;