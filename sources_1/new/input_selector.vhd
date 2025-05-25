LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_selector IS
    PORT (
        -- 控制信号
        clk : IN STD_LOGIC; -- 时钟信号
        select_input : IN STD_LOGIC; -- 输入选择信号 (0=摄像头, 1=测试图案)

        -- 摄像头/帧缓冲区接口
        fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 帧缓冲区读地址输出
        fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 帧缓冲区数据输入

        -- 测试图案接口
        tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 测试图案读地址输出
        tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案数据输入
        tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案选择
        tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- 测试图案模式选择

        -- 输出接口 (连接到VGA驱动器)
        vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA请求地址输入
        vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- VGA数据输出

        -- -- 简化的直方图相关端口
        -- display_mode : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- 000: 正常, 001: 测试图案, 010: 亮度直方图, 011: RGB直方图
        -- hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据输入
        -- hist_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图地址输出

        -- 保留的光流图像端口
        -- flow_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 光流数据输入
        -- flow_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 光流地址输出

    );
END ENTITY input_selector;

ARCHITECTURE rtl OF input_selector IS
BEGIN
    -- 将VGA地址请求转发到帧缓冲区和测试图案生成器
    fb_addr <= vga_addr;
    tp_addr <= vga_addr;

    -- 基于选择信号选择输出数据
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF select_input = '0' THEN
                -- 选择摄像头数据
                vga_data <= fb_data;
            ELSE
                -- 选择测试图案数据
                vga_data <= tp_data;
            END IF;

            -- 将测试图案模式传递给测试图案生成器
            tp_select <= "0000000000000" & tp_pattern;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;