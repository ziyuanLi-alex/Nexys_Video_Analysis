---------------------------------------------------------------------------------
-- OV7670摄像头驱动模块 - 简化版本
-- 原生分辨率：320x240 (QVGA)
-- 数据格式：RGB565 (16位)
-- 总像素数：76,800
-- 地址宽度：17位
-- 
-- 功能：
--   - 按照RGB565时序捕获数据
--   - 匹配ideal_capture的简洁接口
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
        
        -- framebuffer接口（与ideal_capture完全匹配）
        addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0);  -- 17位地址，支持76,800像素
        dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);  -- RGB565数据输出
        we : OUT STD_LOGIC;                         -- 写使能信号

        reset : IN STD_LOGIC                        -- 复位信号（与ideal_capture兼容）
    );
END OV7670_capture;

ARCHITECTURE Behavioral OF OV7670_capture IS
    -- 320x240分辨率常量（与ideal_capture相同）
    CONSTANT QVGA_WIDTH : INTEGER := 320;
    CONSTANT QVGA_HEIGHT : INTEGER := 240;
    CONSTANT TOTAL_PIXELS : INTEGER := QVGA_WIDTH * QVGA_HEIGHT; -- 76,800
    CONSTANT MAX_ADDRESS : INTEGER := TOTAL_PIXELS - 1;         -- 76,799
    
    -- 同步信号（简化为1级同步）
    SIGNAL vsync_reg : STD_LOGIC := '0';
    SIGNAL href_reg : STD_LOGIC := '0';
    SIGNAL data_reg : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    
    -- 边沿检测
    SIGNAL vsync_prev : STD_LOGIC := '0';
    SIGNAL href_prev : STD_LOGIC := '0';
    
    -- RGB565像素组装状态（类似ideal_capture的assembly_state）
    TYPE pixel_assembly_type IS (WAIT_BYTE1, WAIT_BYTE2);
    SIGNAL assembly_state : pixel_assembly_type := WAIT_BYTE1;
    
    -- 数据寄存器
    SIGNAL first_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    
    -- 地址和控制（与ideal_capture相同）
    SIGNAL address_counter : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_enable : STD_LOGIC := '0';
    
    -- 帧和行状态
    SIGNAL frame_active : STD_LOGIC := '0';
    SIGNAL line_active : STD_LOGIC := '0';

BEGIN
    -- 输出端口连接（与ideal_capture相同）
    addr <= address_counter;
    dout <= pixel_data;
    we <= write_enable;
    
    -- 主处理进程（简化逻辑）
    capture_process: PROCESS(pclk, reset)
    BEGIN
        IF reset = '1' THEN
            -- 复位所有状态（与ideal_capture类似）
            vsync_reg <= '0';
            href_reg <= '0';
            data_reg <= (OTHERS => '0');
            vsync_prev <= '0';
            href_prev <= '0';
            assembly_state <= WAIT_BYTE1;
            first_byte <= (OTHERS => '0');
            pixel_data <= (OTHERS => '0');
            address_counter <= (OTHERS => '0');
            write_enable <= '0';
            frame_active <= '0';
            line_active <= '0';
            
        ELSIF rising_edge(pclk) THEN
            -- 输入信号同步
            vsync_reg <= vsync;
            href_reg <= href;
            data_reg <= dport;
            
            -- 保存前一周期的同步信号用于边沿检测
            vsync_prev <= vsync_reg;
            href_prev <= href_reg;
            
            -- 默认状态
            write_enable <= '0';
            
            -- 帧开始检测（上升沿）
            IF vsync_reg = '1' AND vsync_prev = '0' THEN
                -- 新帧开始，复位状态
                address_counter <= (OTHERS => '0');
                assembly_state <= WAIT_BYTE1;
                frame_active <= '1';
                line_active <= '0';
                
            ELSIF frame_active = '1' THEN
                -- 行开始检测
                IF href_reg = '1' AND href_prev = '0' THEN
                    line_active <= '1';
                    assembly_state <= WAIT_BYTE1;  -- 确保每行开始时字节对齐
                    
                -- 行结束检测
                ELSIF href_reg = '0' AND href_prev = '1' THEN
                    line_active <= '0';
                END IF;
                
                -- 像素数据处理（仅在行有效时）
                IF line_active = '1' AND href_reg = '1' THEN
                    CASE assembly_state IS
                        WHEN WAIT_BYTE1 =>
                            -- 接收第一个字节
                            first_byte <= data_reg;
                            assembly_state <= WAIT_BYTE2;
                            
                        WHEN WAIT_BYTE2 =>
                            -- 接收第二个字节并组装像素
                            pixel_data <= first_byte & data_reg;
                            assembly_state <= WAIT_BYTE1;
                            
                            -- 写入framebuffer（地址范围检查）
                            IF unsigned(address_counter) <= MAX_ADDRESS THEN
                                write_enable <= '1';
                                address_counter <= STD_LOGIC_VECTOR(unsigned(address_counter) + 1);
                            END IF;
                    END CASE;
                END IF;
                
                -- 帧结束检测
                IF vsync_reg = '1' OR unsigned(address_counter) >= TOTAL_PIXELS THEN
                    frame_active <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS capture_process;
    
END Behavioral;

---------------------------------------------------------------------------------
-- 主要简化改进：
---------------------------------------------------------------------------------
-- 1. 【接口统一】：
--    - 添加reset输入，与ideal_capture兼容
--    - 移除不必要的enable和frame_done信号
--    - 保持相同的端口名称和类型
--
-- 2. 【逻辑简化】：
--    - 移除3级同步，简化为1级同步
--    - 移除复杂的计数器，只保留必要的地址计数器
--    - 简化状态机，只保留核心的像素组装逻辑
--
-- 3. 【状态管理】：
--    - 使用与ideal_capture相同的assembly_state概念
--    - 简化帧和行状态管理
--    - 移除冗余的统计信号
--
-- 4. 【时序匹配】：
--    - 保持RGB565的2字节组装逻辑
--    - 与真实OV7670硬件时序兼容
--    - 输出接口与ideal_capture完全匹配
--
-- 5. 【使用说明】：
--    - 可直接替换原有OV7670_capture模块
--    - 与ideal_capture具有相同的接口
--    - 支持相同的framebuffer写操作时序
---------------------------------------------------------------------------------