----------------------------------------------------------------------------------
-- Project1_top.vhd
--
-- LEDG<OddNumbers>: Show Key pressed
-- LEDG0 flashing: once per second.
-- LEDG4: Registers finished loading 
-- Register default value check LEDG7.
-- 
-- KEY0: Adjust motion threshold (Debug)
-- KEY1: Adjust motion threshold (Debug2)
-- KEY2: Resend registers
-- KEY3: Reset MAX for LEDDisplay
--
-- LED Display:  Displays the maximum motion of pixels (for debugging).
-- 
-- SW0 : Colour mode (RGB, YCbCr)
-- SW1 : 30/60 FPS
-- SW2 -> SW4 : Colour matrix test
-- SW5 : Adjust speed of motion detector
-- SW6 : Freeze the capture
-- SW7 : Surv mode, display motion
-- SW8 : Surv mode, example
-- SW9 : Normal capture mode.
--
-- Left motion: High pitched sound
-- Right motion: Low pitched sound
-- Center: Gurgle sound.
--
-- The flowchart
--    Top -> buffer, vga, capture data, camera driver, audio
--    camera driver -> settings for camera, i2c to camera to set settings
--
--
-- Future Prospects: 1. Save frame to SD Card. 
-- 2. PWM a DC motor to turn camera via left/right detection.
-- 3. Cleanup TOP.vhd 
--
-- j.inspir3@gmail.com, Git: BurningKoy
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY Project1_top IS
  PORT (
    CLOCK_100 : IN STD_LOGIC;
    OV7670_SIOC : OUT STD_LOGIC;
    OV7670_SIOD : INOUT STD_LOGIC;
    OV7670_VSYNC : IN STD_LOGIC;
    OV7670_HREF : IN STD_LOGIC;
    OV7670_PCLK : IN STD_LOGIC;
    OV7670_XCLK : OUT STD_LOGIC;
    OV7670_D : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    OV7670_RESET : OUT STD_LOGIC;
    OV7670_PWDN : OUT STD_LOGIC;

    VGA_R : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    VGA_G : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    VGA_B : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    VGA_HS : OUT STD_LOGIC;
    VGA_VS : OUT STD_LOGIC;

    number : IN STD_LOGIC_VECTOR (15 DOWNTO 0); -- 8位数字的输入数据(每个数字4位，共8*4=32位)
    seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0); -- 段码(最低位为小数点)
    an : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    SW : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    -- KEY : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    btnu : IN STD_LOGIC;
    btnd : IN STD_LOGIC;
    btnl : IN STD_LOGIC;
    btnr : IN STD_LOGIC;

    -- LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    -- LEDR : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
    LED : out std_logic_vector(15 downto 0);
    LEDB1 : OUT STD_LOGIC;
    LEDB2 : OUT STD_LOGIC

  );
END Project1_top;

