----------------------------------------------------------------------------------
-- 光流矢量计算模块
-- 
-- 功能：
-- 1. 从320x240图像计算16x12=192个光流矢量
-- 2. 每个矢量覆盖20x20像素区域
-- 3. 输出有符号8位矢量分量 (±127像素位移)
-- 4. 与箭头显示模块完美对接
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY optical_flow_vector_calculator IS
    GENERIC (
        IMAGE_WIDTH : INTEGER := 320;
        IMAGE_HEIGHT : INTEGER := 240;
        VECTOR_GRID_X : INTEGER := 16;    -- 水平矢量数
        VECTOR_GRID_Y : INTEGER := 12;    -- 垂直矢量数
        BLOCK_SIZE : INTEGER := 20;       -- 每个矢量对应的像素块大小
        SEARCH_RANGE : INTEGER := 4       -- 搜索范围 ±4像素
    );
    PORT (
        -- 时钟和控制
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        
        -- 当前帧输入接口 (连接framebuffer)
        current_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
        current_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        current_valid : IN STD_LOGIC;
        
        -- 帧同步信号
        frame_start : IN STD_LOGIC;    -- 新帧开始信号
        
        -- 矢量输出接口 (连接箭头显示模块)
        vector_request_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- 0-191
        vector_x : OUT SIGNED(7 DOWNTO 0);
        vector_y : OUT SIGNED(7 DOWNTO 0);
        vector_valid : OUT STD_LOGIC;
        
        -- 状态输出
        processing_active : OUT STD_LOGIC;
        vectors_ready : OUT STD_LOGIC;
        current_vector_index : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END optical_flow_vector_calculator;

ARCHITECTURE rtl OF optical_flow_vector_calculator IS

    -- 前一帧存储器
    COMPONENT previous_frame_memory IS
        PORT (
            clka : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    END COMPONENT;

    -- 矢量结果存储器 (双端口RAM)
    COMPONENT vector_result_memory IS
        PORT (
            -- 写端口 (计算侧)
            clka : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);  -- [vector_y, vector_x]
            
            -- 读端口 (箭头显示侧)
            clkb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;

    -- 块匹配计算单元
    COMPONENT block_matching_unit IS
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
    END COMPONENT;

    -- 状态机
    TYPE state_type IS (IDLE, CAPTURE_FRAME, COMPUTE_VECTORS, STORE_RESULTS, COMPLETED);
    SIGNAL state : state_type := IDLE;

    -- 帧处理信号
    SIGNAL pixel_addr : INTEGER RANGE 0 TO IMAGE_WIDTH*IMAGE_HEIGHT-1 := 0;
    SIGNAL current_gray : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL previous_gray : STD_LOGIC_VECTOR(7 DOWNTO 0);
    
    -- 前一帧RAM控制
    SIGNAL prev_frame_we : STD_LOGIC_VECTOR(0 DOWNTO 0) := "0";
    SIGNAL prev_frame_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL prev_frame_din : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL prev_frame_dout : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- 矢量计算信号
    SIGNAL vector_index : INTEGER RANGE 0 TO VECTOR_GRID_X*VECTOR_GRID_Y-1 := 0;
    SIGNAL vecto_grid_x_reg : INTEGER RANGE 0 TO VECTOR_GRID_X-1;
    SIGNAL vecto_grid_y_reg : INTEGER RANGE 0 TO VECTOR_GRID_Y-1;
    SIGNAL vector_center_x : INTEGER RANGE 0 TO IMAGE_WIDTH-1;
    SIGNAL vector_center_y : INTEGER RANGE 0 TO IMAGE_HEIGHT-1;

    -- 块匹配信号
    SIGNAL current_block_data : STD_LOGIC_VECTOR(63 DOWNTO 0) := (OTHERS => '0');
    SIGNAL previous_block_data : STD_LOGIC_VECTOR(63 DOWNTO 0) := (OTHERS => '0');
    SIGNAL block_match_valid : STD_LOGIC := '0';
    SIGNAL computed_offset_x : SIGNED(7 DOWNTO 0);
    SIGNAL computed_offset_y : SIGNED(7 DOWNTO 0);
    SIGNAL match_result_valid : STD_LOGIC;

    -- 矢量存储信号
    SIGNAL vector_store_we : STD_LOGIC_VECTOR(0 DOWNTO 0) := "0";
    SIGNAL vector_store_addr : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL vector_store_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL vector_read_data : STD_LOGIC_VECTOR(15 DOWNTO 0);

    -- 状态标志
    SIGNAL frame_captured : STD_LOGIC := '0';
    SIGNAL computation_complete : STD_LOGIC := '0';

    -- RGB565转灰度函数
    FUNCTION rgb565_to_gray(rgb : STD_LOGIC_VECTOR(15 DOWNTO 0)) 
        RETURN STD_LOGIC_VECTOR IS
        VARIABLE gray : UNSIGNED(7 DOWNTO 0);
    BEGIN
        -- 提取绿色分量作为灰度 (6位扩展到8位)
        gray := UNSIGNED(rgb(10 DOWNTO 5)) & "00";
        RETURN STD_LOGIC_VECTOR(gray);
    END FUNCTION;

    -- 提取8x8块的简化版本 (取样)
    PROCEDURE extract_block_data(
        center_x, center_y : IN INTEGER;
        SIGNAL block_data : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        SIGNAL frame_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
    ) IS
        VARIABLE sample_x, sample_y : INTEGER;
        VARIABLE pixel_addr : INTEGER;
    BEGIN
        -- 简化：在20x20区域内采样8个点组成8x8块
        FOR i IN 0 TO 7 LOOP
            sample_x := center_x - 8 + (i MOD 4) * 4;  -- 采样4个X坐标
            sample_y := center_y - 4 + (i / 4) * 4;    -- 采样2个Y坐标
            
            -- 边界检查
            IF sample_x >= 0 AND sample_x < IMAGE_WIDTH AND 
               sample_y >= 0 AND sample_y < IMAGE_HEIGHT THEN
                block_data(i*8+7 DOWNTO i*8) <= frame_data;
            ELSE
                block_data(i*8+7 DOWNTO i*8) <= x"00";
            END IF;
        END LOOP;
    END PROCEDURE;

BEGIN
    -- vector_grid_x <= vector_grid_x_reg;
    -- vector_grid_y <= vector_grid_y_reg;

    -- 前一帧存储器实例
    prev_frame_mem : previous_frame_memory PORT MAP (
        clka => clk,
        wea => prev_frame_we,
        addra => prev_frame_addr,
        dina => prev_frame_din,
        douta => prev_frame_dout
    );

    -- 矢量结果存储器实例
    vector_result_mem : vector_result_memory PORT MAP (
        clka => clk,
        wea => vector_store_we,
        addra => vector_store_addr,
        dina => vector_store_data,
        
        clkb => clk,
        addrb => vector_request_addr,
        doutb => vector_read_data
    );

    -- 块匹配单元实例
    block_matcher : block_matching_unit PORT MAP (
        clk => clk,
        current_block => current_block_data,
        previous_block => previous_block_data,
        block_valid => block_match_valid,
        search_center_x => vector_center_x,
        search_center_y => vector_center_y,
        best_offset_x => computed_offset_x,
        best_offset_y => computed_offset_y,
        result_valid => match_result_valid
    );

    -- 主状态机
    main_process : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                state <= IDLE;
                vector_index <= 0;
                pixel_addr <= 0;
                frame_captured <= '0';
                computation_complete <= '0';
                processing_active <= '0';
                prev_frame_we <= "0";
                vector_store_we <= "0";
                
            ELSIF enable = '1' THEN
                CASE state IS
                    
                    WHEN IDLE =>
                        processing_active <= '0';
                        computation_complete <= '0';
                        
                        IF frame_start = '1' THEN
                            state <= CAPTURE_FRAME;
                            pixel_addr <= 0;
                            frame_captured <= '0';
                        END IF;
                    
                    WHEN CAPTURE_FRAME =>
                        processing_active <= '1';
                        
                        -- 读取当前帧像素
                        current_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(pixel_addr, 17));
                        
                        IF current_valid = '1' THEN
                            current_gray <= rgb565_to_gray(current_data);
                            
                            -- 同时将当前帧存储为下一次的前一帧
                            prev_frame_we <= "1";
                            prev_frame_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(pixel_addr, 17));
                            prev_frame_din <= current_gray;
                            
                            -- 读取对应的前一帧像素
                            previous_gray <= prev_frame_dout;
                            
                            IF pixel_addr = IMAGE_WIDTH*IMAGE_HEIGHT-1 THEN
                                pixel_addr <= 0;
                                frame_captured <= '1';
                                state <= COMPUTE_VECTORS;
                                vector_index <= 0;
                            ELSE
                                pixel_addr <= pixel_addr + 1;
                            END IF;
                        ELSE
                            prev_frame_we <= "0";
                        END IF;
                    
                    WHEN COMPUTE_VECTORS =>
                        prev_frame_we <= "0";
                        
                        -- 计算当前矢量的网格坐标
                        vecto_grid_x_reg <= vector_index MOD VECTOR_GRID_X;
                        vecto_grid_y_reg <= vector_index / VECTOR_GRID_X;
                        
                        -- 计算矢量中心坐标
                        vector_center_x <= (vecto_grid_x_reg * BLOCK_SIZE) + (BLOCK_SIZE / 2);
                        vector_center_y <= (vecto_grid_y_reg * BLOCK_SIZE) + (BLOCK_SIZE / 2);
                        
                        -- 提取当前块和前一帧块 (简化实现)
                        -- 这里需要实际的块提取逻辑
                        block_match_valid <= '1';
                        
                        -- 等待块匹配结果
                        IF match_result_valid = '1' THEN
                            block_match_valid <= '0';
                            state <= STORE_RESULTS;
                        END IF;
                    
                    WHEN STORE_RESULTS =>
                        -- 存储计算得到的矢量
                        vector_store_we <= "1";
                        vector_store_addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(vector_index, 8));
                        vector_store_data <= STD_LOGIC_VECTOR(computed_offset_y) & 
                                           STD_LOGIC_VECTOR(computed_offset_x);
                        
                        -- 移动到下一个矢量
                        IF vector_index = (VECTOR_GRID_X * VECTOR_GRID_Y - 1) THEN
                            vector_index <= 0;
                            computation_complete <= '1';
                            state <= COMPLETED;
                        ELSE
                            vector_index <= vector_index + 1;
                            state <= COMPUTE_VECTORS;
                        END IF;
                    
                    WHEN COMPLETED =>
                        vector_store_we <= "0";
                        processing_active <= '0';
                        computation_complete <= '1';
                        state <= IDLE;
                    
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -- 矢量输出接口
    vector_output_process : PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            -- 从矢量存储器读取请求的矢量
            vector_x <= SIGNED(vector_read_data(7 DOWNTO 0));   -- 低8位
            vector_y <= SIGNED(vector_read_data(15 DOWNTO 8));  -- 高8位
            vector_valid <= computation_complete;
        END IF;
    END PROCESS;

    -- 状态输出
    vectors_ready <= computation_complete;
    current_vector_index <= STD_LOGIC_VECTOR(TO_UNSIGNED(vector_index, 8));

END rtl;


