---------------------------------------------------------------------------------
-- 精确摄像头信号调试模块
-- 功能：精确测量PCLK和VSYNC的频率，诊断同步异常问题
---------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY precise_camera_debug IS
    PORT (
        clk_100m : IN STD_LOGIC;                    -- 100MHz系统时钟
        reset : IN STD_LOGIC;
        
        -- 摄像头信号
        pclk : IN STD_LOGIC;
        vsync : IN STD_LOGIC;
        href : IN STD_LOGIC;
        
        -- 频率输出（用于数码管显示）
        pclk_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- PCLK频率(kHz)
        vsync_freq_hz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- VSYNC频率(Hz)
        href_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- HREF频率(kHz)
        
        -- LED状态指示
        led_pclk_normal : OUT STD_LOGIC;            -- PCLK频率正常(10-30MHz)
        led_vsync_normal : OUT STD_LOGIC;           -- VSYNC频率正常(20-40Hz)
        led_href_normal : OUT STD_LOGIC;            -- HREF频率正常(5-15kHz)
        led_timing_error : OUT STD_LOGIC;           -- 时序异常指示
        
        -- 详细状态
        signals_static : OUT STD_LOGIC;             -- 信号完全静止
        signals_identical : OUT STD_LOGIC           -- PCLK和VSYNC完全相同
    );
END precise_camera_debug;

ARCHITECTURE Behavioral OF precise_camera_debug IS
    -- 1秒计数常量
    CONSTANT ONE_SECOND : INTEGER := 100_000_000;
    
    -- 同步寄存器
    SIGNAL pclk_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    
    -- 边沿检测
    SIGNAL pclk_rising : STD_LOGIC;
    SIGNAL vsync_rising : STD_LOGIC;
    SIGNAL href_rising : STD_LOGIC;
    
    -- 频率计数器
    SIGNAL ref_counter : INTEGER RANGE 0 TO ONE_SECOND := 0;
    SIGNAL pclk_counter : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_counter : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_counter : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    
    -- 频率结果寄存器
    SIGNAL pclk_freq_result : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_freq_result : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_freq_result : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    
    -- 静止检测
    SIGNAL pclk_prev_state : STD_LOGIC := '0';
    SIGNAL vsync_prev_state : STD_LOGIC := '0';
    SIGNAL static_counter : INTEGER RANGE 0 TO ONE_SECOND := 0;
    SIGNAL no_pclk_change : STD_LOGIC := '0';
    SIGNAL no_vsync_change : STD_LOGIC := '0';
    
    -- 相同性检测
    SIGNAL pclk_vsync_diff : STD_LOGIC;
    SIGNAL identical_counter : INTEGER RANGE 0 TO 1000 := 0;
    SIGNAL signals_are_identical : STD_LOGIC := '0';

