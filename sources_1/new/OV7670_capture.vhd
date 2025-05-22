---------------------------------------------------------------------------------
-- Purpose:
--    address , referencing whatever buffer
--    data , from camera to _top to vga
--    write enable, from camera to _top to whatever buffer telling it to start writing
--
-- Uses Default HREF and VREF settings from OV7670. 

--    duty   href_last    hold_data         dout		     we 
--    00        0         xxxxxxxxxxxxxxxx  xxxxxxxxxxxxxxxx  0   
--    01        0         xxxxxxxxRRRRRGGG  xxxxxxxxxxxxxxxx  0
--    10        0->1      RRRRRGGGGGGBBBBB  xxxxxxxxRRRRRGGG  0
--    11        0         GGGBBBBBxxxxxxxx  RRRRRGGGGGGBBBBB  1 

----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY OV7670_capture IS
	PORT (
		pclk : IN STD_LOGIC;
		vsync : IN STD_LOGIC;
		href : IN STD_LOGIC;
		surv : IN STD_LOGIC;
		sw5 : IN STD_LOGIC;
		sw6 : IN STD_LOGIC;
		dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		addr : OUT STD_LOGIC_VECTOR (12 DOWNTO 0);
		dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		we : OUT STD_LOGIC;
		maxx : OUT NATURAL
	);
END OV7670_capture;

ARCHITECTURE Behavioral OF OV7670_capture IS
	--In comparison to current href, vync, data.
	--latched means the signal is one cycle late
	--hold means we the signal is two cycles late.
	SIGNAL duty : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL address : STD_LOGIC_VECTOR(12 DOWNTO 0) := (OTHERS => '0');
	SIGNAL we_reg : STD_LOGIC := '0';

	SIGNAL latched_vsync : STD_LOGIC := '0';
	SIGNAL latched_href : STD_LOGIC := '0';
	SIGNAL latched_data : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL hold_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL hold_href : STD_LOGIC := '0';
	SIGNAL holdR : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
	SIGNAL holdG : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
	SIGNAL holdB : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

	-- signal duty         : std_logic_vector(0 downto 0)  := (others => '0'); -- 2x vert
	-- signal href_last    : std_logic_vector(14 downto 0)  := (others => '0'); -- 1/2x 
	SIGNAL href_last : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
	SIGNAL halfaddress : STD_LOGIC := '0';
	SIGNAL saveframe : STD_LOGIC := '0';
	SIGNAL cnt : NATURAL := 0;
	SIGNAL max : NATURAL := 0;
	SIGNAL framecnt : NATURAL := 0;
	SIGNAL framemax : NATURAL := 0;
BEGIN
	WITH sw5 SELECT framemax <= 29 WHEN '0', 14 WHEN OTHERS;

	addr <= address;
	we <= we_reg;
	dout <= hold_data;

	PROCESS (pclk)
	BEGIN
		maxx <= max;
		-- Process at rising edge
		-- Capture at falling edge

		IF falling_edge(pclk) THEN
			latched_data <= dport;
			latched_href <= href;
			latched_vsync <= vsync;
		END IF;

		IF rising_edge(pclk) THEN
			IF we_reg = '1' THEN
				IF cnt > max THEN
					max <= cnt;
				END IF;
				-- IF surv = '1' THEN
				-- 	-- Can't put this inside vsync? I wonder
				-- 	IF saveframe = '0' AND cnt = 0 THEN
				-- 		address <= STD_LOGIC_VECTOR(to_unsigned(1, address'length));
				-- 		IF framecnt = framemax THEN
				-- 			saveframe <= '1';
				-- 		END IF;
				-- 		framecnt <= framecnt + 1;
				-- 	ELSIF saveframe = '1' AND cnt = 0 THEN
				-- 		address <= STD_LOGIC_VECTOR(to_unsigned(2401, address'length));
				-- 		saveframe <= '0';
				-- 		framecnt <= 0;
				-- 	ELSE
				-- 		address <= STD_LOGIC_VECTOR(unsigned(address) + 1);
				-- 	END IF;
				-- ELSE
					address <= STD_LOGIC_VECTOR(unsigned(address) + 1);
				-- END IF;
				cnt <= cnt + 1;
			END IF;

			IF hold_href = '0' AND latched_href = '1' THEN
				duty <= STD_LOGIC_VECTOR(unsigned(duty) + 1);
			END IF;

			hold_href <= latched_href;
			-- capturing the data from the camera, 12-bit RGB
			IF latched_href = '1' THEN
				href_last <= (OTHERS => '0');
				hold_data <= hold_data(7 DOWNTO 0) & latched_data;
			END IF;

			we_reg <= '0';

			-- If a new screen is about to start
			IF sw6 = '0' THEN
				IF latched_vsync = '1' THEN
					duty <= (OTHERS => '0');
					href_last <= (OTHERS => '0');
					address <= (OTHERS => '0');
					cnt <= 0;
				ELSE
					-- IF surv = '1' THEN
					-- 	IF href_last(href_last'high) = '1' THEN
					-- 		IF duty = "10" THEN --and address /= 100101100000
					-- 			IF saveframe = '0' AND cnt < 2400 THEN
					-- 				we_reg <= '1';
					-- 			ELSIF saveframe = '1' AND cnt < 2401 THEN
					-- 				we_reg <= '1';
					-- 			ELSE
					-- 				we_reg <= '0';
					-- 			END IF;
					-- 		END IF;
					-- 		href_last <= (OTHERS => '0');
					-- 	ELSE
					-- 		href_last <= href_last(href_last'high - 1 DOWNTO 0) & latched_href;
					-- 	END IF;
					-- ELSE
						IF href_last(href_last'high) = '1' THEN
							IF duty = "10" THEN
								we_reg <= '1';
							END IF;
							href_last <= (OTHERS => '0');
						ELSE
							href_last <= href_last(href_last'high - 1 DOWNTO 0) & latched_href;
						END IF;
					-- END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END Behavioral;