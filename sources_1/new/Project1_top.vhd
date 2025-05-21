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
    LED : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
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
  COMPONENT vga_driver
    GENERIC (
      -- VGA时序参数 (默认640x480 @ 60Hz)
      H_VISIBLE_AREA : INTEGER := 640;
      H_FRONT_PORCH : INTEGER := 16;
      H_SYNC_PULSE : INTEGER := 96;
      H_BACK_PORCH : INTEGER := 48;
      H_WHOLE_LINE : INTEGER := 800;
      V_VISIBLE_AREA : INTEGER := 480;
      V_FRONT_PORCH : INTEGER := 10;
      V_SYNC_PULSE : INTEGER := 2;
      V_BACK_PORCH : INTEGER := 33;
      V_WHOLE_FRAME : INTEGER := 525;

      -- 帧缓冲区尺寸 - 已更新为320x240
      FB_WIDTH : INTEGER := 320;
      FB_HEIGHT : INTEGER := 240;

      -- 颜色格式 (默认RGB565)
      RED_BITS : INTEGER := 5;
      GREEN_BITS : INTEGER := 6;
      BLUE_BITS : INTEGER := 5;

      -- 输出颜色深度 (VGA输出每种颜色的位数)
      OUTPUT_BITS : INTEGER := 4
    );
    PORT (
      -- Clock and reset
      clk : IN STD_LOGIC; -- Pixel clock
      rst : IN STD_LOGIC; -- Reset signal

      -- Frame buffer interface
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- For 80x60 = 4800 pixels
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565 pixel data

      -- VGA outputs
      hsync : OUT STD_LOGIC;
      vsync : OUT STD_LOGIC;
      red : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
      green : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
      blue : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);

      -- Display resolution selection (optional for future use)
      resolution_sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0) := "00" -- 00: 640x480, 01: 320x240, 10: 800x600
    );
  END COMPONENT;
  -- The frame buffer is reference by OVdriver
  -- and data input is by OVCapture
  COMPONENT framebuffer
    PORT (
      -- 写入接口（80x60分辨率 = 4800像素）
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0); -- 13位足够寻址4800像素
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;

      -- 读取接口（支持320x240分辨率 = 76800像素）
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位支持76800像素
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT test_pattern_generator IS
    PORT (
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- Input data (unused in this module)
      wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- Write address (unused in this module)
      wrclock : IN STD_LOGIC; -- Write clock
      wren : IN STD_LOGIC; -- Write enable (used to select test pattern)
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- Read address from VGA controller
      rdclock : IN STD_LOGIC; -- Read clock (VGA clock)
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- Output pixel data for test pattern
    );
  END COMPONENT;

  COMPONENT input_selector IS
    PORT (
      -- 控制信号
      clk : IN STD_LOGIC; -- 时钟信号
      select_input : IN STD_LOGIC; -- 输入选择信号 (0=摄像头, 1=测试图案)

      -- 摄像头/帧缓冲区接口
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 帧缓冲区读地址输出
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 帧缓冲区数据输入

      -- 测试图案接口
      tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 测试图案读地址输出
      tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案数据输入
      tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案选择
      tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- 测试图案模式选择

      -- 输出接口 (连接到VGA驱动器)
      vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA请求地址输入
      vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- VGA数据输出
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

  -- SIGNAL buffer_addr : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL buffer_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL capture_addr : STD_LOGIC_VECTOR(12 DOWNTO 0);
  SIGNAL capture_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL capture_we : STD_LOGIC; -- write enable.
  SIGNAL config_finished : STD_LOGIC;
  --modes
  -- SIGNAL surveillance : STD_LOGIC;
  -- SIGNAL surveillance2 : STD_LOGIC;
  SIGNAL sw5 : STD_LOGIC;
  SIGNAL sw6 : STD_LOGIC;
  SIGNAL survmode : STD_LOGIC;
  SIGNAL rgb : STD_LOGIC;

  --buttons
  SIGNAL KEY : STD_LOGIC_VECTOR(3 DOWNTO 0);

  --debugging
  SIGNAL mSEG7 : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug : NATURAL := 0;
  -- SIGNAL debug2 : NATURAL := 0;
  SIGNAL max : NATURAL := 0;
  -- SIGNAL leftmotion : NATURAL := 0;
  -- SIGNAL rightmotion : NATURAL := 0;
  -- SIGNAL newframe : STD_LOGIC;
  -- SIGNAL summax : NATURAL := 0;
  --signal motionaddr : std_logic_vector(3 downto 0) := (others => '0');
  --signal sums : unsigned(15 downto 0) := (others => '0');

  --audio
  -- CONSTANT BUZZER_THRESHOLD : NATURAL := 7500; -- magic number from heuristicsis max should be 320*480 however..
  -- SIGNAL left : STD_LOGIC;
  -- SIGNAL AUD_CTRL_CLK : STD_LOGIC;
  -- SIGNAL buzzer : STD_LOGIC := '0';
  -- SIGNAL buzzercnt : unsigned(31 DOWNTO 0);

  SIGNAL display_mode : STD_LOGIC := '0';
  -- SIGNAL hist_pixel : STD_LOGIC_VECTOR(11 DOWNTO 0);
  -- SIGNAL vga_x : STD_LOGIC_VECTOR(9 DOWNTO 0);
  -- SIGNAL vga_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

  SIGNAL test_pattern_select : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

  SIGNAL vga_request_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA驱动器输出的地址请求
  SIGNAL output_yield_data : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 选择后的像素数据输出到VGA
  SIGNAL fb_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 帧缓冲区地址
  SIGNAL fb_data : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 帧缓冲区数据
  SIGNAL tp_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 测试图案地址
  SIGNAL tp_data : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案数据
  SIGNAL tp_select : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案选择

BEGIN

  ----------------------------------------------------------------
  --- PORTS
  ----------------------------------------------------------------
  -- Button input handling (active-low buttons are converted to active-high signals)
  KEY <= btnd & btnr & btnl & btnu; -- Combine button signals into KEY vector

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

  test_pattern_select(2 DOWNTO 0) <= SW(2 DOWNTO 0); -- Test pattern select

  OV7670_RESET <= '1'; -- Normal mode
  OV7670_PWDN <= '0'; -- Power device up
  OV7670_XCLK <= clk_25M; -- 使用从clk_wiz_0生成的25MHz时钟

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
  -- vga : vga_driver PORT MAP(
  --   clk => clk_25M,
  --   rst => '0',
  --   fb_addr => buffer_addr,
  --   fb_data => buffer_data,
  --   hsync => VGA_HS,
  --   vsync => VGA_VS,
  --   red => VGA_R,
  --   green => VGA_G,
  --   blue => VGA_B,
  --   resolution_sel => "00"
  -- );

  vga : vga_driver PORT MAP(
    clk => clk_25M,
    rst => '0',
    fb_addr => vga_request_addr, -- 向input_selector请求数据的地址
    fb_data => output_yield_data, -- 从input_selector接收数据
    hsync => VGA_HS,
    vsync => VGA_VS,
    red => VGA_R,
    green => VGA_G,
    blue => VGA_B,
    resolution_sel => "00"
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

  -- fb : framebuffer PORT MAP
  -- (
  --   rdclock => clk_50M,
  --   rdaddress => buffer_addr,
  --   q => buffer_data,
  --   wrclock => OV7670_PCLK,
  --   wraddress => capture_addr,
  --   data => capture_data,
  --   wren => capture_we
  -- );
  fb : framebuffer PORT MAP
  (
    rdclock => clk_50M,
    rdaddress => fb_addr, -- 从input_selector接收地址
    q => fb_data, -- 输出到input_selector
    wrclock => OV7670_PCLK,
    wraddress => capture_addr,
    data => capture_data,
    wren => capture_we
  );

  -- -- -- Test pattern generator
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
  -- test_pattern_gen : test_pattern_generator PORT MAP
  -- (
  --   data => tp_select,
  --   wraddress => (OTHERS => '0'),
  --   wrclock => clk_50M,
  --   wren => '1',
  --   rdaddress => tp_addr,
  --   rdclock => clk_25M,
  --   q => tp_data
  -- );

  test_pattern_gen : test_pattern_generator PORT MAP
  (
    data => tp_select,
    wraddress => (OTHERS => '0'), -- 不使用
    wrclock => clk_50M,
    wren => '1', -- 始终启用
    rdaddress => tp_addr, -- 从input_selector接收地址
    rdclock => clk_25M,
    q => tp_data -- 输出到input_selector
  );

  input_sel : input_selector PORT MAP
  (
    clk => clk_25M,
    select_input => SW(9), -- 使用SW9选择输入源

    fb_addr => fb_addr, -- 输出：发送到帧缓冲区的地址
    fb_data => fb_data, -- 输入：从帧缓冲区接收的数据

    tp_addr => tp_addr, -- 输出：发送到测试图案生成器的地址
    tp_data => tp_data, -- 输入：从测试图案生成器接收的数据
    tp_select => tp_select, -- 输出：发送到测试图案生成器的选择信号
    tp_pattern => SW(2 DOWNTO 0), -- 输入：从开关接收的图案选择

    vga_addr => vga_request_addr, -- 输入：从VGA驱动器接收的地址请求
    vga_data => output_yield_data -- 输出：发送到VGA驱动器的数据
  );
  ----------------------------------------------------------------
  --- Processes
  ----------------------------------------------------------------
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
  LED(15 DOWNTO 6) <= SW(9 DOWNTO 0);
  LED(5 DOWNTO 1) <= KEY(3 DOWNTO 0) & config_finished;
  LEDB1 <= rgb;
  -- KEY <= btndpush & btnrpush & btnlpush & btnupush;
END rtl;