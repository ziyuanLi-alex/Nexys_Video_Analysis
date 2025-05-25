----------------------------------------------------------------------------------
-- 简化的块匹配单元
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY block_matching_unit IS
    PORT (
        clk : IN STD_LOGIC;
        
        -- 输入块数据 (8x8简化块)
        current_block : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        previous_block : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        block_valid : IN STD_LOGIC;
        
        -- 搜索参数
        search_center_x : IN INTEGER;
        search_center_y : IN INTEGER;
        
        -- 输出最佳匹配位移
        best_offset_x : OUT SIGNED(7 DOWNTO 0);
        best_offset_y : OUT SIGNED(7 DOWNTO 0);
        result_valid : OUT STD_LOGIC
    );
END block_matching_unit;

ARCHITECTURE rtl OF block_matching_unit IS
    TYPE search_state_type IS (IDLE, SEARCHING, DONE);
    SIGNAL search_state : search_state_type := IDLE;
    
    SIGNAL search_dx : INTEGER RANGE -4 TO 4 := -4;
    SIGNAL search_dy : INTEGER RANGE -4 TO 4 := -4;
    SIGNAL best_dx : INTEGER RANGE -4 TO 4 := 0;
    SIGNAL best_dy : INTEGER RANGE -4 TO 4 := 0;
    SIGNAL min_error : UNSIGNED(15 DOWNTO 0) := (OTHERS => '1');
    
    SIGNAL search_counter : INTEGER RANGE 0 TO 100 := 0;
BEGIN

    -- 简化的搜索过程
    search_process : PROCESS(clk)
        VARIABLE current_error : UNSIGNED(15 DOWNTO 0);
        VARIABLE pixel_diff : SIGNED(8 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            CASE search_state IS
                
                WHEN IDLE =>
                    result_valid <= '0';
                    IF block_valid = '1' THEN
                        search_state <= SEARCHING;
                        search_dx <= -4;
                        search_dy <= -4;
                        min_error <= (OTHERS => '1');
                        best_dx <= 0;
                        best_dy <= 0;
                        search_counter <= 0;
                    END IF;
                
                WHEN SEARCHING =>
                    -- 计算当前位移的匹配误差
                    current_error := (OTHERS => '0');
                    
                    -- 简化：只计算8个像素的SAD
                    FOR i IN 0 TO 7 LOOP
                        pixel_diff := SIGNED('0' & current_block(i*8+7 DOWNTO i*8)) - 
                                     SIGNED('0' & previous_block(i*8+7 DOWNTO i*8));
                        current_error := current_error + UNSIGNED(abs(pixel_diff));
                    END LOOP;
                    
                    -- 更新最佳匹配
                    IF current_error < min_error THEN
                        min_error <= current_error;
                        best_dx <= search_dx;
                        best_dy <= search_dy;
                    END IF;
                    
                    -- 更新搜索位置
                    IF search_dx = 4 THEN
                        search_dx <= -4;
                        IF search_dy = 4 THEN
                            search_state <= DONE;
                        ELSE
                            search_dy <= search_dy + 1;
                        END IF;
                    ELSE
                        search_dx <= search_dx + 1;
                    END IF;
                    
                    search_counter <= search_counter + 1;
                
                WHEN DONE =>
                    best_offset_x <= TO_SIGNED(best_dx, 8);
                    best_offset_y <= TO_SIGNED(best_dy, 8);
                    result_valid <= '1';
                    search_state <= IDLE;
                
            END CASE;
        END IF;
    END PROCESS;

END rtl;