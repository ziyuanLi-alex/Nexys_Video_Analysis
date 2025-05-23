---------------------------------------------------------------------------------
-- OV7670摄像头驱动模块
-- 原生分辨率：320x240 (QVGA)
-- 数据格式：RGB565 (16位)
-- 总像素数：76,800
-- 地址宽度：17位
-- 
-- 功能：
--   - 严格按照RGB565时序捕获数据
--   - 输出直接匹配framebuffer接口
--   - 支持320x240原生分辨率
--   - 自动帧同步和地址管理
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
        
        -- framebuffer接口
        addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0);  -- 17位地址，支持76,800像素
        dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);  -- RGB565数据输出
        we : OUT STD_LOGIC;                         -- 写使能信号
        
        -- 控制和状态接口
        enable : IN STD_LOGIC := '1';               -- 捕获使能信号
        frame_done : OUT STD_LOGIC                 -- 帧捕获完成标志
    );
END OV7670_capture;

ARCHITECTURE Behavioral OF OV7670_capture IS
    -- 320x240分辨率常量
    CONSTANT QVGA_WIDTH : INTEGER := 320;
    CONSTANT QVGA_HEIGHT : INTEGER := 240;
    CONSTANT TOTAL_PIXELS : INTEGER := QVGA_WIDTH * QVGA_HEIGHT; -- 76,800
    CONSTANT MAX_ADDRESS : INTEGER := TOTAL_PIXELS - 1;         -- 76,799
    
    -- 同步寄存器链（防止亚稳态）
    SIGNAL vsync_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_sync : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_sync : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    
    -- 边沿检测
    SIGNAL vsync_rising : STD_LOGIC;
    SIGNAL href_rising : STD_LOGIC;
    SIGNAL href_falling : STD_LOGIC;
    
    -- RGB565像素数据组装
    SIGNAL first_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL byte_toggle : STD_LOGIC := '0'; -- 0=等待第一字节, 1=等待第二字节
    
    -- 地址和控制信号
    SIGNAL address_counter : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_enable : STD_LOGIC := '0';
    SIGNAL capture_active : STD_LOGIC := '0';
    
    -- 帧和行控制
    SIGNAL frame_active : STD_LOGIC := '0';
    SIGNAL line_active : STD_LOGIC := '0';
    SIGNAL frame_complete : STD_LOGIC := '0';
    
    -- 统计和调试信号
    SIGNAL pixel_count : INTEGER RANGE 0 TO TOTAL_PIXELS := 0;
    SIGNAL line_count : INTEGER RANGE 0 TO QVGA_HEIGHT := 0;
    SIGNAL frame_count : INTEGER := 0;
    
    -- 地址和数据有效性检查
    SIGNAL addr_valid : STD_LOGIC;
    SIGNAL data_ready : STD_LOGIC;

BEGIN
    -- 边沿检测信号
    vsync_rising <= NOT vsync_sync(2) AND vsync_sync(1);
    href_rising <= NOT href_sync(2) AND href_sync(1);
    href_falling <= href_sync(2) AND NOT href_sync(1);
    
    -- 地址有效性检查
    addr_valid <= '1' WHEN unsigned(address_counter) <= MAX_ADDRESS ELSE '0';
    
    -- 数据准备就绪检查
    data_ready <= byte_toggle AND line_active AND addr_valid;
    
    -- 输出端口连接
    addr <= address_counter;
    dout <= pixel_data;
    we <= write_enable;
    frame_done <= frame_complete;
    maxx <= pixel_count;

    -- 主处理进程
    capture_process: PROCESS(pclk)
    BEGIN
        IF rising_edge(pclk) THEN
            -- 1. 输入信号同步化（3级同步防止亚稳态）
            vsync_sync <= vsync_sync(1 DOWNTO 0) & vsync;
            href_sync <= href_sync(1 DOWNTO 0) & href;
            data_sync <= dport;
            
            -- 默认状态
            write_enable <= '0';
            frame_complete <= '0';
            
            -- 2. 帧开始检测
            IF vsync_rising = '1' AND enable = '1' THEN
                -- 新帧开始，初始化所有状态
                address_counter <= (OTHERS => '0');
                byte_toggle <= '0';
                frame_active <= '1';
                line_active <= '0';
                pixel_count <= 0;
                line_count <= 0;
                frame_count <= frame_count + 1;
                capture_active <= '1';
                
            ELSIF frame_active = '1' AND capture_active = '1' THEN
                
                -- 3. 行开始/结束处理
                IF href_rising = '1' THEN
                    -- 行开始
                    line_active <= '1';
                    byte_toggle <= '0';  -- 确保每行开始时字节对齐
                    line_count <= line_count + 1;
                    
                ELSIF href_falling = '1' THEN
                    -- 行结束
                    line_active <= '0';
                END IF;
                
                -- 4. 像素数据处理（仅在行有效期间）
                IF line_active = '1' AND href_sync(1) = '1' THEN
                    IF byte_toggle = '0' THEN
                        -- 接收第一个字节：R[4:0] + G[5:3]
                        first_byte <= data_sync;
                        byte_toggle <= '1';
                        
                    ELSE
                        -- 接收第二个字节：G[2:0] + B[4:0]
                        -- 组装完整的RGB565像素
                        pixel_data <= first_byte & data_sync;
                        byte_toggle <= '0';
                        
                        -- 在地址有效范围内写入数据
                        IF addr_valid = '1' THEN
                            write_enable <= '1';
                            pixel_count <= pixel_count + 1;
                            
                            -- 地址递增
                            address_counter <= STD_LOGIC_VECTOR(unsigned(address_counter) + 1);
                        END IF;
                    END IF;
                END IF;
                
                -- 5. 帧结束检测
                IF line_count >= QVGA_HEIGHT OR 
                   pixel_count >= TOTAL_PIXELS OR
                   vsync_sync(1) = '1' THEN
                    -- 帧捕获完成
                    frame_active <= '0';
                    capture_active <= '0';
                    frame_complete <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS capture_process;
    
END Behavioral;