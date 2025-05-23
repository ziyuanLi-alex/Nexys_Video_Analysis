---------------------------------------------------------------------------------
-- 真实像素拼装模拟的OV7670_capture测试模块
-- 功能：生成标准8色条图案，模拟真实的2:1像素拼装时序
-- 时序：模拟真实OV7670中2个PCLK周期产生1个像素的特性
-- 分辨率：320x240 (QVGA)
-- 数据格式：RGB565 (16位)
-- 
-- 像素拼装说明：
-- - 真实OV7670在YUV422格式下，需要2个PCLK接收Y和UV数据
-- - 或在RGB格式下，需要2个PCLK接收高字节和低字节
-- - 本模块模拟这种2:1的时序关系
-- 
-- 8色条颜色顺序（从左到右）：
-- 白色(FFFF) - 黄色(FFE0) - 青色(07FF) - 绿色(07E0)
-- 品红(F81F) - 红色(F800) - 蓝色(001F) - 黑色(0000)
---------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ideal_capture IS
    PORT (
        -- 时钟接口（与真实模块兼容）
        pclk : IN STD_LOGIC;                        -- 相机PCLK (~25MHz)
        vsync : IN STD_LOGIC;                       -- 垂直同步信号（可选）
        href : IN STD_LOGIC;                        -- 水平参考信号（可选）
        dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0);   -- 数据输入（未使用）
        
        -- framebuffer接口
        addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0);  -- 17位地址，支持76,800像素
        dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);  -- RGB565数据输出
        we : OUT STD_LOGIC;                         -- 写使能信号（每2个PCLK有效一次）

        reset : IN STD_LOGIC                        -- 复位信号
    );
END ideal_capture;

ARCHITECTURE Behavioral OF ideal_capture IS
    -- 320x240分辨率常量
    CONSTANT QVGA_WIDTH : INTEGER := 320;
    CONSTANT QVGA_HEIGHT : INTEGER := 240;
    CONSTANT TOTAL_PIXELS : INTEGER := QVGA_WIDTH * QVGA_HEIGHT; -- 76,800
    CONSTANT MAX_ADDRESS : INTEGER := TOTAL_PIXELS - 1;         -- 76,799
    
    -- 8色条宽度（每个色条40像素宽）
    CONSTANT COLOR_BAR_WIDTH : INTEGER := QVGA_WIDTH / 8; -- 40像素
    
    -- RGB565颜色定义（8色条标准颜色）
    TYPE color_array_type IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    CONSTANT COLOR_BARS : color_array_type := (
        0 => x"FFFF", -- 白色 (R=31, G=63, B=31)
        1 => x"FFE0", -- 黄色 (R=31, G=63, B=0)
        2 => x"07FF", -- 青色 (R=0,  G=63, B=31)
        3 => x"07E0", -- 绿色 (R=0,  G=63, B=0)
        4 => x"F81F", -- 品红 (R=31, G=0,  B=31)
        5 => x"F800", -- 红色 (R=31, G=0,  B=0)
        6 => x"001F", -- 蓝色 (R=0,  G=0,  B=31)
        7 => x"0000"  -- 黑色 (R=0,  G=0,  B=0)
    );
    
    -- 时序生成器状态
    TYPE state_type IS (IDLE, VSYNC_PERIOD, ACTIVE_LINE, HSYNC_PERIOD);
    SIGNAL current_state : state_type := IDLE;
    
    -- 像素拼装状态 (关键：模拟2:1拼装)
    TYPE pixel_assembly_type IS (WAIT_BYTE1, WAIT_BYTE2);
    SIGNAL assembly_state : pixel_assembly_type := WAIT_BYTE1;
    
    -- 计数器
    SIGNAL pixel_counter : INTEGER RANGE 0 TO QVGA_WIDTH := 0;
    SIGNAL line_counter : INTEGER RANGE 0 TO QVGA_HEIGHT := 0;
    SIGNAL address_counter : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
    
    -- PCLK计数器 (用于2:1拼装时序)
    SIGNAL pclk_counter : INTEGER RANGE 0 TO 1 := 0;
    
    -- 内部控制信号
    SIGNAL internal_vsync : STD_LOGIC := '0';
    SIGNAL internal_href : STD_LOGIC := '0';
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL write_enable : STD_LOGIC := '0';
    
    -- 时序参数（模拟真实OV7670时序）
    CONSTANT VSYNC_LINES : INTEGER := 20;        -- VSYNC脉冲持续PCLK周期数
    CONSTANT HSYNC_PIXELS : INTEGER := 40;       -- 行同步间隔PCLK周期数
    
    -- 时序计数器
    SIGNAL vsync_count : INTEGER RANGE 0 TO VSYNC_LINES := 0;
    SIGNAL hsync_count : INTEGER RANGE 0 TO HSYNC_PIXELS := 0;
    
    -- 状态计数器
    SIGNAL total_pixel_count : INTEGER RANGE 0 TO TOTAL_PIXELS := 0;
    
    -- 颜色索引计算
    SIGNAL color_index : INTEGER RANGE 0 TO 7 := 0;
    
    -- 调试信号
    SIGNAL debug_pclk_per_pixel : INTEGER RANGE 0 TO 2 := 0;
    SIGNAL debug_actual_pixel_freq : STD_LOGIC := '0';  -- 实际像素输出频率指示

