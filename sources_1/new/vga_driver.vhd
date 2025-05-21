----------------------------------------------------------------------------------
-- VGA 640x480@60hz
-- http://tinyvga.com/vga-timing/640x480@60Hz
-- Because of picking the high 13 bits of address, each pixel is read at most 8 times. 
-- this results in a strectched 80 x 60 downscale into 480 x 640.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY vga_driver IS
	PORT (
		iVGA_CLK : IN STD_LOGIC;
		r : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		g : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		b : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

		display_mode : IN STD_LOGIC; -- 显示模式: 0=原画面, 1=直方图
		hist_pixel : IN STD_LOGIC_VECTOR(11 DOWNTO 0); -- 来自直方图模块的像素

		hs : OUT STD_LOGIC;
		vs : OUT STD_LOGIC;
		surv : IN STD_LOGIC;
		rgb : IN STD_LOGIC;
		debug : IN NATURAL;
		debug2 : IN NATURAL;
		buffer_addr : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		buffer_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		newframe : OUT STD_LOGIC;
		leftmotion : OUT NATURAL;
		rightmotion : OUT NATURAL

	);
END vga_driver;

ARCHITECTURE Behavioral OF vga_driver IS

	CONSTANT hRes : NATURAL := 640;
	CONSTANT vRes : NATURAL := 480;

	CONSTANT hMax : NATURAL := 799;
	CONSTANT hStartSync : NATURAL := 656;
	CONSTANT hEndSync : NATURAL := 752;

	CONSTANT vMax : NATURAL := 524;
	CONSTANT vStartSync : NATURAL := 490;
	CONSTANT vEndSync : NATURAL := 491;

	SIGNAL hCount : unsigned(9 DOWNTO 0) := (OTHERS => '0');
	SIGNAL vCount : unsigned(9 DOWNTO 0) := (OTHERS => '0');
	SIGNAL address : unsigned(16 DOWNTO 0) := (OTHERS => '0');
	SIGNAL blank : STD_LOGIC := '1';
	SIGNAL compare : STD_LOGIC := '0';
	SIGNAL tempbuff : STD_LOGIC := '1';

	SIGNAL sumright : NATURAL := 0;
	SIGNAL sumleft : NATURAL := 0;
BEGIN
	buffer_addr <= STD_LOGIC_VECTOR(address(15 DOWNTO 3));

	PROCESS (iVGA_CLK)
		VARIABLE r0 : unsigned (3 DOWNTO 0);
		VARIABLE g0 : unsigned (3 DOWNTO 0);
		VARIABLE b0 : unsigned (3 DOWNTO 0);

	BEGIN

		IF rising_edge(iVGA_CLK) THEN

			sumleft <= 0;
			sumright <= 0;
			IF hCount = hMax THEN
				hCount <= (OTHERS => '0');
				IF vCount = vMax THEN
					vCount <= (OTHERS => '0');
				ELSE
					vCount <= vCount + 1;
				END IF;
			ELSE
				hCount <= hCount + 1;
			END IF;

			IF display_mode = '0' OR surv = '1' THEN
				-- 原始画面显示（保留现有逻辑）
				IF blank = '0' THEN
					r <= buffer_data(15 DOWNTO 12); -- 红色取高4位（从5位）
					g <= buffer_data(9 DOWNTO 6); -- 绿色取中间4位（从6位）
					b <= buffer_data(4 DOWNTO 1); -- 蓝色取高4位（从5位）
				ELSE
					r <= (OTHERS => '0');
					g <= (OTHERS => '0');
					b <= (OTHERS => '0');
				END IF;

			ELSE 				-- 直方图显示，从hist_pixel中取值
				IF blank = '0' THEN
					r <= hist_pixel(11 DOWNTO 8);
					g <= hist_pixel(7 DOWNTO 4);
					b <= hist_pixel(3 DOWNTO 0);
				ELSE
					r <= (OTHERS => '0');
					g <= (OTHERS => '0');
					b <= (OTHERS => '0');
				END IF;
			END IF;

			IF vCount >= vRes THEN
				address <= (OTHERS => '0');
				blank <= '1';
			ELSE
				IF hCount < hRes THEN
					blank <= '0';
					IF hCount = hRes - 1 THEN
						IF vCount(2 DOWNTO 0) /= "111" THEN
							address <= address - hRes + 1; ---debug +debug2; -- I dont know why its 641 (/8 = 81). But it works.
						ELSE
							address <= address + 1;
						END IF;
					ELSIF vCount(1) /= '1' THEN -- Blank every other
						blank <= '1';
						address <= address + 1;
					ELSE
						address <= address + 1;
					END IF;
				ELSE
					blank <= '1';
				END IF;
			END IF;

			IF hCount >= hStartSync AND hCount < hEndSync THEN
				hs <= '1';
			ELSE
				hs <= '0';
			END IF;

			IF vCount >= vStartSync AND vCount < vEndSync THEN
				vs <= '1';
			ELSE
				vs <= '0';
			END IF;
		END IF; -- end rising edge
	END PROCESS;
END Behavioral;