ARCHITECTURE rtl OF Project1_top IS

  ----------------------------------------------------------------
  --- COMPONENTS
  ---------------------------------------------------------------- 

  COMPONENT display
    PORT (
      clk : IN STD_LOGIC; -- 100MHz系统时钟
      number : IN STD_LOGIC_VECTOR (15 DOWNTO 0); -- 8位数字的输入数据(每个数字4位，共8*4=32位)
      seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0); -- 段码(最低位为小数点)
      an : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)); -- 位选信号
  END COMPONENT;

  COMPONENT clk_wiz_0
    PORT (-- Clock in ports
      -- Clock out ports
      clk_100M : OUT STD_LOGIC;
      clk_50M : OUT STD_LOGIC;
      clk_200M : OUT STD_LOGIC;
      clk_25M : OUT STD_LOGIC;
      -- Status and control signals
      locked : OUT STD_LOGIC;
      clk_in : IN STD_LOGIC
    );
  END COMPONENT;
  
  COMPONENT OV7670_driver
    PORT (
      iclk50 : IN STD_LOGIC;
      config_finished : OUT STD_LOGIC;
      sioc : OUT STD_LOGIC;
      siod : INOUT STD_LOGIC;
      sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      key : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
      --readcheck : OUT std_logic_vector (7 downto 0)
    );
  END COMPONENT;

  -- OVCapture gets the data from OV7670 camera

  COMPONENT OV7670_capture
    PORT (
      pclk : IN STD_LOGIC; -- camera clock
      vsync : IN STD_LOGIC;
      href : IN STD_LOGIC;
      dport : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- data        
      surv : IN STD_LOGIC;
      sw5 : IN STD_LOGIC;
      sw6 : IN STD_LOGIC;
      addr : OUT STD_LOGIC_VECTOR(12 DOWNTO 0); --test 18, 14 previous
      dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      we : OUT STD_LOGIC; -- write enable
      maxx : OUT NATURAL -- write enable
    );
  END COMPONENT;

  -- VGA determines the active area as well as gets the data from frame buffer
  --  Does the final setting of  r g b  output to the screen
  component vga_driver
    GENERIC (
        -- VGA Timing parameters (default 640x480 @ 60Hz)
        H_VISIBLE_AREA : INTEGER := 640;
        H_FRONT_PORCH  : INTEGER := 16;
        H_SYNC_PULSE   : INTEGER := 96;
        H_BACK_PORCH   : INTEGER := 48;
        H_WHOLE_LINE   : INTEGER := 800;
        V_VISIBLE_AREA : INTEGER := 480;
        V_FRONT_PORCH  : INTEGER := 10;
        V_SYNC_PULSE   : INTEGER := 2;
        V_BACK_PORCH   : INTEGER := 33;
        V_WHOLE_FRAME  : INTEGER := 525;
        
        -- Frame buffer dimensions (for the 80x60 test pattern)
        FB_WIDTH       : INTEGER := 80;
        FB_HEIGHT      : INTEGER := 60;
        
        -- Color format (default RGB565)
        RED_BITS       : INTEGER := 5;
        GREEN_BITS     : INTEGER := 6;
        BLUE_BITS      : INTEGER := 5;
        
        -- Output color depth (VGA output bits per color)
        OUTPUT_BITS    : INTEGER := 4
    );
    PORT (
        -- Clock and reset
        clk            : IN  STD_LOGIC;  -- Pixel clock
        rst            : IN  STD_LOGIC;  -- Reset signal
        
        -- Frame buffer interface
        fb_addr        : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);  -- For 80x60 = 4800 pixels
        fb_data        : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);  -- RGB565 pixel data
        
        -- VGA outputs
        hsync          : OUT STD_LOGIC;
        vsync          : OUT STD_LOGIC;
        red            : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        green          : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        blue           : OUT STD_LOGIC_VECTOR(OUTPUT_BITS-1 DOWNTO 0);
        
        -- Display resolution selection (optional for future use)
        resolution_sel : IN  STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"  -- 00: 640x480, 01: 320x240, 10: 800x600
    );
  END COMPONENT;
  

  -- The frame buffer is reference by OVdriver
  -- and data input is by OVCapture
  COMPONENT framebuffer
    PORT (
      data : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR (12 DOWNTO 0);
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;
      rdaddress : IN STD_LOGIC_VECTOR (12 DOWNTO 0);
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR (15 DOWNTO 0)--data OUT
    );
  END COMPONENT;

  ----------------------------------------------------------------
  --- Variables
  ----------------------------------------------------------------
  SIGNAL xclk : STD_LOGIC := '0'; -- This will now be driven by clk_wiz_0

  -- Signals for clk_wiz_0 outputs
  SIGNAL clk_100M : STD_LOGIC; -- 100MHz output from clk_wiz_0 (if needed, or a buffered version)
  SIGNAL clk_50M : STD_LOGIC; -- 50MHz output from clk_wiz_0
  SIGNAL clk_200M : STD_LOGIC; -- 200MHz output from clk_wiz_0 (for DDR)
  SIGNAL clk_25M : STD_LOGIC; -- 25MHz output from clk_wiz_0
  SIGNAL locked : STD_LOGIC; -- Lock signal from clk_wiz_0

  CONSTANT CLOCK_50_FREQ : INTEGER := 50000000;
  CONSTANT BLINK_FREQ : INTEGER := 1;
  CONSTANT CNT_MAX : INTEGER := CLOCK_50_FREQ/BLINK_FREQ/2 - 1;
  CONSTANT BUZZ_MAX : INTEGER := CLOCK_50_FREQ * 3/BLINK_FREQ/2 - 1;

  --Local wires
  SIGNAL cnt : unsigned(24 DOWNTO 0);
  SIGNAL blink : STD_LOGIC;

  SIGNAL buffer_addr : STD_LOGIC_VECTOR(12 DOWNTO 0) := (OTHERS => '0');
  SIGNAL buffer_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL capture_addr : STD_LOGIC_VECTOR(12 DOWNTO 0);
  SIGNAL capture_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL capture_we : STD_LOGIC; -- write enable.
  SIGNAL config_finished : STD_LOGIC;
  --modes
  SIGNAL surveillance : STD_LOGIC;
  SIGNAL surveillance2 : STD_LOGIC;
  SIGNAL sw5 : STD_LOGIC;
  SIGNAL sw6 : STD_LOGIC;
  SIGNAL survmode : STD_LOGIC;
  SIGNAL rgb : STD_LOGIC;

  --buttons
  SIGNAL KEY : STD_LOGIC_VECTOR(3 DOWNTO 0);

  --debugging
  SIGNAL mSEG7 : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL debug : NATURAL := 0;
  SIGNAL debug2 : NATURAL := 0;
  SIGNAL max : NATURAL := 0;
  SIGNAL leftmotion : NATURAL := 0;
  SIGNAL rightmotion : NATURAL := 0;
  SIGNAL newframe : STD_LOGIC;
  SIGNAL summax : NATURAL := 0;
  --signal motionaddr : std_logic_vector(3 downto 0) := (others => '0');
  --signal sums : unsigned(15 downto 0) := (others => '0');

  --audio
  CONSTANT BUZZER_THRESHOLD : NATURAL := 7500; -- magic number from heuristicsis max should be 320*480 however..
  SIGNAL left : STD_LOGIC;
  SIGNAL AUD_CTRL_CLK : STD_LOGIC;
  SIGNAL buzzer : STD_LOGIC := '0';
  SIGNAL buzzercnt : unsigned(31 DOWNTO 0);
  
  -- DDR相关信号
  SIGNAL rst_ddr : STD_LOGIC := '0'; -- Reset for ddr_framebuffer
  SIGNAL device_temp : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0'); -- Device temperature for DDR
  
