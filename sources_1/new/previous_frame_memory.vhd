-- =============================================================================
-- 前一帧存储器 (单端口RAM) - 修正版本
-- 用于存储前一帧图像数据 (灰度8位)
-- =============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY previous_frame_memory IS
    PORT (
        clka : IN STD_LOGIC;                           -- 时钟
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);        -- 写使能
        addra : IN STD_LOGIC_VECTOR(16 DOWNTO 0);     -- 地址 (0-76799 for 320x240)
        dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);       -- 写入数据 (修正：8位灰度)
        douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)      -- 读出数据 (修正：8位灰度)
    );
END previous_frame_memory;

ARCHITECTURE Behavioral OF previous_frame_memory IS
    -- 定义存储器类型 (320*240 = 76800个8位字)
    TYPE memory_type IS ARRAY (0 TO 76799) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL memory : memory_type := (OTHERS => (OTHERS => '0'));
    
    -- 用于改善时序的寄存器输出
    SIGNAL dout_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
    
BEGIN
    PROCESS(clka)
    BEGIN
        IF rising_edge(clka) THEN
            -- 写操作
            IF wea(0) = '1' THEN
                memory(TO_INTEGER(UNSIGNED(addra))) <= dina;
            END IF;
            
            -- 读操作 (寄存器输出用于改善时序)
            dout_reg <= memory(TO_INTEGER(UNSIGNED(addra)));
        END IF;
    END PROCESS;
    
    douta <= dout_reg;
    
END Behavioral;
