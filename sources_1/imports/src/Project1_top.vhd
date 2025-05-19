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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Project1_top is
  PORT (
	 CLOCK_100 : in STD_LOGIC;
	 OV7670_SIOC  : OUT   STD_LOGIC;
	 OV7670_SIOD  : inout STD_LOGIC;
	 OV7670_VSYNC : in    STD_LOGIC;
	 OV7670_HREF  : in    STD_LOGIC;
	 OV7670_PCLK  : in    STD_LOGIC;
	 OV7670_XCLK  : OUT   STD_LOGIC;
	 OV7670_D     : in    std_logic_vector(7 downto 0);
	 OV7670_RESET : OUT   STD_LOGIC;
	 OV7670_PWDN  : OUT   STD_LOGIC;

	 VGA_R      : OUT   std_logic_vector(3 downto 0);
	 VGA_G    : OUT   std_logic_vector(3 downto 0);
	 VGA_B     : OUT   std_logic_vector(3 downto 0);
	 VGA_HS    : OUT   STD_LOGIC;
	 VGA_VS    : OUT   STD_LOGIC;

     number : in  std_logic_vector (15 downto 0); -- 8个数字的输入数据(每个数字4位，共8*4=32位)
     seg : out  std_logic_vector (6 downto 0);    -- 数据端(最高位为小数点)
     an : out  std_logic_vector (7 downto 0);   
	 SW : in std_logic_vector( 9 downto 0 );
	 KEY : in std_logic_vector( 3 downto 0);
	 LEDG          : OUT   std_logic_vector(7 downto 0);
	 LEDR : OUT std_logic_vector( 9 downto 0 )
       );
end Project1_top;

