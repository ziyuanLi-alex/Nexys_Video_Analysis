---------------------------------------------------------------------------------
-- 目的:
--    地址生成，连接到帧缓冲区
--    数据流，从相机到顶层设计再到VGA显示
--    写使能信号，从相机告知缓冲区何时写入数据
--
-- 使用OV7670的默认HREF和VSYNC设置。

-- 工作周期说明:
--    duty   href_last    hold_data         dout               we 
--    00        0         xxxxxxxxxxxxxxxx  xxxxxxxxxxxxxxxx   0   
--    01        0         xxxxxxxxRRRRRGGG  xxxxxxxxxxxxxxxx   0
--    10        0->1      RRRRRGGGGGGBBBBB  xxxxxxxxRRRRRGGG   0
--    11        0         GGGBBBBBxxxxxxxx  RRRRRGGGGGGBBBBB   1 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_capture IS
	PORT (
		pclk : IN STD_LOGIC;                        -- 相机时钟输入
		vsync : IN STD_LOGIC;                       -- 垂直同步信号
		href : IN STD_LOGIC;                        -- 水平参考信号
		surv : IN STD_LOGIC;                        -- 监控模式（已废弃，保留兼容性）
		sw5 : IN STD_LOGIC;                         -- 调整运动检测速度
		sw6 : IN STD_LOGIC;                         -- 冻结捕获
		dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0);   -- 相机数据输入
		addr : OUT STD_LOGIC_VECTOR (12 DOWNTO 0);  -- 输出地址
		dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);  -- 输出数据
		we : OUT STD_LOGIC;                         -- 写使能信号
		maxx : OUT NATURAL                          -- 最大运动值
	);
END OV7670_capture;

ARCHITECTURE Behavioral OF OV7670_capture IS
	-- 信号延迟说明:
	-- latched信号比当前信号延迟一个时钟周期
	-- hold信号比当前信号延迟两个时钟周期
	
	-- 控制信号
	SIGNAL duty : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');  -- 工作周期计数器
	SIGNAL address : STD_LOGIC_VECTOR(12 DOWNTO 0) := (OTHERS => '0');  -- 内部地址计数器
	SIGNAL we_reg : STD_LOGIC := '0';  -- 内部写使能寄存器
	
	-- 延迟信号
	SIGNAL latched_vsync : STD_LOGIC := '0';  -- 延迟的垂直同步信号
	SIGNAL latched_href : STD_LOGIC := '0';   -- 延迟的水平参考信号
	SIGNAL latched_data : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');  -- 延迟的数据
	SIGNAL hold_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');     -- 保持的数据(RGB565)
	SIGNAL hold_href : STD_LOGIC := '0';      -- 保持的水平参考信号
	
	-- RGB分量存储（未使用）
	SIGNAL holdR : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
	SIGNAL holdG : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
	SIGNAL holdB : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

	-- 水平行计数
	SIGNAL href_last : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');  -- 延迟行检测移位寄存器
	
	-- 其他控制信号
	SIGNAL halfaddress : STD_LOGIC := '0';  -- 未使用
	SIGNAL saveframe : STD_LOGIC := '0';    -- 保存帧标志（已废弃）
	SIGNAL cnt : NATURAL := 0;             -- 像素计数器
	SIGNAL max : NATURAL := 0;             -- 最大运动值
	SIGNAL framecnt : NATURAL := 0;        -- 帧计数器（已废弃）
	SIGNAL framemax : NATURAL := 0;        -- 最大帧数（已废弃）
BEGIN
	-- 根据sw5调整帧率
	WITH sw5 SELECT framemax <= 29 WHEN '0', 14 WHEN OTHERS;

	-- 端口映射
	addr <= address;
	we <= we_reg;
	dout <= hold_data;

	PROCESS (pclk)
	BEGIN
		maxx <= max;
		
		-- 在下降沿捕获数据
		IF falling_edge(pclk) THEN
			latched_data <= dport;
			latched_href <= href;
			latched_vsync <= vsync;
		END IF;

		-- 在上升沿处理数据
		IF rising_edge(pclk) THEN
			-- 当写使能有效时更新最大运动值和地址
			IF we_reg = '1' THEN
				-- 更新最大运动值
				IF cnt > max THEN
					max <= cnt;
				END IF;
				
				-- 简化地址计数器，移除冗余的监控模式代码
				address <= STD_LOGIC_VECTOR(unsigned(address) + 1);
				cnt <= cnt + 1;
			END IF;

			-- 检测水平参考信号的上升沿，更新工作周期
			IF hold_href = '0' AND latched_href = '1' THEN
				duty <= STD_LOGIC_VECTOR(unsigned(duty) + 1);
			END IF;

			-- 更新保持的水平参考信号
			hold_href <= latched_href;
			
			-- 当水平参考信号有效时，捕获相机数据（RGB565格式）
			IF latched_href = '1' THEN
				-- 清除行计数
				href_last <= (OTHERS => '0');
				-- 将当前数据移入保持寄存器
				hold_data <= hold_data(7 DOWNTO 0) & latched_data;
			END IF;

			-- 默认禁用写使能
			we_reg <= '0';

			-- 帧处理逻辑
			IF sw6 = '0' THEN -- 如果未冻结捕获
				-- 帧开始时重置计数器
				IF latched_vsync = '1' THEN
					duty <= (OTHERS => '0');
					href_last <= (OTHERS => '0');
					address <= (OTHERS => '0');
					cnt <= 0;
				ELSE
					-- 行处理逻辑，移除冗余监控模式
					IF href_last(href_last'high) = '1' THEN
						-- 当duty为10时启用写使能
						IF duty = "10" THEN
							we_reg <= '1';
						END IF;
						href_last <= (OTHERS => '0');
					ELSE
						-- 更新行计数移位寄存器
						href_last <= href_last(href_last'high - 1 DOWNTO 0) & latched_href;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END Behavioral;