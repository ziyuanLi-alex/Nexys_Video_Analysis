---------------------------------------------------------------------------------
-- 摄像头调试模块
-- 功能：诊断摄像头黑屏问题
-- 输出：LED指示各种状态，帮助快速定位问题
---------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY camera_debug IS
    PORT (
        clk : IN STD_LOGIC;                         -- 系统时钟
        reset : IN STD_LOGIC;                       -- 复位信号
        
        -- 摄像头信号
        pclk : IN STD_LOGIC;                        -- 摄像头PCLK
        vsync : IN STD_LOGIC;                       -- 垂直同步
        href : IN STD_LOGIC;                        -- 水平参考
        dport : IN STD_LOGIC_VECTOR(7 DOWNTO 0);   -- 数据端口
        
        -- LED调试输出（连接到板上LED）
        led_pclk_active : OUT STD_LOGIC;            -- PCLK活跃指示
        led_vsync_active : OUT STD_LOGIC;           -- VSYNC活跃指示  
        led_href_active : OUT STD_LOGIC;            -- HREF活跃指示
        led_data_changing : OUT STD_LOGIC;          -- 数据变化指示
        
        -- 数码管显示（可选）
        debug_counter : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 调试计数器
        
        -- 状态输出
        camera_working : OUT STD_LOGIC              -- 摄像头工作状态
    );
END camera_debug;

ARCHITECTURE Behavioral OF camera_debug IS
    -- 同步寄存器
    SIGNAL pclk_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_sync : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_prev : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    
    -- 活跃检测计数器
    SIGNAL pclk_counter : UNSIGNED(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_counter : UNSIGNED(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_counter : UNSIGNED(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_change_counter : UNSIGNED(23 DOWNTO 0) := (OTHERS => '0');
    
    -- LED闪烁控制（约1秒周期）
    CONSTANT LED_BLINK_PERIOD : INTEGER := 50_000_000; -- 50M = 0.5秒 @ 100MHz
    SIGNAL blink_counter : INTEGER RANGE 0 TO LED_BLINK_PERIOD := 0;
    SIGNAL blink_state : STD_LOGIC := '0';
    
    -- 边沿检测
    SIGNAL pclk_edge : STD_LOGIC;
    SIGNAL vsync_edge : STD_LOGIC;
    SIGNAL href_edge : STD_LOGIC;
    SIGNAL data_change : STD_LOGIC;
    
    -- 综合状态
    SIGNAL all_signals_active : STD_LOGIC;

BEGIN
    -- 边沿检测
    pclk_edge <= pclk_sync(1) XOR pclk_sync(2);     -- PCLK变化检测
    vsync_edge <= vsync_sync(1) XOR vsync_sync(2);   -- VSYNC变化检测
    href_edge <= href_sync(1) XOR href_sync(2);     -- HREF变化检测
    data_change <= '1' WHEN data_sync /= data_prev ELSE '0';
    
    -- 综合工作状态
    all_signals_active <= '1' WHEN (pclk_counter > 1000 AND 
                                    vsync_counter > 10 AND 
                                    href_counter > 100 AND 
                                    data_change_counter > 100) ELSE '0';
    
    camera_working <= all_signals_active;
    debug_counter <= STD_LOGIC_VECTOR(pclk_counter(15 DOWNTO 0));
    
    -- 主调试进程
    debug_process: PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            pclk_sync <= (OTHERS => '0');
            vsync_sync <= (OTHERS => '0');
            href_sync <= (OTHERS => '0');
            data_sync <= (OTHERS => '0');
            data_prev <= (OTHERS => '0');
            pclk_counter <= (OTHERS => '0');
            vsync_counter <= (OTHERS => '0');
            href_counter <= (OTHERS => '0');
            data_change_counter <= (OTHERS => '0');
            blink_counter <= 0;
            blink_state <= '0';
            
        ELSIF rising_edge(clk) THEN
            -- 信号同步
            pclk_sync <= pclk_sync(1 DOWNTO 0) & pclk;
            vsync_sync <= vsync_sync(1 DOWNTO 0) & vsync;
            href_sync <= href_sync(1 DOWNTO 0) & href;
            data_prev <= data_sync;
            data_sync <= dport;
            
            -- LED闪烁控制
            IF blink_counter < LED_BLINK_PERIOD THEN
                blink_counter <= blink_counter + 1;
            ELSE
                blink_counter <= 0;
                blink_state <= NOT blink_state;
            END IF;
            
            -- 活跃信号计数
            IF pclk_edge = '1' THEN
                IF pclk_counter < x"FFFFFF" THEN
                    pclk_counter <= pclk_counter + 1;
                END IF;
            END IF;
            
            IF vsync_edge = '1' THEN
                IF vsync_counter < x"FFFFFF" THEN  
                    vsync_counter <= vsync_counter + 1;
                END IF;
            END IF;
            
            IF href_edge = '1' THEN
                IF href_counter < x"FFFFFF" THEN
                    href_counter <= href_counter + 1;
                END IF;
            END IF;
            
            IF data_change = '1' THEN
                IF data_change_counter < x"FFFFFF" THEN
                    data_change_counter <= data_change_counter + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS debug_process;
    
    -- LED输出逻辑
    led_pclk_active <= blink_state WHEN pclk_counter > 1000 ELSE '0';
    led_vsync_active <= blink_state WHEN vsync_counter > 10 ELSE '0';
    led_href_active <= blink_state WHEN href_counter > 100 ELSE '0';
    led_data_changing <= blink_state WHEN data_change_counter > 100 ELSE '0';
    
END Behavioral;

---------------------------------------------------------------------------------
-- 使用说明和问题诊断：
---------------------------------------------------------------------------------
-- 连接方式：
-- camera_debug_inst : camera_debug
-- port map (
--     clk => clk,
--     reset => reset,
--     pclk => camera_pclk,
--     vsync => camera_vsync, 
--     href => camera_href,
--     dport => camera_data,
--     led_pclk_active => led(0),
--     led_vsync_active => led(1),
--     led_href_active => led(2),
--     led_data_changing => led(3),
--     camera_working => led(7)
-- );
--
-- LED指示含义：
-- led(0) 闪烁 = PCLK信号正常 (你已经确认有12.5MHz)
-- led(1) 闪烁 = VSYNC信号正常 (帧同步)
-- led(2) 闪烁 = HREF信号正常 (行同步) 
-- led(3) 闪烁 = 数据在变化 (像素数据)
-- led(7) 亮 = 所有信号都正常
--
-- 问题诊断：
-- 1. 只有led(0)亮 -> VSYNC/HREF信号问题，检查摄像头初始化
-- 2. led(0)(1)(2)亮但led(3)不亮 -> 数据线连接问题或摄像头配置错误
-- 3. 所有LED都不亮 -> 摄像头未启动或SCCB通信失败
-- 4. 如果PCLK只有12.5MHz -> 检查CLKRC寄存器配置
---------------------------------------------------------------------------------