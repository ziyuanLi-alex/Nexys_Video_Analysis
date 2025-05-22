----------------------------------------------------------------------------------
-- OV7670寄存器配置模块 - 简化版本
-- 硬编码输出：320x240分辨率 + RGB565格式 + 八色条测试图案
-- 移除所有切换功能，专注于稳定输出
--------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_registers IS
	PORT (
		iclk : IN STD_LOGIC;
		gostate : IN STD_LOGIC;
		sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);      -- 保留接口兼容性
		key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);     -- 保留接口兼容性
		regs : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		reg_loaded : OUT STD_LOGIC
	);
END OV7670_registers;

ARCHITECTURE Behavioral OF OV7670_registers IS
	COMPONENT debounce PORT (
		clk : IN STD_LOGIC;
		i : IN STD_LOGIC;
		o : OUT STD_LOGIC
	);
	END COMPONENT;

	SIGNAL sreg : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL nextRegAddr : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL resend : STD_LOGIC;

BEGIN
	-- 重发控制（保留KEY2功能）
	b1 : debounce PORT MAP
	(
		clk => iclk,
		i => key(2),
		o => resend
	);

	regs <= sreg;
	WITH sreg SELECT reg_loaded <= '1' WHEN x"FFFF", '0' WHEN OTHERS;

	PROCESS (iclk)
	BEGIN
		IF rising_edge(iclk) THEN
			IF gostate = '1' THEN
				nextRegAddr <= STD_LOGIC_VECTOR(unsigned(nextRegAddr) + 1);
			ELSIF resend = '1' THEN
				nextRegAddr <= (OTHERS => '0');
			END IF;

			-- 硬编码寄存器配置序列：320x240 RGB565 八色条
			CASE nextRegAddr IS
				-- =====================================================
				-- 基础复位和时钟
				-- =====================================================
				WHEN x"00" => sreg <= x"1280"; -- COM7: 系统复位
				WHEN x"01" => sreg <= x"1280"; -- COM7: 再次复位
				WHEN x"02" => sreg <= x"1101"; -- CLKRC: 2分频 (50MHz->25MHz)

				-- =====================================================
				-- 320x240 + RGB565硬编码配置
				-- =====================================================
				WHEN x"03" => sreg <= x"1214"; -- COM7: QVGA(位4=1) + RGB(位2=1)
				WHEN x"04" => sreg <= x"40D0"; -- COM15: 全范围 + RGB565
				WHEN x"05" => sreg <= x"8C00"; -- RGB444: 禁用

				-- =====================================================
				-- 八色条测试图案硬编码
				-- =====================================================
				WHEN x"06" => sreg <= x"70BA"; -- SCALING_XSC: 八色条(位7=1)
				WHEN x"07" => sreg <= x"71B5"; -- SCALING_YSC: 八色条(位7=0)

				-- =====================================================
				-- QVGA缩放硬编码 (640x480->320x240)
				-- =====================================================
				WHEN x"08" => sreg <= x"0C04"; -- COM3: 使能缩放
				WHEN x"09" => sreg <= x"3E19"; -- COM14: 手动缩放 + PCLK分频
				WHEN x"0A" => sreg <= x"7222"; -- SCALING_DCWCTR: 2倍降采样
				WHEN x"0B" => sreg <= x"7302"; -- SCALING_PCLK_DIV: 2分频
				WHEN x"0C" => sreg <= x"A202"; -- SCALING_PCLK_DELAY: 延迟

				-- =====================================================
				-- 图像窗口硬编码
				-- =====================================================
				WHEN x"0D" => sreg <= x"1714"; -- HSTART: 水平起始
				WHEN x"0E" => sreg <= x"1802"; -- HSTOP: 水平结束
				WHEN x"0F" => sreg <= x"32A4"; -- HREF: 水平参考
				WHEN x"10" => sreg <= x"1903"; -- VSTART: 垂直起始
				WHEN x"11" => sreg <= x"1A7B"; -- VSTOP: 垂直结束
				WHEN x"12" => sreg <= x"038A"; -- VREF: 垂直参考

				-- =====================================================
				-- 时序控制硬编码
				-- =====================================================
				WHEN x"13" => sreg <= x"1500"; -- COM10: 使用HREF
				WHEN x"14" => sreg <= x"3A04"; -- TSLB: RGB数据顺序

				-- =====================================================
				-- 图像处理关闭（保持测试图案纯净）
				-- =====================================================
				WHEN x"15" => sreg <= x"1300"; -- COM8: 关闭AGC/AWB/AEC
				WHEN x"16" => sreg <= x"3D00"; -- COM13: 关闭Gamma
				WHEN x"17" => sreg <= x"1438"; -- COM9: AGC上限

				-- =====================================================
				-- 颜色矩阵硬编码（直通配置）
				-- =====================================================
				WHEN x"18" => sreg <= x"4F80"; -- MTX1: R->R
				WHEN x"19" => sreg <= x"5080"; -- MTX2: R->G  
				WHEN x"1A" => sreg <= x"5100"; -- MTX3: R->B
				WHEN x"1B" => sreg <= x"5222"; -- MTX4: G->R
				WHEN x"1C" => sreg <= x"535E"; -- MTX5: G->G
				WHEN x"1D" => sreg <= x"5480"; -- MTX6: G->B
				WHEN x"1E" => sreg <= x"589E"; -- MTXS: 矩阵符号

				-- =====================================================
				-- PLL硬编码（旁路PLL）
				-- =====================================================
				-- WHEN x"1F" => sreg <= x"6B0A"; -- DBLV: 旁路PLL

				-- 配置完成标志
				WHEN OTHERS => sreg <= x"FFFF";
			END CASE;
		END IF;
	END PROCESS;
END Behavioral;

-- =====================================================
-- 硬编码配置说明：
-- =====================================================
-- 输出分辨率: 320x240 (QVGA)
-- 数据格式: RGB565 (16位/像素)
-- 测试图案: 八色垂直条纹
-- 像素时钟: 25MHz (从50MHz 2分频)
-- 帧率: 约30fps
-- 总像素数: 76,800
-- 
-- 八色条颜色顺序（从左到右）:
-- 白色、黄色、青色、绿色、品红、红色、蓝色、黑色
--
-- 关键寄存器值:
-- COM7(0x12) = 0x14: QVGA + RGB输出
-- COM15(0x40) = 0xD0: RGB565格式
-- SCALING_XSC(0x70) = 0xBA: 八色条使能
-- SCALING_YSC(0x71) = 0x35: 八色条配置