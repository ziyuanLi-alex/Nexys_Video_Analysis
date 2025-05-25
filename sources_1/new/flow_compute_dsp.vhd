----------------------------------------------------------------------------------
-- 精简版DSP光流计算单元 - 使用平方差算法
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY flow_compute_dsp IS
    PORT (
        clk : IN STD_LOGIC;
        
        -- 输入4x4像素块
        current_block : IN STD_LOGIC_VECTOR(127 DOWNTO 0);  -- 16x8bit  
        previous_block : IN STD_LOGIC_VECTOR(127 DOWNTO 0); -- 16x8bit
        block_valid : IN STD_LOGIC;
        
        -- 输出运动强度
        motion_intensity : OUT UNSIGNED(7 DOWNTO 0);
        result_valid : OUT STD_LOGIC
    );
END flow_compute_dsp;

ARCHITECTURE rtl OF flow_compute_dsp IS
    SIGNAL valid_reg : STD_LOGIC := '0';
    SIGNAL intensity_reg : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
BEGIN

    compute_process : PROCESS(clk)
        VARIABLE sum_of_squares : UNSIGNED(19 DOWNTO 0);
        VARIABLE pixel_diff : SIGNED(8 DOWNTO 0);
        VARIABLE diff_abs : UNSIGNED(7 DOWNTO 0);
        VARIABLE diff_squared : UNSIGNED(15 DOWNTO 0);
        VARIABLE current_pixel, previous_pixel : UNSIGNED(7 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            -- 延迟valid信号一个时钟周期
            valid_reg <= block_valid;
            
            IF block_valid = '1' THEN
                sum_of_squares := (OTHERS => '0');
                
                -- 计算16个像素的差值平方和
                FOR i IN 0 TO 15 LOOP
                    current_pixel := UNSIGNED(current_block(i*8+7 DOWNTO i*8));
                    previous_pixel := UNSIGNED(previous_block(i*8+7 DOWNTO i*8));
                    
                    -- 计算有符号差值
                    pixel_diff := SIGNED('0' & current_pixel) - SIGNED('0' & previous_pixel);
                    
                    -- 转换为绝对值
                    IF pixel_diff(8) = '1' THEN  -- 负数
                        diff_abs := UNSIGNED(-pixel_diff(7 DOWNTO 0));
                    ELSE  -- 正数
                        diff_abs := UNSIGNED(pixel_diff(7 DOWNTO 0));
                    END IF;
                    
                    -- 平方运算 (DSP会自动推断)
                    diff_squared := diff_abs * diff_abs;
                    
                    -- 累加
                    sum_of_squares := sum_of_squares + diff_squared;
                END LOOP;
                
                -- 归一化到8位输出 (取平方根的近似)
                IF sum_of_squares(19 DOWNTO 12) /= 0 THEN
                    intensity_reg <= TO_UNSIGNED(255, 8);  -- 饱和
                ELSE
                    intensity_reg <= sum_of_squares(11 DOWNTO 4);  -- 简单缩放
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- 输出
    motion_intensity <= intensity_reg;
    result_valid <= valid_reg;

END rtl;