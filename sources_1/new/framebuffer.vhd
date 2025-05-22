LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY framebuffer IS
    PORT (
        -- 写入接口（320x240分辨率 = 76,800像素）
        data       : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        wraddress  : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位支持76,800像素
        wrclock    : IN STD_LOGIC;
        wren       : IN STD_LOGIC;
        
        -- 读取接口（320x240分辨率 = 76,800像素）
        rdaddress  : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位支持76,800像素
        rdclock    : IN STD_LOGIC;
        q          : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END ENTITY framebuffer;

ARCHITECTURE rtl OF framebuffer IS
    -- True Dual Port BRAM IP核组件声明
    COMPONENT blk_mem_gen_0
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            clkb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addrb : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
            dinb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;
    
    -- 内部信号定义
    SIGNAL port_a_we : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL port_b_we : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL port_a_en : STD_LOGIC;
    SIGNAL port_b_en : STD_LOGIC;
    SIGNAL unused_douta : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 端口A读输出(写端口，通常不使用)
    
    -- 地址边界检查
    CONSTANT MAX_ADDRESS : INTEGER := 76799; -- 320*240-1
    SIGNAL wr_addr_valid : STD_LOGIC;
    SIGNAL rd_addr_valid : STD_LOGIC;
    
BEGIN
    -- 地址有效性检查
    wr_addr_valid <= '1' WHEN to_integer(unsigned(wraddress)) <= MAX_ADDRESS ELSE '0';
    rd_addr_valid <= '1' WHEN to_integer(unsigned(rdaddress)) <= MAX_ADDRESS ELSE '0';
    
    -- 端口控制信号
    port_a_en <= '1';                              -- 端口A始终使能（写端口）
    port_a_we(0) <= wren AND wr_addr_valid;       -- 写使能 + 地址有效性检查
    
    port_b_en <= rd_addr_valid;                    -- 端口B使能（读端口）
    port_b_we(0) <= '0';                           -- 端口B仅用于读取，写使能固定为0
    
    -- True Dual Port BRAM IP核实例化
    framebuffer_bram : blk_mem_gen_0
        PORT MAP (
            -- 端口A: 专用于写操作（相机数据写入）
            clka => wrclock,                       -- 写时钟（相机像素时钟）
            ena => port_a_en,                      -- 端口A使能
            wea => port_a_we,                      -- 写使能信号（矢量形式）
            addra => wraddress,                    -- 写地址
            dina => data,                          -- 写数据
            douta => unused_douta,                 -- 端口A读输出（不使用）
            
            -- 端口B: 专用于读操作（VGA显示读取）
            clkb => rdclock,                       -- 读时钟（VGA像素时钟）
            enb => port_b_en,                      -- 端口B使能
            web => port_b_we,                      -- 端口B写使能（固定为0）
            addrb => rdaddress,                    -- 读地址
            dinb => (OTHERS => '0'),               -- 端口B写数据（不使用，固定为0）
            doutb => q                             -- 读数据输出
        );

END ARCHITECTURE rtl;