BEGIN
    -- 输出端口连接
    addr <= address_counter;
    dout <= pixel_data;
    we <= write_enable;
    
    -- 颜色索引计算（基于像素位置）
    color_index <= pixel_counter / COLOR_BAR_WIDTH WHEN pixel_counter < QVGA_WIDTH ELSE 7;
    
    -- 主状态机进程 - 模拟2:1像素拼装时序
    timing_generator: PROCESS(pclk, reset)
    BEGIN
        IF reset = '1' THEN
            -- 复位所有状态
            current_state <= IDLE;
            assembly_state <= WAIT_BYTE1;
            pixel_counter <= 0;
            line_counter <= 0;
            address_counter <= (OTHERS => '0');
            pclk_counter <= 0;
            internal_vsync <= '0';
            internal_href <= '0';
            write_enable <= '0';
            vsync_count <= 0;
            hsync_count <= 0;
            total_pixel_count <= 0;
            debug_pclk_per_pixel <= 0;
            debug_actual_pixel_freq <= '0';
            
        ELSIF rising_edge(pclk) THEN
            -- 默认状态
            write_enable <= '0';
            debug_actual_pixel_freq <= '0';
            
            CASE current_state IS
                -- 空闲状态，等待开始新帧
                WHEN IDLE =>
                    internal_vsync <= '1';
                    internal_href <= '0';
                    vsync_count <= 0;
                    line_counter <= 0;
                    address_counter <= (OTHERS => '0');
                    total_pixel_count <= 0;
                    assembly_state <= WAIT_BYTE1;
                    pclk_counter <= 0;
                    current_state <= VSYNC_PERIOD;
                
                -- 垂直同步期间（帧开始）
                WHEN VSYNC_PERIOD =>
                    internal_vsync <= '1';
                    internal_href <= '0';
                    
                    IF vsync_count < VSYNC_LINES THEN
                        vsync_count <= vsync_count + 1;
                    ELSE
                        internal_vsync <= '0';
                        current_state <= HSYNC_PERIOD;
                        hsync_count <= 0;
                    END IF;
                
                -- 水平同步期间（行开始）
                WHEN HSYNC_PERIOD =>
                    internal_vsync <= '0';
                    internal_href <= '0';
                    
                    IF hsync_count < HSYNC_PIXELS THEN
                        hsync_count <= hsync_count + 1;
                    ELSE
                        IF line_counter < QVGA_HEIGHT THEN
                            current_state <= ACTIVE_LINE;
                            pixel_counter <= 0;
                            internal_href <= '1';
                            assembly_state <= WAIT_BYTE1;
                            pclk_counter <= 0;
                        ELSE
                            -- 帧结束，返回空闲状态
                            current_state <= IDLE;
                        END IF;
                    END IF;
                
                -- 活跃行期间（像素数据传输）- 关键的2:1拼装逻辑
                WHEN ACTIVE_LINE =>
                    internal_vsync <= '0';
                    internal_href <= '1';
                    
                    IF pixel_counter < QVGA_WIDTH THEN
                        -- 2:1像素拼装状态机
                        CASE assembly_state IS
                            WHEN WAIT_BYTE1 =>
                                -- 第1个PCLK周期：准备像素数据但不输出
                                pixel_data <= COLOR_BARS(color_index);
                                assembly_state <= WAIT_BYTE2;
                                debug_pclk_per_pixel <= 1;
                                
                            WHEN WAIT_BYTE2 =>
                                -- 第2个PCLK周期：输出完整像素
                                write_enable <= '1';
                                debug_actual_pixel_freq <= '1';  -- 指示实际像素输出
                                assembly_state <= WAIT_BYTE1;
                                debug_pclk_per_pixel <= 2;
                                
                                -- 更新像素计数器（只在输出像素时更新）
                                pixel_counter <= pixel_counter + 1;
                                total_pixel_count <= total_pixel_count + 1;
                                
                                -- 更新地址计数器
                                IF unsigned(address_counter) < MAX_ADDRESS THEN
                                    address_counter <= STD_LOGIC_VECTOR(unsigned(address_counter) + 1);
                                END IF;
                        END CASE;
                        
                    ELSE
                        -- 行结束
                        internal_href <= '0';
                        line_counter <= line_counter + 1;
                        current_state <= HSYNC_PERIOD;
                        hsync_count <= 0;
                        assembly_state <= WAIT_BYTE1;
                    END IF;
                
                WHEN OTHERS =>
                    current_state <= IDLE;
            END CASE;
        END IF;
    END PROCESS timing_generator;
    
END Behavioral;

---------------------------------------------------------------------------------
-- 关键改进说明：
---------------------------------------------------------------------------------
-- 1. 【像素拼装状态机】：
--    - WAIT_BYTE1: 第1个PCLK，准备数据但不写入
--    - WAIT_BYTE2: 第2个PCLK，写入完整像素
--    - 这样模拟了真实OV7670的2:1时序关系
--
-- 2. 【时钟频率关系】：
--    - PCLK频率: ~25MHz (输入)
--    - 实际像素输出频率: ~12.5MHz (输出)
--    - 符合真实硬件的时序特性
--
-- 3. 【调试信号】：
--    - debug_pclk_per_pixel: 显示当前PCLK计数
--    - debug_actual_pixel_freq: 实际像素输出频率指示
--
-- 4. 【使用说明】：
--    - 直接替换原有ideal_capture模块
--    - we信号现在每2个PCLK周期才有效一次
--    - 更准确地模拟了真实摄像头的时序特性
---------------------------------------------------------------------------------