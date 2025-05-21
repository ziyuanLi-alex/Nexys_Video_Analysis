LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY framebuffer IS
    PORT (
        -- 写入接口（80x60分辨率 = 4800像素）
        data       : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        wraddress  : IN STD_LOGIC_VECTOR(12 DOWNTO 0); -- 13位足够寻址4800像素
        wrclock    : IN STD_LOGIC;
        wren       : IN STD_LOGIC;
        
        -- 读取接口（支持320x240分辨率 = 76800像素）
        rdaddress  : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位支持76800像素
        rdclock    : IN STD_LOGIC;
        q          : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl OF framebuffer IS
    -- 常量定义
    CONSTANT SMALL_WIDTH  : INTEGER := 80;
    CONSTANT SMALL_HEIGHT : INTEGER := 60;
    CONSTANT LARGE_WIDTH  : INTEGER := 320;
    CONSTANT LARGE_HEIGHT : INTEGER := 240;
    CONSTANT SCALE_FACTOR : INTEGER := 4; -- 320/80 = 240/60 = 4
    
    -- 定义RAM类型用于存储80x60分辨率的图像
    TYPE ram_type IS ARRAY(0 TO SMALL_WIDTH*SMALL_HEIGHT-1) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL ram : ram_type := (OTHERS => (OTHERS => '0'));
    
    -- 读数据寄存器
    SIGNAL rd_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
BEGIN
    -- 写入进程：使用原始13位地址直接存储80x60图像
    write_process: PROCESS(wrclock)
    BEGIN
        IF rising_edge(wrclock) THEN
            IF wren = '1' THEN
                -- 确保地址在有效范围内
                IF to_integer(unsigned(wraddress)) < SMALL_WIDTH*SMALL_HEIGHT THEN
                    ram(to_integer(unsigned(wraddress))) <= data;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- 读取进程：从17位地址计算对应的80x60分辨率中的像素
    read_process: PROCESS(rdclock)
        VARIABLE large_x, large_y : INTEGER;
        VARIABLE small_x, small_y : INTEGER;
        VARIABLE small_addr : INTEGER;
    BEGIN
        IF rising_edge(rdclock) THEN
            -- 从17位地址计算320x240分辨率中的x,y坐标
            large_x := to_integer(unsigned(rdaddress)) MOD LARGE_WIDTH;
            large_y := to_integer(unsigned(rdaddress)) / LARGE_WIDTH;
            
            -- 将320x240坐标转换为对应的80x60坐标
            small_x := large_x / SCALE_FACTOR;
            small_y := large_y / SCALE_FACTOR;
            
            -- 计算80x60分辨率中的地址
            small_addr := small_y * SMALL_WIDTH + small_x;
            
            -- 确保地址在有效范围内
            IF small_addr < SMALL_WIDTH*SMALL_HEIGHT THEN
                rd_data <= ram(small_addr);
            ELSE
                -- 超出范围时返回黑色
                rd_data <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- 输出读取的数据
    q <= rd_data;

END ARCHITECTURE;