----------------------------------------------------------------------------------
-- OV7670寄存器模块 - 调试兼容版本
-- 功能：支持硬编码调试和注释切换，保持原有端口兼容性
-- 特点：可以单独启用/禁用任何寄存器，方便逐步调试
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_registers IS
    PORT (
        iclk : IN STD_LOGIC;
        gostate : IN STD_LOGIC;
        sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        regs : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        reg_loaded : OUT STD_LOGIC
    );
END OV7670_registers;

ARCHITECTURE Behavioral OF OV7670_registers IS
    -- 防抖组件（保持兼容）
    COMPONENT debounce PORT (
        clk : IN STD_LOGIC;
        i : IN STD_LOGIC;
        o : OUT STD_LOGIC
    );
    END COMPONENT;

    -- 信号定义（保持原有兼容）
    SIGNAL sreg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL nextRegAddr : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    
    CONSTANT write_address : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"42";
    CONSTANT read_address : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"43";
    
    -- 开关控制寄存器（保持兼容）
    SIGNAL test2 : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL test3 : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL test4 : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL test5 : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL fps_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"6b4a";
    SIGNAL colour_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"1204";
    SIGNAL resend : STD_LOGIC;
    SIGNAL survmode : STD_LOGIC;

BEGIN
    -- 防抖处理（保持兼容）
    b1 : debounce PORT MAP (
        clk => iclk,
        i => key(2),
        o => resend
    );

    -- 输出连接（保持兼容）
    regs <= sreg;
    WITH sreg SELECT reg_loaded <= '1' WHEN x"FFFF", '0' WHEN OTHERS;
    
    -- 开关控制（保持兼容）
    WITH sw(0) SELECT colour_reg <= x"1200" WHEN '1', x"1204" WHEN OTHERS;
    WITH sw(1) SELECT fps_reg <= x"6bca" WHEN '1', x"6b4a" WHEN OTHERS;
    WITH sw(2) SELECT test2 <= x"4fff" WHEN '1', x"4fb3" WHEN OTHERS;
    WITH sw(3) SELECT test3 <= x"50ff" WHEN '1', x"50b3" WHEN OTHERS;
    WITH sw(4) SELECT test4 <= x"51ff" WHEN '1', x"5100" WHEN OTHERS;
    WITH sw(7) SELECT survmode <= '1' WHEN '1', '0' WHEN OTHERS;

    PROCESS (iclk)
    BEGIN
        IF rising_edge(iclk) THEN
            IF gostate = '1' THEN
                nextRegAddr <= STD_LOGIC_VECTOR(unsigned(nextRegAddr) + 1);
            ELSIF resend = '1' THEN
                nextRegAddr <= (OTHERS => '0');
            END IF;

            -- =================================================================
            -- 寄存器配置 - 支持硬编码调试
            -- 可以通过注释/取消注释单独控制每个寄存器
            -- =================================================================
            CASE nextRegAddr IS
                -- ---------------------------------------------------------
                -- 基础系统复位（必须保留）
                -- ---------------------------------------------------------
                WHEN x"00" => sreg <= x"1280"; -- COM7: 系统复位
                WHEN x"01" => sreg <= x"1280"; -- COM7: 系统复位（确保）
                
                -- ---------------------------------------------------------
                -- 时钟配置（可单独调试）
                -- ---------------------------------------------------------
                WHEN x"02" => sreg <= x"11C0"; -- CLKRC: 时钟不分频
                -- WHEN x"02" => sreg <= x"1101"; -- CLKRC: 时钟2分频（调试用）
                
                -- ---------------------------------------------------------
                -- 输出格式配置（关键 - 解决红色问题）
                -- ---------------------------------------------------------
                -- WHEN x"03" => sreg <= colour_reg; -- COM7: RGB565/YUV422格式
                WHEN x"03" => sreg <= x"1204"; -- COM7: 强制RGB565（调试用）
                -- WHEN x"03" => sreg <= x"1200"; -- COM7: 强制YUV422（调试用）
                
                -- ---------------------------------------------------------
                -- RGB565格式控制（重要）
                -- ---------------------------------------------------------
                WHEN x"04" => sreg <= x"4010"; -- COM15: 全范围输出，RGB565格式
                -- WHEN x"04" => sreg <= x"40C0"; -- COM15: 不同范围（调试用）
                
                WHEN x"05" => sreg <= x"3A04"; -- TSLB: UV输出顺序
                -- WHEN x"05" => sreg <= x"3A0C"; -- TSLB: 不同顺序（调试用）
                
                WHEN x"06" => sreg <= x"8C00"; -- RGB444: 必须为0使RGB565工作
                -- WHEN x"06" => sreg <= x"8C02"; -- RGB444: RGB444模式（调试用）
                
                -- ---------------------------------------------------------
                -- 缩放和时钟控制（可选调试）
                -- ---------------------------------------------------------
                -- WHEN x"07" => sreg <= x"0C04"; -- COM3: 使能缩放
                -- WHEN x"07" => sreg <= x"0C00"; -- COM3: 禁用缩放（调试用）
                
                -- WHEN x"08" => sreg <= x"3E00"; -- COM14: PCLK不分频
                -- WHEN x"08" => sreg <= x"3E19"; -- COM14: PCLK分频（调试用）
                
                -- ---------------------------------------------------------
                -- 像素时钟和降采样控制（可选调试）
                -- ---------------------------------------------------------
                -- WHEN x"09" => sreg <= x"7200"; -- SCALING_DCWCTR: 不降采样
                -- WHEN x"09" => sreg <= x"7211"; -- SCALING_DCWCTR: 降采样（调试用）
                
                -- WHEN x"0A" => sreg <= x"7300"; -- SCALING_PCLK_DIV: 不分频
                -- WHEN x"0A" => sreg <= x"7301"; -- SCALING_PCLK_DIV: 分频（调试用）
                
                -- ---------------------------------------------------------
                -- 缩放系数与测试图案
                -- ---------------------------------------------------------
                -- WHEN x"0B" => sreg <= x"70BA"; -- SCALING_XSC: 水平缩放
                -- WHEN x"0B" => sreg <= x"703A"; -- SCALING_XSC: 不同缩放（调试用）
                
                -- WHEN x"0C" => sreg <= x"71B5"; -- SCALING_YSC: 垂直缩放
                -- WHEN x"0C" => sreg <= x"7135"; -- SCALING_YSC: 不同缩放（调试用）
                
                -- ---------------------------------------------------------
                -- 同步和帧率控制（可选调试）
                -- ---------------------------------------------------------
                -- WHEN x"0D" => sreg <= x"1500"; -- COM10: 使用HREF
                -- WHEN x"0D" => sreg <= x"1540"; -- COM10: 使用HSYNC（调试用）
                
                -- WHEN x"0E" => sreg <= fps_reg; -- DBLV: PLL控制
                -- WHEN x"0E" => sreg <= x"6B0A"; -- DBLV: 不同PLL（调试用）
                
                -- ---------------------------------------------------------
                -- 颜色矩阵（高级调试 - 可选）
                -- ---------------------------------------------------------
                -- WHEN x"0F" => sreg <= test2; -- MTX1: 颜色矩阵1
                -- WHEN x"10" => sreg <= test3; -- MTX2: 颜色矩阵2  
                -- WHEN x"11" => sreg <= test4; -- MTX3: 颜色矩阵3
                -- WHEN x"12" => sreg <= x"523D"; -- MTX4: 颜色矩阵4
                -- WHEN x"13" => sreg <= x"53A7"; -- MTX5: 颜色矩阵5
                -- WHEN x"14" => sreg <= x"54E4"; -- MTX6: 颜色矩阵6
                -- WHEN x"15" => sreg <= x"589E"; -- MTXS: 矩阵符号
                
                -- ---------------------------------------------------------
                -- 窗口设置（高级调试 - 可选）
                -- ---------------------------------------------------------
                -- WHEN x"16" => sreg <= x"1714"; -- HSTART: HREF开始
                -- WHEN x"17" => sreg <= x"1802"; -- HSTOP: HREF结束
                -- WHEN x"18" => sreg <= x"32A4"; -- HREF: 边缘控制
                -- WHEN x"19" => sreg <= x"1903"; -- VSTART: VSYNC开始
                -- WHEN x"1A" => sreg <= x"1A7B"; -- VSTOP: VSYNC结束
                -- WHEN x"1B" => sreg <= x"038A"; -- VREF: VSYNC控制
                
                -- ---------------------------------------------------------
                -- 结束标志
                -- ---------------------------------------------------------
                WHEN OTHERS => sreg <= x"FFFF";
            END CASE;
        END IF;
    END PROCESS;