architecture rtl of Project1_top is

  ----------------------------------------------------------------
  --- COMPONENTS
  ---------------------------------------------------------------- 

  COMPONENT display
    Port(clk : in  std_logic;                         -- 100MHz系统时钟
         number : in  std_logic_vector (15 downto 0); -- 8个数字的输入数据(每个数字4位，共8*4=32位)
         seg : out  std_logic_vector (6 downto 0);    -- 数据端(最高位为小数点)
         an : out  std_logic_vector (7 downto 0));    -- 阳极选择端
  END COMPONENT;


  COMPONENT OV7670_driver
    PORT
    (
      iclk50   : in    STD_LOGIC;
      config_finished : OUT STD_LOGIC;
      sioc  : OUT   STD_LOGIC;
      siod  : inout STD_LOGIC;
      sw : in std_logic_vector( 9 downto 0 );
      key : in std_logic_vector( 3 downto 0 )
    --readcheck : OUT std_logic_vector (7 downto 0)
    );
  END COMPONENT;

  -- OVCapture gets the data from OV7670 camera

  COMPONENT OV7670_capture
    PORT
    (
      pclk : IN STD_LOGIC; -- camera clock
      vsync : IN STD_LOGIC;
      href  : IN STD_LOGIC;
      dport  : IN std_logic_vector(7 downto 0); -- data        
      surv : in STD_LOGIC;
      sw5 : in STD_LOGIC;
      sw6 : in STD_LOGIC;
      addr  : OUT std_logic_vector(12 downto 0); --test 18, 14 previous
      dout  : OUT std_logic_vector(15 downto 0);
      we    : OUT STD_LOGIC; -- write enable
      maxx    : OUT natural -- write enable
    );
  END COMPONENT;

  -- VGA determines the active area as well as gets the data from frame buffer
  --  Does the final setting of  r g b  output to the screen
  COMPONENT vga_driver 
    Port 
    ( 
      iVGA_CLK       : in  STD_LOGIC;
      r     : OUT std_logic_vector(3 downto 0);
      g   : OUT std_logic_vector(3 downto 0);
      b    : OUT std_logic_vector(3 downto 0);
      hs   : OUT STD_LOGIC;
      vs   : OUT STD_LOGIC;
      surv : in STD_LOGIC;
      rgb : in STD_LOGIC;
      debug : in natural;
      debug2 : in natural;
      newframe : OUT STD_LOGIC;
      leftmotion : OUT natural;
      rightmotion : OUT natural;
      buffer_addr : OUT std_logic_vector(12 downto 0);
      buffer_data : in  std_logic_vector(15 downto 0)
    );
  end COMPONENT;


  --The frame buffer is reference by OVdriver
  -- and data input is by OVCapture
  COMPONENT framebuffer 
    PORT
    (
      rdclock		: IN STD_LOGIC ;
      rdaddress	: IN std_logic_vector (12 downto 0);
      q		: OUT std_logic_vector (15 DOWNTO 0);--data OUT

      wrclock		: IN STD_LOGIC;
      wraddress	: IN std_logic_vector (12 downto 0);
      data		: IN std_logic_vector (15 DOWNTO 0);
      wren		: IN STD_LOGIC
    );
  END COMPONENT;

  ----------------------------------------------------------------
  --- Variables
  ----------------------------------------------------------------
  signal xclk  : STD_LOGIC := '0';   
  signal CLOCK_50: std_logic;

  constant CLOCK_50_FREQ : integer := 50000000;
  constant BLINK_FREQ : integer := 1;
  constant CNT_MAX : integer := CLOCK_50_FREQ/BLINK_FREQ/2-1;
  constant BUZZ_MAX : integer := CLOCK_50_FREQ*3/BLINK_FREQ/2-1;

  --Local wires
  signal cnt : unsigned(24 downto 0);
  signal blink : STD_LOGIC;

  signal buffer_addr  : std_logic_vector(12 downto 0) := (others => '0');
  signal buffer_data  : std_logic_vector(15 downto 0) := (others => '0');
  signal capture_addr  : std_logic_vector(12 downto 0);
  signal capture_data  : std_logic_vector(15 downto 0);
  signal capture_we    : STD_LOGIC; -- write enable.
  signal config_finished : STD_LOGIC;
  --modes
  signal surveillance : STD_LOGIC;
  signal surveillance2 : STD_LOGIC;
  signal sw5 : STD_LOGIC;
  signal sw6 : STD_LOGIC;
  signal survmode : STD_LOGIC;
  signal rgb : STD_LOGIC;

  --buttons
  signal key0push : STD_LOGIC;
  signal key1push : STD_LOGIC;
  signal key2push : STD_LOGIC;
  signal key3push : STD_LOGIC;

  --debugging
  signal mSEG7 : std_logic_vector ( 15 downto 0) := (others => '0');
  signal debug : natural := 0;
  signal debug2 : natural := 0;
  signal max : natural := 0;
  signal leftmotion : natural := 0;
  signal rightmotion : natural := 0;
  signal newframe : STD_LOGIC;
  signal summax : natural := 0;
  --signal motionaddr : std_logic_vector(3 downto 0) := (others => '0');
  --signal sums : unsigned(15 downto 0) := (others => '0');

  --audio
  constant BUZZER_THRESHOLD : natural := 7500; -- magic number from heuristicsis max should be 320*480 however..
  signal left : STD_LOGIC;
  signal AUD_CTRL_CLK : STD_LOGIC;
  signal buzzer : STD_LOGIC := '0';
  signal buzzercnt : unsigned(31 downto 0);


begin

  ----------------------------------------------------------------
  --- PORTS
  ----------------------------------------------------------------
  with KEY(0) select key0push <= '1' when '0', '0' when others;
  with KEY(1) select key1push <= '1' when '0', '0' when others;
  -- key 3 used in registers.
  with KEY(2) select key2push <= '1' when '0', '0' when others;
  with KEY(3) select key3push <= '1' when '0', '0' when others;
  --SW1 to 6 used by ovregisters
  with SW(0) select rgb <= '1' when '1', '0' when others;
  with SW(5) select sw5 <= '1' when '1', '0' when others;
  with SW(6) select sw6 <= '1' when '1', '0' when others;
  with SW(7) select surveillance <= '1' when '1', '0' when others;
  with SW(8) select surveillance2 <= '1' when '1', '0' when others;

  OV7670_RESET <= '1';                   -- Normal mode
  OV7670_PWDN  <= '0';                   -- Power device up
  OV7670_XCLK <=  xclk;
  
