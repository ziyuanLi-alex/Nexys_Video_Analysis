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
    KEY : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    LEDR : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
    
    -- DDR2 Interface for ddr_framebuffer - 已启用
    -- ddr2_addr : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
    -- ddr2_ba : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    -- ddr2_ras_n : OUT STD_LOGIC;
    -- ddr2_cas_n : OUT STD_LOGIC;
    -- ddr2_we_n : OUT STD_LOGIC;
    -- ddr2_ck_p : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    -- ddr2_ck_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    -- ddr2_cke : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    -- ddr2_cs_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    -- ddr2_dm : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    -- ddr2_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    -- ddr2_dq : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    -- ddr2_dqs_p : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    -- ddr2_dqs_n : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0)
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
    PORT (
      iVGA_CLK : IN STD_LOGIC;
      r : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      g : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      b : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      hs : OUT STD_LOGIC;
      vs : OUT STD_LOGIC;
      surv : IN STD_LOGIC;
      rgb : IN STD_LOGIC;
      debug : IN NATURAL;
      debug2 : IN NATURAL;
      newframe : OUT STD_LOGIC;
      leftmotion : OUT NATURAL;
      rightmotion : OUT NATURAL;
      buffer_addr : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
      buffer_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
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

  -- COMPONENT ddr_framebuffer
  --   PORT (
  --     data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
  --     wraddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
  --     wrclock : IN STD_LOGIC;
  --     wren : IN STD_LOGIC;
  --     rdaddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
  --     rdclock : IN STD_LOGIC;
  --     q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      
  --     -- DDR系统接口
  --     clk_200MHz_i : IN STD_LOGIC;
  --     rst_i : IN STD_LOGIC;
  --     device_temp_i : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      
  --     -- DDR2物理接口
  --     ddr2_addr : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
  --     ddr2_ba : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
  --     ddr2_ras_n : OUT STD_LOGIC;
  --     ddr2_cas_n : OUT STD_LOGIC;
  --     ddr2_we_n : OUT STD_LOGIC;
  --     ddr2_ck_p : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
  --     ddr2_ck_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
  --     ddr2_cke : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
  --     ddr2_cs_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
  --     ddr2_dm : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
  --     ddr2_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
  --     ddr2_dq : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
  --     ddr2_dqs_p : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
  --     ddr2_dqs_n : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0)
  --   );
  -- END COMPONENT;

  ----------------------------------------------------------------
  --- Variables
  ----------------------------------------------------------------
  SIGNAL xclk : STD_LOGIC := '0'; -- This will now be driven by clk_wiz_0
  -- signal CLOCK_50: std_logic; -- Removed: Replaced by clk_50M from clk_wiz_0

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
  SIGNAL key0push : STD_LOGIC;
  SIGNAL key1push : STD_LOGIC;
  SIGNAL key2push : STD_LOGIC;
  SIGNAL key3push : STD_LOGIC;

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
  WITH KEY(0) SELECT key0push <= '1' WHEN '0', '0' WHEN OTHERS;
  WITH KEY(1) SELECT key1push <= '1' WHEN '0', '0' WHEN OTHERS;
  -- key 3 used in registers.
  WITH KEY(2) SELECT key2push <= '1' WHEN '0', '0' WHEN OTHERS;
  WITH KEY(3) SELECT key3push <= '1' WHEN '0', '0' WHEN OTHERS;
  --SW1 to 6 used by ovregisters
  WITH SW(0) SELECT rgb <= '1' WHEN '1', '0' WHEN OTHERS;
  WITH SW(5) SELECT sw5 <= '1' WHEN '1', '0' WHEN OTHERS;
  WITH SW(6) SELECT sw6 <= '1' WHEN '1', '0' WHEN OTHERS;
  WITH SW(7) SELECT surveillance <= '1' WHEN '1', '0' WHEN OTHERS;
  WITH SW(8) SELECT surveillance2 <= '1' WHEN '1', '0' WHEN OTHERS;

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
  vgadr : vga_driver PORT MAP
  (
    iVGA_CLK => clk_25M,
    r => VGA_R,
    g => VGA_G,
    b => VGA_B,
    hs => VGA_HS,
    vs => VGA_VS,
    surv => surveillance,
    rgb => rgb,
    debug => debug,
    debug2 => debug2,
    newframe => newframe,
    leftmotion => leftmotion,
    rightmotion => rightmotion,
    buffer_addr => buffer_addr,
    buffer_data => buffer_data
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

  -- 不再使用原始framebuffer，改用ddr_framebuffer
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

  -- 使用DDR framebuffer
  -- fb_ddr : ddr_framebuffer PORT MAP
  -- (
  --   -- 原始framebuffer接口
  --   data => capture_data,
  --   wraddress => capture_addr,
  --   wrclock => OV7670_PCLK,
  --   wren => capture_we,
  --   rdaddress => buffer_addr,
  --   rdclock => clk_25M,
  --   q => buffer_data,
    
  --   -- DDR系统接口
  --   clk_200MHz_i => clk_200M,
  --   rst_i => rst_ddr,
  --   device_temp_i => device_temp,
    
  --   -- DDR2物理接口
  --   ddr2_addr => ddr2_addr,
  --   ddr2_ba => ddr2_ba,
  --   ddr2_ras_n => ddr2_ras_n,
  --   ddr2_cas_n => ddr2_cas_n,
  --   ddr2_we_n => ddr2_we_n,
  --   ddr2_ck_p => ddr2_ck_p,
  --   ddr2_ck_n => ddr2_ck_n,
  --   ddr2_cke => ddr2_cke,
  --   ddr2_cs_n => ddr2_cs_n,
  --   ddr2_dm => ddr2_dm,
  --   ddr2_odt => ddr2_odt,
  --   ddr2_dq => ddr2_dq,
  --   ddr2_dqs_p => ddr2_dqs_p,
  --   ddr2_dqs_n => ddr2_dqs_n
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

      -- 将最大运动值显示在七段数码管上
      mSEG7 <= std_logic_vector(to_unsigned(max, mSEG7'length));
      
      -- 监控模式检测
      survmode <= surveillance OR surveillance2;
    END IF;
  END PROCESS;

  ----------------------------------------------------------------
  --- LEDS
  ----------------------------------------------------------------
  LEDG <= key3push & '0' & key2push & '0' & key1push & config_finished & key0push & blink;
  LEDR <= SW(9) & SW(8) & SW(7) & SW(6) & SW(5) & SW(4) & SW(3) & SW(2) & SW(1) & SW(0);

END rtl;