END Behavioral;

---------------------------------------------------------------------------------
-- 硬编码调试说明：
---------------------------------------------------------------------------------
-- 1. 【基础调试】- 只启用最关键的寄存器：
--    保持 x"00" 到 x"06" 启用，其他全部注释
--    这是解决红色问题的最小配置
--
-- 2. 【渐进调试】- 逐步添加寄存器：
--    先测试 x"00"-x"06"，确认RGB565输出正常
--    然后逐个取消注释 x"07"-x"0E"，观察效果
--
-- 3. 【高级调试】- 颜色和窗口调试：
--    在基础功能正常后，可以启用颜色矩阵和窗口设置
--
-- 4. 【开关调试】- 运行时切换：
--    SW(0): RGB565(0) vs YUV422(1)
--    SW(1): 标准PLL(0) vs 高频PLL(1) 
--    SW(2-4): 颜色矩阵参数调整
--
-- 5. 【调试技巧】：
--    - 单独启用一个寄存器时，可以硬编码值而不用开关
--    - 例如：WHEN x"03" => sreg <= x"1204"; -- 强制RGB565
--    - 对比不同配置的效果
--
-- 6. 【当前建议的最小配置】（解决红色问题）：
--    只启用 x"00" 到 x"06"，其他全部注释
--    这应该能输出正确的RGB565黑白图像
---------------------------------------------------------------------------------