-- =============================================================================
-- 矢量结果存储器 (双端口RAM) - 修正版本
-- 用于存储光流矢量计算结果
-- 端口A：写入端口，端口B：读取端口
-- 地址位宽：8位 (支持256个矢量，实际使用192个)
-- =============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY vector_result_memory IS
    PORT (
        -- 端口A (写入端口)
        clka : IN STD_LOGIC;                           -- 时钟A
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);        -- 写使能A
        addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);      -- 地址A (修正：8位地址)
        dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);      -- 写入数据A
        
        -- 端口B (读取端口)
        clkb : IN STD_LOGIC;                           -- 时钟B
        addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);      -- 地址B (修正：8位地址)
        doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)     -- 读出数据B
    );
END vector_result_memory;

ARCHITECTURE Behavioral OF vector_result_memory IS
    -- 定义存储器类型 (修正：256个矢量存储空间)
    TYPE memory_type IS ARRAY (0 TO 255) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL memory : memory_type := (OTHERS => (OTHERS => '0'));
    
    -- 用于改善时序的寄存器输出
    SIGNAL dout_reg_b : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
BEGIN
    -- 端口A进程 (写入)
    PROCESS(clka)
    BEGIN
        IF rising_edge(clka) THEN
            IF wea(0) = '1' THEN
                memory(TO_INTEGER(UNSIGNED(addra))) <= dina;
            END IF;
        END IF;
    END PROCESS;
    
    -- 端口B进程 (读取)
    PROCESS(clkb)
    BEGIN
        IF rising_edge(clkb) THEN
            dout_reg_b <= memory(TO_INTEGER(UNSIGNED(addrb)));
        END IF;
    END PROCESS;
    
    doutb <= dout_reg_b;
    
END Behavioral;