BEGIN
    -- 边沿检测
    pclk_rising <= pclk_sync(1) AND NOT pclk_sync(2);
    vsync_rising <= vsync_sync(1) AND NOT vsync_sync(2);
    href_rising <= href_sync(1) AND NOT href_sync(2);
    
    -- 信号差异检测
    pclk_vsync_diff <= pclk_sync(1) XOR vsync_sync(1);
    
    -- 输出连接
    pclk_freq_khz <= STD_LOGIC_VECTOR(pclk_freq_result);
    vsync_freq_hz <= STD_LOGIC_VECTOR(vsync_freq_result);
    href_freq_khz <= STD_LOGIC_VECTOR(href_freq_result);
    
    -- 正常范围判断
    led_pclk_normal <= '1' WHEN (pclk_freq_result >= 10000 AND pclk_freq_result <= 30000) ELSE '0';  -- 10-30MHz
    led_vsync_normal <= '1' WHEN (vsync_freq_result >= 20 AND vsync_freq_result <= 40) ELSE '0';     -- 20-40Hz
    led_href_normal <= '1' WHEN (href_freq_result >= 5 AND href_freq_result <= 15) ELSE '0';         -- 5-15kHz
    
    -- 异常指示
    signals_static <= no_pclk_change AND no_vsync_change;
    signals_identical <= signals_are_identical;
    led_timing_error <= (no_pclk_change AND no_vsync_change) OR signals_are_identical;
    
    -- 主处理进程
    main_process: PROCESS(clk_100m, reset)
    BEGIN
        IF reset = '1' THEN
            pclk_sync <= (OTHERS => '0');
            vsync_sync <= (OTHERS => '0');
            href_sync <= (OTHERS => '0');
            ref_counter <= 0;
            pclk_counter <= (OTHERS => '0');
            vsync_counter <= (OTHERS => '0');
            href_counter <= (OTHERS => '0');
            pclk_freq_result <= (OTHERS => '0');
            vsync_freq_result <= (OTHERS => '0');
            href_freq_result <= (OTHERS => '0');
            static_counter <= 0;
            identical_counter <= 0;
            no_pclk_change <= '0';
            no_vsync_change <= '0';
            signals_are_identical <= '0';
            
        ELSIF rising_edge(clk_100m) THEN
            -- 信号同步
            pclk_sync <= pclk_sync(1 DOWNTO 0) & pclk;
            vsync_sync <= vsync_sync(1 DOWNTO 0) & vsync;
            href_sync <= href_sync(1 DOWNTO 0) & href;
            
            -- 1秒计数窗口
            IF ref_counter < ONE_SECOND - 1 THEN
                ref_counter <= ref_counter + 1;
                
                -- 脉冲计数
                IF pclk_rising = '1' THEN
                    IF pclk_counter < 65535 THEN
                        pclk_counter <= pclk_counter + 1;
                    END IF;
                END IF;
                
                IF vsync_rising = '1' THEN
                    IF vsync_counter < 65535 THEN
                        vsync_counter <= vsync_counter + 1;
                    END IF;
                END IF;
                
                IF href_rising = '1' THEN
                    IF href_counter < 65535 THEN
                        href_counter <= href_counter + 1;
                    END IF;
                END IF;
                
            ELSE
                -- 1秒到，更新频率结果
                -- PCLK: 直接输出计数值(Hz)转换为kHz需要除以1000
                IF pclk_counter >= 1000 THEN
                    pclk_freq_result <= pclk_counter / 1000;  -- 转换为kHz
                ELSE
                    pclk_freq_result <= (OTHERS => '0');      -- 小于1kHz显示0
                END IF;
                
                vsync_freq_result <= vsync_counter;           -- 直接显示Hz
                
                -- HREF: 转换为kHz
                IF href_counter >= 1000 THEN
                    href_freq_result <= href_counter / 1000;  -- 转换为kHz
                ELSE
                    href_freq_result <= (OTHERS => '0');      -- 小于1kHz显示0
                END IF;
                
                -- 重置计数器
                ref_counter <= 0;
                pclk_counter <= (OTHERS => '0');
                vsync_counter <= (OTHERS => '0');
                href_counter <= (OTHERS => '0');
            END IF;
            
            -- 静止检测
            IF pclk_sync(1) = pclk_prev_state AND vsync_sync(1) = vsync_prev_state THEN
                IF static_counter < ONE_SECOND - 1 THEN
                    static_counter <= static_counter + 1;
                ELSE
                    no_pclk_change <= '1';
                    no_vsync_change <= '1';
                END IF;
            ELSE
                static_counter <= 0;
                no_pclk_change <= '0';
                no_vsync_change <= '0';
            END IF;
            
            pclk_prev_state <= pclk_sync(1);
            vsync_prev_state <= vsync_sync(1);
            
            -- 相同性检测
            IF pclk_vsync_diff = '0' THEN
                IF identical_counter < 1000 THEN
                    identical_counter <= identical_counter + 1;
                ELSE
                    signals_are_identical <= '1';
                END IF;
            ELSE
                identical_counter <= 0;
                signals_are_identical <= '0';
            END IF;
        END IF;
    END PROCESS main_process;
    
END Behavioral;

---------------------------------------------------------------------------------
-- 使用说明和问题诊断：
---------------------------------------------------------------------------------
-- 连接到数码管显示：
-- - pclk_freq_khz: 应该显示12500 (表示12.5MHz)，如果超过65535会显示为除以1000后的值
-- - vsync_freq_hz: 应该显示25-30 (表示25-30Hz)
-- - href_freq_khz: 应该显示7-10 (表示7-10kHz)
--
-- 注意：由于使用16位计数器，PCLK在12.5MHz时每秒计数12,500,000
-- 但16位最大值65535，所以会自动限制并转换为kHz显示
--
-- LED指示诊断：
-- - led_timing_error = '1': 发现时序异常
-- - signals_static = '1': 所有信号完全不变化
-- - signals_identical = '1': PCLK和VSYNC完全相同（这是你的问题！）
--
-- 问题解决步骤：
-- 1. 如果signals_identical='1' -> 检查引脚约束，PCLK和VSYNC可能接错
-- 2. 如果signals_static='1' -> 摄像头未启动，检查电源和SCCB初始化
-- 3. 如果频率都是0 -> 硬件连接问题
-- 4. 如果PCLK显示12500但VSYNC=0 -> 摄像头配置问题
---------------------------------------------------------------------------------