--  --AUD_ADCLRCK	<=	AUD_DACLRCK;
--  AUD_XCK     <=  AUD_CTRL_CLK;
    
  clock_div_inst: entity work.clk_div_50MHz
     port map(
         clk_in => CLOCK_100,
         clk_out => CLOCK_50
     );

  disp: display PORT MAP
  (	  
    clk =>CLOCK_100,
    number => mSEG7,
    seg => seg,
    an => an
  );

  ovdr : OV7670_driver PORT MAP
  (
    iclk50  => xclk,
    config_finished => config_finished,
    sioc  => ov7670_sioc,
    siod  => ov7670_siod,
    sw => SW,
    key => KEY
  --readcheck => readcheck
  );


  vgadr : vga_driver PORT MAP
  (
    iVGA_CLK       => xclk,
    r    => VGA_R,
    g   => VGA_G,
    b    => VGA_B,
    hs   => VGA_HS,
    vs   => VGA_VS,
    surv => surveillance,
    rgb => rgb,
    debug => debug,
    debug2 => debug2,
    newframe => newframe,
    leftmotion => leftmotion,
    rightmotion => rightmotion,
    buffer_addr  => buffer_addr,
    buffer_data => buffer_data
  );

  ovcap : OV7670_capture PORT MAP
  (
    pclk  => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href  => OV7670_HREF,
    dport  => OV7670_D,
    surv => survmode,
    sw5 => sw5,
    sw6 => sw6,
    addr  => capture_addr,
    dout  => capture_data,
    maxx => max,
    we    => capture_we
  );

  fb : framebuffer PORT MAP 
  (
    rdclock  => CLOCK_50,
    rdaddress => buffer_addr,
    q => buffer_data,

    wrclock => OV7670_PCLK,
    wraddress => capture_addr,
    data  => capture_data,
    wren   => capture_we
  );

  ----------------------------------------------------------------
  --- Processes
  ----------------------------------------------------------------
  process(CLOCK_50)

  begin
    if rising_edge(CLOCK_50) then
      if cnt >= CNT_MAX then
	cnt <= (others => '0');
	blink <= not blink;
	mSEG7 <= std_logic_vector(to_unsigned(summax,mSEG7'length));
      --mSEG7 <= std_logic_vector(to_unsigned(max,mSEG7'length));
      --mSEG7 <= std_logic_vector(sums);
      else
	cnt <= cnt + 1;
      end if;

      if leftmotion + rightmotion > summax then
	summax <= leftmotion + rightmotion;
      elsif key3push = '1' then
	summax <= 0;

      end if;


      if (to_unsigned(leftmotion + rightmotion, 16) > (BUZZER_THRESHOLD)) then
	if leftmotion > rightmotion  then
	  left <= '1';
	else
	  left <= '0';
	end if;
	buzzer <= '1';
	buzzercnt <= (others => '0');
      end if;

      if buzzer = '1' then
	if buzzercnt >= BUZZ_MAX then
	  buzzer <= '0';
	  buzzercnt <= (others => '0');
	else
	  buzzercnt <= buzzercnt + 1;
	end if;
      end if;
      xclk <= not xclk; --System clock for OV and VGA 25mhz
    end if;
  end process;
  

  process(surveillance,surveillance2)
  begin
    survmode <= surveillance or surveillance2;
  end process;

  ----------------------------------------------------------------
  --- LEDS
  ----------------------------------------------------------------
  LEDG <= key3push & '0' & key2push & '0' & key1push & config_finished & key0push & blink;
  LEDR <= SW(9) & SW(8) & SW(7) & SW(6) & SW(5) & SW(4) & SW(3) & SW(2) & SW(1) & SW(0);

end rtl;