BEGIN

  ----------------------------------------------------------------
  --- PORTS
  ----------------------------------------------------------------
-- Button input handling (active-low buttons are converted to active-high signals)
-- 翻转btnupush输入到KEY中
-- WITH KEY(0) SELECT 
--     btnupush <= '1' WHEN '0',     -- When UP button is pressed (KEY(0)='0'), btnupush='1'
--                 '0' WHEN OTHERS;   -- Otherwise, btnupush='0'

-- WITH KEY(1) SELECT 
--     btnlpush <= '1' WHEN '0',     -- When LEFT button is pressed (KEY(1)='0'), btnlpush='1'
--                 '0' WHEN OTHERS;   -- Otherwise, btnlpush='0'

-- -- Note: key 3 used in registers (mentioned in comment)

-- WITH KEY(2) SELECT 
--     btnrpush <= '1' WHEN '0',     -- When RIGHT button is pressed (KEY(2)='0'), btnrpush='1'
--                 '0' WHEN OTHERS;   -- Otherwise, btnrpush='0'

-- WITH KEY(3) SELECT 
--     btndpush <= '1' WHEN '0',     -- When DOWN button is pressed (KEY(3)='0'), btndpush='1'
--                 '0' WHEN OTHERS;   -- Otherwise, btndpush='0'
KEY <= btnd & btnr & btnl & btnu; -- Combine button signals into KEY vector

  -- LED output handling
  -- LEDG <= KEY(3) & '0' & Key(2) & '0' & key(1) & config_finished & KEY(0) & blink;
  -- LEDR <= SW(9) & SW(8) & SW(7) & SW(6) & SW(5) & SW(4) & SW(3) & SW(2) & SW(1) & SW(0);
  -- LED <= blink;
  -- LED <= (others => '0'); -- Initialize all LEDs to off

