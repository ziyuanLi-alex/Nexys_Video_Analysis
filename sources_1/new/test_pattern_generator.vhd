LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY test_pattern_generator IS
    PORT (
        data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 输入数据(用于图案选择)
        wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 写地址(本模块中未使用)
        wrclock : IN STD_LOGIC; -- 写时钟
        wren : IN STD_LOGIC; -- 写使能(用于选择测试图案)
        rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 从VGA控制器读取地址
        rdclock : IN STD_LOGIC; -- 读时钟(VGA时钟)
        q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- 测试图案的输出像素数据
    );
END ENTITY;

ARCHITECTURE Behavioral OF test_pattern_generator IS
    -- 图案选择寄存器
    SIGNAL pattern_select : unsigned(2 DOWNTO 0) := "000";

    -- 屏幕参数 (320x240分辨率)
    CONSTANT WIDTH : INTEGER := 320;
    CONSTANT HEIGHT : INTEGER := 240;

    -- 图案颜色 (RGB565格式)
    CONSTANT COLOR_RED : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111100000000000"; -- F800
    CONSTANT COLOR_GREEN : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000011111100000"; -- 07E0
    CONSTANT COLOR_BLUE : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000000000011111"; -- 001F
    CONSTANT COLOR_YELLOW : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111111111100000"; -- FFE0
    CONSTANT COLOR_CYAN : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000011111111111"; -- 07FF
    CONSTANT COLOR_MAGENTA : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111100000011111"; -- F81F
    CONSTANT COLOR_BLACK : STD_LOGIC_VECTOR(15 DOWNTO 0) := "0000000000000000"; -- 0000
    CONSTANT COLOR_WHITE : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1111111111111111"; -- FFFF
    CONSTANT COLOR_GRAY : STD_LOGIC_VECTOR(15 DOWNTO 0) := "1000010000010000"; -- 8410

    -- 输出寄存器
    SIGNAL output_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

