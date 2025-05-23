----------------------------------------------------------------------------------
-- Register settings
-- Purpose: Load register values before sending.
--------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_registers IS
	PORT (
		iclk : IN STD_LOGIC;
		gostate : IN STD_LOGIC;
		sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
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

	CONSTANT write_address : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"42";
	CONSTANT read_address : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"43";

	SIGNAL test2 : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL test3 : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL test4 : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL test5 : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL fps_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"6b4a";
	SIGNAL colour_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"1204";
	SIGNAL resend : STD_LOGIC; --resend registers
	SIGNAL survmode : STD_LOGIC;
BEGIN

	b1 : debounce PORT MAP
	(
		clk => iclk,
		i => key(2),
		o => resend
	);

	regs <= sreg;
	WITH sreg SELECT reg_loaded <= '1' WHEN x"FFFF", '0' WHEN OTHERS;
	WITH sw(0) SELECT colour_reg <= x"1200" WHEN '1', x"1204" WHEN OTHERS;
	WITH sw(1) SELECT fps_reg <= x"6bca" WHEN '1', x"6b4a" WHEN OTHERS;
	WITH sw(2) SELECT test2 <= x"4fff" WHEN '1', x"4fb3" WHEN OTHERS;
	WITH sw(3) SELECT test3 <= x"50ff" WHEN '1', x"50b3" WHEN OTHERS;
	WITH sw(4) SELECT test4 <= x"51ff" WHEN '1', x"5100" WHEN OTHERS;
	WITH sw(7) SELECT survmode <= '1' WHEN '1', '0' WHEN OTHERS;

	PROCESS (iclk)
	BEGIN
		IF rising_edge(iclk) THEN
			IF gostate = '1' THEN
				--Ready for the next item.
				nextRegAddr <= STD_LOGIC_VECTOR(unsigned(nextRegAddr) + 1);
			ELSIF resend = '1' THEN
				nextRegAddr <= (OTHERS => '0');
			END IF;

			--   if survmode = '0' then
			CASE nextRegAddr IS
					-- =====================================================
					-- 1. 系统复位和基本时钟配置
					-- =====================================================
				WHEN x"00" => sreg <= x"1280"; -- COM7   系统复位 - 复位所有寄存器到默认值
				WHEN x"01" => sreg <= x"1280"; -- COM7   系统复位 - 再次复位确保清除完全
				WHEN x"02" => sreg <= x"11C0"; -- CLKRC  不进行内部时钟分频
				WHEN x"03" => sreg <= x"70BA"; -- SCALING_XSC 水平缩放系数 - 默认值，可设置测试图案
				WHEN x"04" => sreg <= x"7135"; -- SCALING_YSC 垂直缩放系数 - 默认值，可设置测试图案


					-- =====================================================
					-- 2. 输出格式和数据配置
					-- =====================================================
				-- WHEN x"03" => sreg <= colour_reg; -- COM7   输出格式配置 - VGA + RGB输出模式
				-- when x"03" => sreg <= x"1214"; -- COM7   输出格式配置 - QGVA + RGB 不使能彩条
				-- WHEN x"04" => sreg <= x"1E30"; -- MVFP  镜像翻转控制 - 水平翻转和垂直翻转使能
				-- WHEN x"05" => sreg <= x"3E19"; -- COM14  通用控制14 - PCLK分频=2，手动缩放使能
				-- WHEN x"06" => sreg <= x"4010"; -- COM15  通用控制15 - 全范围0-255输出，RGB565格式
				-- WHEN x"07" => sreg <= x"3A04"; -- TSLB   行缓冲测试选项 - 设置UV输出顺序，不自动复位窗口
				-- WHEN x"08" => sreg <= x"8C02"; -- RGB444 RGB444格式控制 - RGB444设置（必须为低电平使RGB565工作）

					-- =====================================================
					-- 3. 图像窗口和帧时序配置
					-- =====================================================
				-- WHEN x"09" => sreg <= x"1714"; -- HSTART 行频开始位置（高8位） - HREF起始位置
				-- WHEN x"0A" => sreg <= x"1802"; -- HSTOP  行频结束位置（高8位） - HREF结束位置
				-- WHEN x"0B" => sreg <= x"32A4"; -- HREF   水平参考信号控制 - 边缘偏移和HSTART/HSTOP低3位
				-- WHEN x"0C" => sreg <= x"1903"; -- VSTART 场频开始位置（高8位） - VSYNC起始位置
				-- WHEN x"0D" => sreg <= x"1A7B"; -- VSTOP  场频结束位置（高8位） - VSYNC结束位置
				-- WHEN x"0E" => sreg <= x"038A"; -- VREF   帧竖直方向控制 - VSYNC低2位和AGC高2位

					-- =====================================================
					-- 4. 图像缩放和像素时钟配置
					-- =====================================================
				-- WHEN x"0F" => sreg <= x"70BA"; -- SCALING_XSC 水平缩放系数 - 默认值，可设置测试图案
				-- WHEN x"10" => sreg <= x"71B5"; -- SCALING_YSC 垂直缩放系数 - 默认值，可设置测试图案
				-- WHEN x"11" => sreg <= x"7211"; -- SCALING_DCWCTR DCW控制 - 水平8倍降采样
				-- WHEN x"12" => sreg <= x"7301"; -- SCALING_PCLK_DIV 像素时钟分频 - 2分频，需与COM14匹配
				-- WHEN x"13" => sreg <= x"A200"; -- SCALING_PCLK_DELAY 像素时钟延迟 - PCLK缩放=4，必须与COM14匹配

					-- =====================================================
					-- 5. 自动增益和颜色矩阵配置
					-- =====================================================
				-- WHEN x"14" => sreg <= x"1438"; -- COM9   通用控制9 - AGC增益上限设置
				-- WHEN x"15" => sreg <= test2; -- MTX1   颜色转换矩阵系数1 - RGB颜色空间转换
				-- WHEN x"16" => sreg <= test3; -- MTX2   颜色转换矩阵系数2 - RGB颜色空间转换
				-- WHEN x"17" => sreg <= test4; -- MTX3   颜色转换矩阵系数3 - RGB颜色空间转换
				-- WHEN x"18" => sreg <= x"523D"; -- MTX4   颜色转换矩阵系数4 - RGB颜色空间转换
				-- WHEN x"19" => sreg <= x"53A7"; -- MTX5   颜色转换矩阵系数5 - RGB颜色空间转换
				-- WHEN x"1A" => sreg <= x"54E4"; -- MTX6   颜色转换矩阵系数6 - RGB颜色空间转换
				-- WHEN x"1B" => sreg <= x"589E"; -- MTXS   矩阵符号位和自动对比度控制

					-- =====================================================
					-- 6. 帧率和图像质量控制
					-- =====================================================
				-- WHEN x"1C" => sreg <= fps_reg; -- DBLV   PLL控制寄存器 - 输入时钟倍频设置
				-- WHEN x"1D" => sreg <= x"3DC0"; -- COM13  通用控制13 - 开启GAMMA校正和UV自动调整

				WHEN OTHERS => sreg <= x"FFFF";
			END CASE;

			--   else 
			-- case nextRegAddr is
			--   when x"00" => sreg <= x"1280"; -- COM7   Reset -- Do it twice to make sure its wiped
			--   when x"01" => sreg <= x"1280"; -- COM7   Reset -- choose output format. 
			--   when x"02" => sreg <= x"1101"; -- CLKRC  Prescaler then multiplied by 4 for 25mhz. 30fps.
			--   when x"03" => sreg <= colour_reg; -- COM7   VGA + RGB output
			--   when x"04" => sreg <= x"0C04"; -- COM3  Lots of stuff, enable scaling, all others off
			--   when x"05" => sreg <= x"3E19"; -- COM14  PCLK scaling = 2 when x"05" => sreg <= x"3E00"; -- COM14  PCLK scaling = 0
			--   when x"06" => sreg <= x"4010" ; -- COM15  Full 0-255 output, RGB 565
			--   when x"07" => sreg <= x"3a04"; -- TSLB   Set UV ordering,  do not auto-reset window
			--   --when x"08" => sreg <= x"8C00"; -- RGB444 Set RGB format -- must be low for rgb 565 to work
			--   when x"08" => sreg <= x"8C02"; -- RGB444 
			--   when x"09" => sreg <= x"1714"; -- HSTART HREF start (high 8 bits)
			--   when x"0a" => sreg <= x"1802"; -- HSTOP  HREF stop (high 8 bits)
			--   when x"0b" => sreg <= x"32A4"; -- HREF   Edge offset and low 3 bits of HSTART and HSTOP
			--   when x"0c" => sreg <= x"1903"; -- VSTART VSYNC start (high 8 bits)
			--   when x"0d" => sreg <= x"1A7b"; -- VSTOP  VSYNC stop (high 8 bits) 
			--   when x"0e" => sreg <= x"038a"; -- VREF   VSYNC low two bits
			--   when x"0f" => sreg <= x"703a"; -- SCALING_XSC -- default value. HScale. Can have test pattern.
			--   when x"10" => sreg <= x"7135"; -- SCALING_YSC -- default value. VScale. Can have test pattern.
			--   when x"11" => sreg <= x"7211"; -- SCALING_DCWCTR -- default value. H down sample by 8.
			--   when x"12" => sreg <= x"7301"; -- SCALING_PCLK_DIV -- default: 00. lowerbit = COM14. Prescale by 2.
			--   when x"13" => sreg <= x"a200"; -- SCALING_PCLK_DELAY  PCLK scaling = 4, must match COM14

			--   when x"14" => sreg <= x"1438"; -- COM9  - AGC Celling
			--   when x"15" => sreg <= test2; -- MTX1  - colour conversion matrix
			--   when x"16" => sreg <= test3; -- MTX2  - colour conversion matrix
			--   when x"17" => sreg <= test4; -- MTX3  - colour conversion matrix
			--   --when x"15" => sreg <= x"4fb3"; -- MTX1  - colour conversion matrix
			--   --when x"16" => sreg <= x"50b3"; -- MTX2  - colour conversion matrix
			--   --when x"17" => sreg <= x"5100"; -- MTX3  - colour conversion matrix
			--   when x"18" => sreg <= x"523d"; -- MTX4  - colour conversion matrix
			--   when x"19" => sreg <= x"53a7"; -- MTX5  - colour conversion matrix
			--   when x"1A" => sreg <= x"54e4"; -- MTX6  - colour conversion matrix
			--   --when x"18" => sreg <= x"52" & test2; -- MTX4  - colour conversion matrix
			--   --when x"19" => sreg <= x"53" & test3; -- MTX5  - colour conversion matrix
			--   --when x"1A" => sreg <= x"54" & test4; -- MTX6  - colour conversion matrix
			--   when x"1B" => sreg <= x"589e"; -- MTXS  - Matrix sign and auto contrast
			--   when x"1C" => sreg <= fps_reg; -- DBLV input clock
			--   when x"1d" => sreg <= x"1500"; -- COM10 Use HREF not hSYNC

			--   when x"1e" => sreg <= x"7a20"; -- SLOP
			--   when x"1f" => sreg <= x"7b10"; -- GAM1
			--   when x"20" => sreg <= x"7c1e"; -- GAM2
			--   when x"21" => sreg <= x"7d35"; -- GAM3
			--   when x"22" => sreg <= x"7e5a"; -- GAM4
			--   when x"23" => sreg <= x"7f69"; -- GAM5
			--   when x"24" => sreg <= x"8076"; -- GAM6
			--   when x"25" => sreg <= x"8180"; -- GAM7
			--   when x"26" => sreg <= x"8288"; -- GAM8
			--   when x"27" => sreg <= x"838f"; -- GAM9
			--   when x"28" => sreg <= x"8496"; -- GAM10
			--   when x"29" => sreg <= x"85a3"; -- GAM11
			--   when x"2a" => sreg <= x"86af"; -- GAM12
			--   when x"2b" => sreg <= x"87c4"; -- GAM13
			--   when x"2c" => sreg <= x"88d7"; -- GAM14
			--   when x"2d" => sreg <= x"89e8"; -- GAM15
			--   when x"2e" => sreg <= x"3d80"; -- COM13 - Turn on GAMMA and UV Auto adjust

			--   when others => sreg <= x"ffff";

			-- end case;
			--   end if;

		END IF;
	END PROCESS;
END Behavioral;

-- =====================================================
-- 寄存器功能说明：
-- =====================================================
-- COM7 (0x12): 通用控制7 - 系统复位和输出格式选择
--   位[7]: SCCB寄存器复位 (1=复位)
--   位[2]: RGB输出格式选择
--   位[0]: Raw RGB输出格式选择

-- COM3 (0x0C): 通用控制3 - 缩放和数据格式控制
--   位[3]: 缩放使能 (1=使能)
--   位[2]: DCW使能 (1=使能)

-- COM14 (0x3E): 通用控制14 - 像素时钟分频控制
--   位[4]: DCW和缩小PCLK使能
--   位[3]: 手动缩放使能
--   位[2:0]: PCLK分频系数

-- COM15 (0x40): 通用控制15 - 数据范围和RGB格式
--   位[7:6]: 数据输出范围选择
--   位[5:4]: RGB555/565操作选择

-- TSLB (0x3A): 行缓冲测试选项
--   位[3]: 输出数据顺序控制
--   位[0]: 自动输出窗口控制

-- SCALING_XSC/YSC (0x70/0x71): 水平/垂直缩放系数
--   位[7]: 测试图案控制位
--   位[6:0]: 缩放系数

-- MTX1-6 (0x4F-0x54): 颜色转换矩阵系数
--   用于RGB颜色空间转换和颜色校正

-- MTXS (0x58): 矩阵符号和对比度控制
--   位[7]: 自动对比度中心使能
--   位[5:0]: 颜色矩阵系数符号位

-- DBLV (0x6B): PLL控制
--   位[7:6]: PLL控制 (00=旁路, 01=4x, 10=6x, 11=8x)
--   位[4]: 内部LDO控制

-- COM13 (0x3D): 通用控制13
--   位[7]: Gamma使能
--   位[6]: UV饱和度自动调整




--when x"2e" => sreg <= x"13E0"; -- COM8 - AGC, White balance
--when x"2f" => sreg <= x"0000"; -- GAIN AGC 
--when x"30" => sreg <= x"1000"; -- AECH Exposure
--when x"31" => sreg <= x"0D40"; -- COMM4 - Window Size
--when x"32" => sreg <= x"1418"; -- COMM9 AGC 
--when x"33" => sreg <= x"a505"; -- AECGMAX banding filter step
--when x"34" => sreg <= x"2495"; -- AEW AGC Stable upper limite
--when x"35" => sreg <= x"2533"; -- AEB AGC Stable lower limi
--when x"36" => sreg <= x"26e3"; -- VPT AGC fast mode limits
--when x"37" => sreg <= x"9f78"; -- HRL High reference level
--when x"38" => sreg <= x"A068"; -- LRL low reference level
--when x"39" => sreg <= x"a103"; -- DSPC3 DSP control
--when x"3a" => sreg <= x"A6d8"; -- LPH Lower Prob High
--when x"3b" => sreg <= x"A7d8"; -- UPL Upper Prob Low
--when x"3c" => sreg <= x"A8f0"; -- TPL Total Prob Low
--when x"3d" => sreg <= x"A990"; -- TPH Total Prob High
--when x"3e" => sreg <= x"AA94"; -- NALG AEC Algo select
--when x"3f" => sreg <= x"13E5"; -- COM8 AGC Settings

--when x"16" => sreg <= x"7a20";
--when x"17" => sreg <= x"7b1c";
--when x"18" => sreg <= x"7c28";
--when x"19" => sreg <= x"7d3c";
--when x"1a" => sreg <= x"7e55";
--when x"1b" => sreg <= x"7f68";
--when x"1c" => sreg <= x"8076";
--when x"1d" => sreg <= x"8180";
--when x"1e" => sreg <= x"8288";
--when x"1f" => sreg <= x"838f";
--when x"21" => sreg <= x"8496";
--when x"22" => sreg <= x"85a3";
--when x"23" => sreg <= x"86af";
--when x"24" => sreg <= x"87c4";
--when x"25" => sreg <= x"88d7";
--when x"26" => sreg <= x"89e8";
--when x"27" => sreg <= x"13e0";
--when x"28" => sreg <= x"0000";
--when x"29" => sreg <= x"1000";
--when x"2a" => sreg <= x"0d00";
--when x"2b" => sreg <= x"1428";
--when x"2c" => sreg <= x"a505";
--when x"2d" => sreg <= x"ab07";
--when x"2e" => sreg <= x"2475";
--when x"2f" => sreg <= x"2563";
--when x"30" => sreg <= x"26A5";
--when x"31" => sreg <= x"9f78";
--when x"32" => sreg <= x"a068";
--when x"33" => sreg <= x"a103";
--when x"34" => sreg <= x"a6df";
--when x"35" => sreg <= x"a7df";
--when x"36" => sreg <= x"a8f0";
--when x"37" => sreg <= x"a990";
--when x"38" => sreg <= x"aa94";
--when x"39" => sreg <= x"13e5";
--when x"3a" => sreg <= x"0e61";
--when x"3b" => sreg <= x"0f4b";
--when x"3c" => sreg <= x"1602";
--when x"3d" => sreg <= x"1e07";
--when x"3e" => sreg <= x"2102";
--when x"3f" => sreg <= x"2291";
--when x"40" => sreg <= x"2907";
--when x"41" => sreg <= x"330b";
--when x"42" => sreg <= x"350b";
--when x"43" => sreg <= x"371d";
--when x"44" => sreg <= x"3871";
--when x"45" => sreg <= x"392a";
--when x"46" => sreg <= x"3c78";
--when x"47" => sreg <= x"4d40";
--when x"48" => sreg <= x"4e20";
--when x"49" => sreg <= x"6900";
--when x"4a" => sreg <= x"6b4a";
--when x"4b" => sreg <= x"7419";
--when x"4c" => sreg <= x"8d4f";
--when x"4d" => sreg <= x"8e00";
--when x"4e" => sreg <= x"8f00";
--when x"4f" => sreg <= x"9000";
--when x"50" => sreg <= x"9100";
--when x"51" => sreg <= x"9200";
--when x"52" => sreg <= x"9600";
--when x"53" => sreg <= x"9a80";
--when x"54" => sreg <= x"b084";
--when x"55" => sreg <= x"b10c";
--when x"56" => sreg <= x"b20e";
--when x"57" => sreg <= x"b382";
--when x"58" => sreg <= x"b80a";
--when x"59" => sreg <= x"4314";
--when x"5a" => sreg <= x"44f0";
--when x"5b" => sreg <= x"4534";
--when x"5c" => sreg <= x"4658";
--when x"5d" => sreg <= x"4728";
--when x"5e" => sreg <= x"483a";
--when x"5f" => sreg <= x"5988";
--when x"60" => sreg <= x"5a88";
--when x"61" => sreg <= x"5b44";
--when x"62" => sreg <= x"5c67";
--when x"63" => sreg <= x"5d49";
--when x"64" => sreg <= x"5e0e";
--when x"65" => sreg <= x"6404";
--when x"66" => sreg <= x"6520";
--when x"67" => sreg <= x"6605";
--when x"68" => sreg <= x"9404";
--when x"69" => sreg <= x"9508";
--when x"6a" => sreg <= x"6c0a";
--when x"6b" => sreg <= x"6d55";
--when x"6c" => sreg <= x"6e11";
--when x"6d" => sreg <= x"6f9f";
--when x"6e" => sreg <= x"6a40";
--when x"6f" => sreg <= x"0140";
--when x"70" => sreg <= x"0240";
--when x"71" => sreg <= x"13e7";
--when x"72" => sreg <= x"1500";  
--when x"73" => sreg <= x"4f80";
--when x"74" => sreg <= x"5080";
--when x"75" => sreg <= x"5100";
--when x"76" => sreg <= x"5222";
--when x"77" => sreg <= x"535e";
--when x"78" => sreg <= x"5480";
--when x"79" => sreg <= x"589e";
--when x"7a" => sreg <= x"4108";
--when x"7b" => sreg <= x"3f00";
--when x"7c" => sreg <= x"7505";
--when x"7d" => sreg <= x"76e1";
--when x"7e" => sreg <= x"4c00";
--when x"7f" => sreg <= x"7701";
--when x"80" => sreg <= x"3dc2";	
--when x"81" => sreg <= x"4b09";
--when x"82" => sreg <= x"c960";
--when x"83" => sreg <= x"4138";
--when x"84" => sreg <= x"5640";
--when x"85" => sreg <= x"3411";
--when x"86" => sreg <= x"3b02"; 
--when x"87" => sreg <= x"a489";
--when x"88" => sreg <= x"9600";
--when x"89" => sreg <= x"9730";
--when x"8a" => sreg <= x"9820";
--when x"8b" => sreg <= x"9930";
--when x"8c" => sreg <= x"9a84";
--when x"8d" => sreg <= x"9b29";
--when x"8e" => sreg <= x"9c03";
--when x"8f" => sreg <= x"9d4c";
--when x"90" => sreg <= x"9e3f";