-- Switch input handling
-- Note: SW1 to 6 used by ovregisters (mentioned in comment)
-- WITH SW(3) SELECT 
--     rgb <= '1' WHEN '1',          -- When SW(3) is ON (SW(3)='1'), rgb='1'
--            '0' WHEN OTHERS;        -- Otherwise, rgb='0'
      rgb <= SW(3);

  -- WITH SW(5) SELECT sw5 <= '1' WHEN '1', '0' WHEN OTHERS;
  -- WITH SW(6) SELECT sw6 <= '1' WHEN '1', '0' WHEN OTHERS;
  -- WITH SW(7) SELECT surveillance <= '1' WHEN '1', '0' WHEN OTHERS;
  -- WITH SW(8) SELECT surveillance2 <= '1' WHEN '1', '0' WHEN OTHERS;
  -- WITH SW(8) SELECT display_mode <= '1' WHEN '1', '0' WHEN OTHERS;
  
  test_pattern_select(2 downto 0) <= SW(2 downto 0); -- Test pattern select

  OV7670_RESET <= '1'; -- Normal mode
  OV7670_PWDN <= '0'; -- Power device up
  OV7670_XCLK <= clk_25M; -- 使用从clk_wiz_0生成的25MHz时钟

  -- 生成DDR复位信号
  PROCESS(clk_50M)
  BEGIN
    IF rising_edge(clk_50M) THEN
      -- 在上电后短暂保持复位状态
      IF cnt < 1000 THEN
        rst_ddr <= '1';
      ELSE
        rst_ddr <= '0';
      END IF;
    END IF;
  END PROCESS;

  -- 时钟生成器
  clk_wiz : clk_wiz_0
  PORT MAP(
    -- Clock out ports  
    clk_100M => clk_100M,
    clk_50M => clk_50M,
    clk_200M => clk_200M,
    clk_25M => clk_25M,
    -- Status and control signals                
    locked => locked,
    -- Clock in ports
    clk_in => CLOCK_100
  );

  -- 七段数码管显示
  disp : display PORT MAP
  (
    clk => CLOCK_100,
    number => mSEG7,
    seg => seg,
    an => an
  );

  -- 摄像头驱动
  ovdr : OV7670_driver PORT MAP
  (
    iclk50 => clk_50M,
    config_finished => config_finished,
    sioc => ov7670_sioc,
    siod => ov7670_siod,
    sw => SW,
    key => KEY
  );
  
  -- VGA驱动
  vga : vga_driver PORT MAP (
    clk => clk_25M,
    rst => '0',
    fb_addr => buffer_addr,
    fb_data => buffer_data,
    hsync => VGA_HS,
    vsync => VGA_VS,
    red => VGA_R,
    green => VGA_G,
    blue => VGA_B,
    resolution_sel => (OTHERS => '0')
  );

  -- 摄像头数据捕获
  ovcap : OV7670_capture PORT MAP
  (
    pclk => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href => OV7670_HREF,
    dport => OV7670_D,
    surv => survmode,
    sw5 => sw5,
    sw6 => sw6,
    addr => capture_addr,
    dout => capture_data,
    maxx => max,
    we => capture_we
  );

    fb : framebuffer PORT MAP
    (
      rdclock => clk_50M,
      rdaddress => buffer_addr,
      q => buffer_data,
      wrclock => OV7670_PCLK,
      wraddress => capture_addr,
      data => capture_data,
      wren => capture_we
    );

  -- -- Test pattern generator
  -- test_pattern_gen : test_pattern_generator PORT MAP
  -- (
  --   data => test_pattern_select, -- Unused in this module
  --   wraddress => (OTHERS => '0'), -- Unused in this module
  --   wrclock => clk_50M,
  --   wren => '1', -- Unused in this module
  --   rdaddress => buffer_addr,
  --   rdclock => clk_25M,
  --   q => buffer_data
  -- );

  -- Histogram generator
  -- histgen : histogram_generator PORT MAP
  -- (
  --   pclk => OV7670_PCLK,
  --   vsync => OV7670_VSYNC,
  --   pixel_data => capture_data,
  --   pixel_valid => capture_we,
  --   vga_clk => clk_25M,
  --   vga_x => vga_x,
  --   vga_y => vga_y,
  --   hist_pixel => hist_pixel
  -- );

  ----------------------------------------------------------------
  --- Processes
  ----------------------------------------------------------------
  PROCESS (clk_50M)
  BEGIN
    IF rising_edge(clk_50M) THEN
      IF cnt >= CNT_MAX THEN
        cnt <= (OTHERS => '0');
        blink <= NOT blink;
      ELSE
        cnt <= cnt + 1;
      END IF;
      mSeg7 <= test_pattern_select;
    END IF;
  END PROCESS;

  ----------------------------------------------------------------
  --- LEDS
  ----------------------------------------------------------------
  -- LEDG <= KEY(3) & '0' & Key(2) & '0' & key(1) & config_finished & KEY(0) & blink;
  -- LEDR <= SW(9) & SW(8) & SW(7) & SW(6) & SW(5) & SW(4) & SW(3) & SW(2) & SW(1) & SW(0);
  LED(0) <= blink;
  LED(15 downto 6) <= SW(9 downto 0);
  LED(5 downto 1) <= KEY(3 downto 0) & config_finished;
  LEDB1 <= rgb;


  -- KEY <= btndpush & btnrpush & btnlpush & btnupush;
END rtl;