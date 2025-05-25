LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY input_selector IS
    PORT (
        -- 控制信号
        clk : IN STD_LOGIC; -- 时钟信号
        select_input : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- 输入选择信号 (00=摄像头, 01=测试图案, 10=直方图, 11=光流)

        -- 摄像头/帧缓冲区接口
        fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 帧缓冲区读地址输出
        fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 帧缓冲区数据输入

        -- 测试图案接口
        tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 测试图案读地址输出
        tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案数据输入
        tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案选择
        tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- 测试图案模式选择

        -- VGA输出接口 (连接到VGA驱动器)
        vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA请求地址输入
        vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- VGA数据输出

        -- 简化的直方图相关端口
        hist_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 直方图读取地址
        hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式输出像素

        -- 保留的光流图像端口
        flow_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 光流地址输出
        flow_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0) -- 光流数据输入
    );
END ENTITY input_selector;

ARCHITECTURE rtl OF input_selector IS
    -- 内部信号
    signal selected_data : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN
    -- 地址路由逻辑 (组合逻辑)
    PROCESS (select_input, vga_addr)
    BEGIN
        -- 默认值
        fb_addr <= (others => '0');
        tp_addr <= (others => '0');
        hist_addr <= (others => '0');
        flow_addr <= (others => '0');
        
        CASE select_input IS
            WHEN "00" => -- 摄像头模式
                fb_addr <= vga_addr;
                
            WHEN "01" => -- 测试图案模式
                tp_addr <= vga_addr;
                
            WHEN "10" => -- 直方图模式
                hist_addr <= vga_addr;
                
            WHEN "11" => -- 光流模式
                flow_addr <= vga_addr;
                
            WHEN OTHERS =>
                fb_addr <= vga_addr; -- 默认显示摄像头
        END CASE;
    END PROCESS;

    -- 数据选择逻辑 (时序逻辑)
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            CASE select_input IS
                WHEN "00" => -- 摄像头模式
                    selected_data <= fb_data;
                    
                WHEN "01" => -- 测试图案模式
                    selected_data <= tp_data;
                    
                WHEN "10" => -- 直方图模式
                    selected_data <= hist_data;
                    
                WHEN "11" => -- 光流模式
                    selected_data <= flow_data;
                    
                WHEN OTHERS =>
                    selected_data <= fb_data; -- 默认显示摄像头
            END CASE;

            -- 将测试图案模式传递给测试图案生成器
            tp_select <= "0000000000000" & tp_pattern;
        END IF;
    END PROCESS;

    -- 输出赋值
    vga_data <= selected_data;

END ARCHITECTURE rtl;