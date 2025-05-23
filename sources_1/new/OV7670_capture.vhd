---------------------------------------------------------------------------------
-- OV7670摄像头驱动模块 - 简化宽松版本
-- 功能：最简单的像素捕获，确保有数据输出
-- 策略：只要有PCLK就捕获，2字节拼接成1个像素
---------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_capture IS
    PORT (
        -- 摄像头接口
        pclk : IN STD_LOGIC;                        -- 相机像素时钟
        vsync : IN STD_LOGIC;                       -- 垂直同步信号
        href : IN STD_LOGIC;                        -- 水平参考信号
        dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0);   -- 相机8位数据输入
        
        -- framebuffer接口（与之前保持一致）
        addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0);  -- 17位地址，支持76,800像素
        dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);  -- RGB565数据输出
        we : OUT STD_LOGIC;                         -- 写使能信号

        reset : IN STD_LOGIC                        -- 复位信号
    );
END OV7670_capture;

ARCHITECTURE Behavioral OF OV7670_capture IS
    -- 分辨率常量
    CONSTANT TOTAL_PIXELS : INTEGER := 76800;      -- 320x240
    
    -- 数据寄存器
    SIGNAL first_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    
    -- 地址和控制
    SIGNAL address_counter : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_enable : STD_LOGIC := '0';
    
    -- 像素组装状态
    SIGNAL byte_toggle : STD_LOGIC := '0';          -- 0=第一字节, 1=第二字节
    
    -- VSYNC边沿检测
    SIGNAL vsync_prev : STD_LOGIC := '0';

BEGIN
    -- 输出连接
    addr <= address_counter;
    dout <= pixel_data;
    we <= write_enable;
    
    -- 添加HREF的捕获进程
    capture_process: PROCESS(pclk, reset)
    BEGIN
        IF reset = '1' THEN
            first_byte <= (OTHERS => '0');
            pixel_data <= (OTHERS => '0');
            address_counter <= (OTHERS => '0');
            write_enable <= '0';
            byte_toggle <= '0';
            vsync_prev <= '0';
            
        ELSIF rising_edge(pclk) THEN
            -- 默认状态
            write_enable <= '0';
            vsync_prev <= vsync;
            
            -- VSYNC上升沿复位地址
            IF vsync = '1' AND vsync_prev = '0' THEN
                address_counter <= (OTHERS => '0');
                byte_toggle <= '0';
            
            -- 添加HREF条件：VSYNC为低且HREF为高时处理数据
            ELSIF vsync = '0' AND href = '1' THEN
                IF byte_toggle = '0' THEN
                    -- 收集第一个字节
                    first_byte <= dport;
                    byte_toggle <= '1';
                    
                ELSE
                    -- 收集第二个字节，组装像素
                    pixel_data <= first_byte & dport;
                    -- pixel_data <= dport & first_byte;
                    byte_toggle <= '0';
                    
                    -- 写入像素（地址范围检查）
                    IF unsigned(address_counter) < TOTAL_PIXELS THEN
                        write_enable <= '1';
                        address_counter <= STD_LOGIC_VECTOR(unsigned(address_counter) + 1);
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS capture_process;
    
END Behavioral;

---------------------------------------------------------------------------------
-- 添加HREF的改进策略：
---------------------------------------------------------------------------------
-- 1. 【核心改进】：
--    - 添加HREF条件：vsync = '0' AND href = '1'
--    - 只在有效像素区域内捕获数据
--    - 消除屏幕上方的黑色区域
--
-- 2. 【时序条件】：
--    - VSYNC=0: 不在垂直同步期间
--    - HREF=1: 在有效像素行内
--    - 双重条件确保只捕获有效像素
--
-- 3. 【预期效果】：
--    - 黑色区域应该消失
--    - 图像应该从正确位置开始显示
--    - 地址计数器只在有效像素时递增
--
-- 4. 【如果还有问题】：
--    - 检查HREF信号是否正常（你的调试显示是15kHz，应该正常）
--    - 可能需要检查HREF的极性（高有效还是低有效）
--    - 如果图像仍然不对，可以尝试 href = '0' 来测试极性
---------------------------------------------------------------------------------