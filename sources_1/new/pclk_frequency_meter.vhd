---------------------------------------------------------------------------------
-- 精简PCLK频率测量模块
-- 功能：测量PCLK频率并输出数值
-- 测量原理：在1秒窗口内计数PCLK脉冲数
-- 输出：32位频率值（Hz）和有效标志
---------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pclk_frequency_meter IS
    PORT (
        -- 时钟和控制
        clk_100m : IN STD_LOGIC;                    -- 100MHz参考时钟
        reset : IN STD_LOGIC;                       -- 复位信号
        
        -- 被测信号
        pclk : IN STD_LOGIC;                        -- 待测PCLK信号
        
        -- 输出
        frequency_mhz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 频率值（MHz x 100，支持小数）
        freq_valid : OUT STD_LOGIC                  -- 频率值有效（每秒更新一次）
    );
END pclk_frequency_meter;

ARCHITECTURE Behavioral OF pclk_frequency_meter IS
    -- 1秒计数值 (100MHz时钟)
    CONSTANT ONE_SECOND_COUNT : INTEGER := 100_000_000 - 1;
    
    -- PCLK同步寄存器（防止亚稳态）
    SIGNAL pclk_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pclk_prev : STD_LOGIC := '0';
    SIGNAL pclk_rising : STD_LOGIC;
    
    -- 计数器
    SIGNAL ref_counter : INTEGER RANGE 0 TO ONE_SECOND_COUNT := 0;
    SIGNAL pclk_counter : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL freq_result : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL valid_flag : STD_LOGIC := '0';
    
    -- 频率转换中间信号
    SIGNAL freq_hz : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL freq_mhz_x100 : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');

BEGIN
    -- PCLK上升沿检测
    pclk_rising <= pclk_sync(1) AND NOT pclk_sync(2);
    
    -- 输出连接
    frequency_mhz <= freq_result;
    freq_valid <= valid_flag;
    
    -- 频率测量进程
    freq_measure_process: PROCESS(clk_100m, reset)
    BEGIN
        IF reset = '1' THEN
            pclk_sync <= (OTHERS => '0');
            pclk_prev <= '0';
            ref_counter <= 0;
            pclk_counter <= (OTHERS => '0');
            freq_result <= (OTHERS => '0');
            valid_flag <= '0';
            
        ELSIF rising_edge(clk_100m) THEN
            -- PCLK信号同步
            pclk_sync <= pclk_sync(1 DOWNTO 0) & pclk;
            
            -- 默认状态
            valid_flag <= '0';
            
            -- 参考时钟计数（1秒窗口）
            IF ref_counter < ONE_SECOND_COUNT THEN
                ref_counter <= ref_counter + 1;
                
                -- 在1秒窗口内计数PCLK脉冲
                IF pclk_rising = '1' THEN
                    pclk_counter <= pclk_counter + 1;
                END IF;
                
            ELSE
                -- 1秒到达，计算MHz频率
                freq_hz <= pclk_counter;
                -- 转换为MHz x 100（保留2位小数）
                -- MHz x 100 = Hz / 10000
                freq_mhz_x100 <= pclk_counter / 10000;
                
                -- 限制在16位范围内 (0-65535，即0-655.35MHz)
                IF freq_mhz_x100 <= 65535 THEN
                    freq_result <= STD_LOGIC_VECTOR(freq_mhz_x100(15 DOWNTO 0));
                ELSE
                    freq_result <= x"FFFF"; -- 超出范围时显示最大值
                END IF;
                
                valid_flag <= '1';
                
                -- 重新开始下一轮测量
                ref_counter <= 0;
                pclk_counter <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS freq_measure_process;
    
END Behavioral;

---------------------------------------------------------------------------------
-- 使用说明：
---------------------------------------------------------------------------------
-- 1. 连接clk_100m到板载100MHz时钟
-- 2. 连接pclk到OV7670的PCLK输出
-- 3. frequency_mhz输出为MHz频率 x 100（支持2位小数）
-- 4. freq_valid为'1'时表示frequency_mhz值已更新（每秒一次）
-- 
-- 输出格式示例：
-- - 25.00MHz -> frequency_mhz = 2500
-- - 24.12MHz -> frequency_mhz = 2412
-- - 12.50MHz -> frequency_mhz = 1250
-- 
-- 显示转换：
-- - 取frequency_mhz的值，前面几位为整数部分，后2位为小数部分
-- - 例如：2500 显示为 "25.00"，2412 显示为 "24.12"
-- 
-- 典型连接示例：
-- signal pclk_freq_mhz : std_logic_vector(15 downto 0);
-- signal freq_ready : std_logic;
-- 
-- freq_meter_inst : pclk_frequency_meter
-- port map (
--     clk_100m => clk,
--     reset => reset,
--     pclk => camera_pclk,
--     frequency_mhz => pclk_freq_mhz,
--     freq_valid => freq_ready
-- );
-- 
-- -- 将pclk_freq_mhz连接到你现有的16位数码管显示模块
-- -- 典型PCLK频率：24-25MHz，显示为2400-2500
---------------------------------------------------------------------------------