BEGIN
    -- 图案选择进程(使用写接口进行控制)
    PROCESS (wrclock)
    BEGIN
        IF rising_edge(wrclock) THEN
            IF wren = '1' THEN
                -- 使用数据输入选择图案
                pattern_select <= unsigned(data(2 DOWNTO 0));
            END IF;
        END IF;
    END PROCESS;

    -- 生成测试图案进程
    PROCESS (rdclock)
        VARIABLE x_pos, y_pos : INTEGER;
        VARIABLE addr_int : INTEGER;
        VARIABLE color : STD_LOGIC_VECTOR(15 DOWNTO 0);
        VARIABLE bar_width : INTEGER;
        VARIABLE checker_size : INTEGER;
        VARIABLE radius_sq, center_dist_sq : INTEGER;
    BEGIN
        IF rising_edge(rdclock) THEN
            -- 将地址转换为坐标
            addr_int := to_integer(unsigned(rdaddress));
            x_pos := addr_int MOD WIDTH;
            y_pos := addr_int / WIDTH;

            -- 根据pattern_select选择图案
            CASE pattern_select IS
                -- 彩色条纹 (垂直) - 调整为320x240分辨率
                WHEN "000" =>
                    -- 计算每个条纹的宽度 (320/8 = 40像素)
                    bar_width := 40;
                    
                    IF x_pos < bar_width THEN 
                        color := COLOR_WHITE;
                    ELSIF x_pos < bar_width * 2 THEN 
                        color := COLOR_YELLOW;
                    ELSIF x_pos < bar_width * 3 THEN
                        color := COLOR_CYAN;
                    ELSIF x_pos < bar_width * 4 THEN
                        color := COLOR_GREEN;
                    ELSIF x_pos < bar_width * 5 THEN
                        color := COLOR_MAGENTA;
                    ELSIF x_pos < bar_width * 6 THEN
                        color := COLOR_RED;
                    ELSIF x_pos < bar_width * 7 THEN
                        color := COLOR_BLUE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                -- 棋盘格图案 - 调整为320x240分辨率
                WHEN "001" =>
                    checker_size := 20; -- 20x20像素棋盘格
                    IF ((x_pos / checker_size) MOD 2 = 0) XOR ((y_pos / checker_size) MOD 2 = 0) THEN
                        color := COLOR_WHITE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                -- 同心圆图案 - 调整为320x240分辨率
                WHEN "010" =>
                    -- 预先计算半径的平方值以减少复杂度
                    center_dist_sq := (x_pos - WIDTH/2) * (x_pos - WIDTH/2) + (y_pos - HEIGHT/2) * (y_pos - HEIGHT/2);
                    
                    -- 第一个圆 (红色)
                    radius_sq := (WIDTH/8) * (WIDTH/8);
                    IF center_dist_sq < radius_sq THEN
                        color := COLOR_RED;
                    -- 第二个圆 (白色)
                    ELSIF center_dist_sq < (WIDTH/6) * (WIDTH/6) THEN
                        color := COLOR_WHITE;
                    -- 第三个圆 (蓝色)
                    ELSIF center_dist_sq < (WIDTH/4) * (WIDTH/4) THEN
                        color := COLOR_BLUE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                -- 网格图案 - 调整为320x240分辨率
                WHEN "011" =>
                    IF (x_pos MOD 16 = 0) OR (y_pos MOD 16 = 0) THEN
                        color := COLOR_WHITE;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                -- 直方图图案 - 调整为320x240分辨率
                WHEN "100" =>
                    -- 分三区域：红色(左)、绿色(中)、蓝色(右)柱状图
                    IF x_pos < WIDTH/3 THEN -- 红色区域
                        IF y_pos > (HEIGHT - 5 - (x_pos * 3) MOD (HEIGHT/2)) THEN
                            color := COLOR_RED;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    ELSIF x_pos < 2 * WIDTH/3 THEN -- 绿色区域
                        IF y_pos > (HEIGHT - 5 - ((x_pos - WIDTH/3) * 5) MOD (HEIGHT/2)) THEN
                            color := COLOR_GREEN;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    ELSE -- 蓝色区域
                        IF y_pos > (HEIGHT - 5 - ((x_pos - 2 * WIDTH/3) * 4) MOD (HEIGHT/2)) THEN
                            color := COLOR_BLUE;
                        ELSE
                            color := COLOR_BLACK;
                        END IF;
                    END IF;

                    -- 添加水平网格线
                    IF y_pos MOD 20 = 0 THEN
                        color := COLOR_GRAY;
                    END IF;

                -- 分辨率测试图案 - 调整为320x240分辨率
                WHEN "101" =>
                    -- 简单的十字线图案
                    IF x_pos = WIDTH/2 OR y_pos = HEIGHT/2 THEN
                        color := COLOR_WHITE;
                    -- 中心区域的棋盘格
                    ELSIF (x_pos + y_pos) MOD 2 = 0 AND 
                          (x_pos > WIDTH/2 - 40 AND x_pos < WIDTH/2 + 40 AND
                           y_pos > HEIGHT/2 - 40 AND y_pos < HEIGHT/2 + 40) THEN
                        color := COLOR_RED;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;

                -- 边框图案 - 调整为320x240分辨率
                WHEN "110" =>
                    IF x_pos = 0 OR x_pos = WIDTH - 1 OR y_pos = 0 OR y_pos = HEIGHT - 1 THEN
                        color := COLOR_WHITE;  -- 外边框白色
                    ELSIF x_pos = 1 OR x_pos = WIDTH - 2 OR y_pos = 1 OR y_pos = HEIGHT - 2 THEN
                        color := COLOR_RED;    -- 内边框红色
                    ELSE
                        color := COLOR_BLACK;  -- 内部黑色
                    END IF;

                -- 默认图案 - 简单边框与黑色背景
                WHEN OTHERS =>
                    IF x_pos = 0 OR x_pos = WIDTH - 1 OR y_pos = 0 OR y_pos = HEIGHT - 1 THEN
                        color := COLOR_WHITE;
                    ELSIF x_pos = 1 OR x_pos = WIDTH - 2 OR y_pos = 1 OR y_pos = HEIGHT - 2 THEN
                        color := COLOR_RED;
                    ELSE
                        color := COLOR_BLACK;
                    END IF;
            END CASE;

            output_data <= color; -- 将计算得到的颜色值赋给输出信号
        END IF;
    END PROCESS;

    q <= output_data; -- 将内部寄存器的值连接到最终输出端口

END Behavioral;