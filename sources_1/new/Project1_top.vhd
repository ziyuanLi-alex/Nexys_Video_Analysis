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
<<<<<<< HEAD
      pclk : IN STD_LOGIC; -- camera clock
=======
      -- 摄像头接口
      pclk : IN STD_LOGIC; -- 相机像素时钟
      vsync : IN STD_LOGIC; -- 垂直同步信号
      href : IN STD_LOGIC; -- 水平参考信号
      dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0); -- 相机8位数据输入

      -- framebuffer接口（与ideal_capture完全匹配）
      addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0); -- 17位地址，支持76,800像素
      dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); -- RGB565数据输出
      we : OUT STD_LOGIC; -- 写使能信号

      reset : IN STD_LOGIC -- 复位信号（与ideal_capture兼容）
    );
  END COMPONENT;

  COMPONENT framebuffer
    PORT (
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT test_pattern_generator IS
    PORT (
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT input_selector IS
    PORT (
      -- 控制信号
      clk : IN STD_LOGIC; -- 时钟信号
      select_input : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- 输入选择信号 (00=摄像头, 01=测试图案, 10=直方图, 11=光流)

      -- 摄像头/帧缓冲区接口
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 帧缓冲区读地址输出
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 帧缓冲区数据输入

      -- 测试图案接口
      tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 测试图案读地址输出
      tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案数据输入
      tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 测试图案选择
      tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- 测试图案模式选择

      -- VGA输出接口 (连接到VGA驱动器)
      vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA请求地址输入
      vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- VGA数据输出

      -- 简化的直方图相关端口
      hist_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 直方图读取地址
      hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式输出像素

      -- 保留的光流图像端口
      flow_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 光流地址输出
      flow_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0) -- 光流数据输入
    );
  END COMPONENT;

  COMPONENT ideal_capture IS
    PORT (
      -- 时钟接口（与真实模块兼容）
      pclk : IN STD_LOGIC; -- 像素时钟(约12.5MHz)
      vsync : IN STD_LOGIC; -- 垂直同步信号（可选，用于外部同步）
      href : IN STD_LOGIC; -- 水平参考信号（可选，用于外部同步）
      dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0); -- 数据输入（未使用）

      -- framebuffer接口
      addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0); -- 17位地址，支持76,800像素
      dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); -- RGB565数据输出
      we : OUT STD_LOGIC; -- 写使能信号

      -- 控制接口
      reset : IN STD_LOGIC -- 复位信号
    );
  END COMPONENT;

  COMPONENT pclk_frequency_meter IS
    PORT (
      -- 时钟和控制
      clk_100m : IN STD_LOGIC; -- 100MHz参考时钟
      reset : IN STD_LOGIC; -- 复位信号

      -- 被测信号
      pclk : IN STD_LOGIC; -- 待测PCLK信号

      -- 输出
      frequency_mhz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 频率值（Hz）
      freq_valid : OUT STD_LOGIC -- 频率值有效（每秒更新一次）
    );
  END COMPONENT;

  ---------------------------
  -- Image Analysis Components
  ---------------------------
  -- 直方图生成器
  COMPONENT histogram_generator IS
    PORT (
      clk : IN STD_LOGIC; -- 时钟信号
      reset : IN STD_LOGIC; -- 复位信号

      -- 视频输入接口
      pixel_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 输入像素数据 (RGB565格式)
      pixel_valid : IN STD_LOGIC; -- 像素有效信号
      frame_start : IN STD_LOGIC; -- 帧开始信号

      -- 直方图存储接口
      hist_bin_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图读取地址 (0-255)
      hist_bin_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据输出

      -- 控制接口
      mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0) -- 00: Y亮度直方图, 01: R直方图, 10: G直方图, 11: B直方图
    );
  END COMPONENT;

  -- -- 直方图显示
  COMPONENT histogram_display IS
    PORT (
      clk : IN STD_LOGIC; -- 时钟信号
      reset : IN STD_LOGIC; -- 复位信号

      -- 视频输出接口 (连接到input_selector)
      hist_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 17位视频地址输入 (来自VGA控制器)
      hist_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式视频数据输出 (到VGA)

      -- 直方图数据源接口 (连接到histogram_generator)
      hist_bin_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图bin读取地址 (0-255)
      hist_bin_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图bin数据输入 (来自histogram_generator)

      -- 直方图类型控制
      hist_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0) -- 00: Y, 01: R, 10: G, 11: B
    );
  END COMPONENT;

  -- COMPONENT camera_debug IS
  --   PORT (
  --     clk : IN STD_LOGIC; -- 系统时钟
  --     reset : IN STD_LOGIC; -- 复位信号

  --     -- 摄像头信号
  --     pclk : IN STD_LOGIC; -- 摄像头PCLK
  --     vsync : IN STD_LOGIC; -- 垂直同步
  --     href : IN STD_LOGIC; -- 水平参考
  --     dport : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 数据端口

  --     -- LED调试输出（连接到板上LED）
  --     led_pclk_active : OUT STD_LOGIC; -- PCLK活跃指示
  --     led_vsync_active : OUT STD_LOGIC; -- VSYNC活跃指示  
  --     led_href_active : OUT STD_LOGIC; -- HREF活跃指示
  --     led_data_changing : OUT STD_LOGIC; -- 数据变化指示

  --     -- 数码管显示（可选）
  --     debug_counter : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 调试计数器

  --     -- 状态输出
  --     camera_working : OUT STD_LOGIC -- 摄像头工作状态
  --   );
  -- END COMPONENT;

  COMPONENT precise_camera_debug IS
    PORT (
      clk_100m : IN STD_LOGIC; -- 100MHz系统时钟
      reset : IN STD_LOGIC;

      -- 摄像头信号
      pclk : IN STD_LOGIC;
>>>>>>> 995f407 (VALIDATED: 直方图正常显示)
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

<<<<<<< HEAD
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
=======
  ---------------------------
  -- Input Control Signals
  ---------------------------
  -- Button signals combined
  SIGNAL KEY : STD_LOGIC_VECTOR(3 DOWNTO 0); -- Combined button inputs  

  ---------------------------
  -- Debug and Display Signals
  ---------------------------
  -- Debug signals
  SIGNAL mSEG7 : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0'); -- 7-segment display value
  SIGNAL max : NATURAL := 0; -- Maximum motion value  

  -- Display mode control
  SIGNAL display_mode : STD_LOGIC := '0'; -- Display mode selector  

  ---------------------------
  -- Graphics and Pattern Signals
  ---------------------------
  -- Test pattern signals
  SIGNAL test_pattern_select : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0'); -- Test pattern selection  

  ---------------------------
  -- Video Pipeline Signals
  ---------------------------
  -- Video Pipeline Signals
  SIGNAL vga_request_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
  SIGNAL output_yield_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL fb_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
  SIGNAL fb_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL tp_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
  SIGNAL tp_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL tp_select : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL hist_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
  SIGNAL hist_data : STD_LOGIC_VECTOR(15 DOWNTO 0);

  -- 直方图相关信号
  SIGNAL hist_bin_addr : STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图bin读取地址 (0-255)
  SIGNAL hist_bin_data : STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图bin数据输入 (来自histogram_generator)

  -- Framebuffer验证信号
  -- SIGNAL debug_capture_active : STD_LOGIC := '0';
  -- SIGNAL debug_frame_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_pixel_count : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_last_addr : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_last_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_total_pixels : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_href_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_pclk_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_vsync_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_data_nonzero_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_vsync_low_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  -- SIGNAL debug_valid_condition : STD_LOGIC := '0';
  -- 状态监控信号
  SIGNAL vsync_edge_detect : STD_LOGIC := '0';
  SIGNAL vsync_prev : STD_LOGIC := '0';
  SIGNAL href_active_count : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

  -- 数据验证信号
  SIGNAL data_changed : STD_LOGIC := '0';
  SIGNAL prev_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

  SIGNAL pclk_frequency : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL freq_updated : STD_LOGIC;

  SIGNAL cam_debug_counter : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

  SIGNAL pclk_freq_khz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL vsync_freq_hz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL href_freq_khz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

  SIGNAL led_pclk_normal : STD_LOGIC := '0';
  SIGNAL led_vsync_normal : STD_LOGIC := '0';
  SIGNAL led_href_normal : STD_LOGIC := '0';
  SIGNAL led_timing_error : STD_LOGIC := '0';

  -- SIGNAL signals_static : STD_LOGIC := '0';
  -- SIGNAL signals_identical : STD_LOGIC := '0';
>>>>>>> 995f407 (VALIDATED: 直方图正常显示)

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
<<<<<<< HEAD
  
  -- VGA驱动
  vga : vga_driver PORT MAP (
=======

  -- vga驱动
  vga : vga_driver PORT MAP(
>>>>>>> 995f407 (VALIDATED: 直方图正常显示)
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

<<<<<<< HEAD
  -- 摄像头数据捕获
=======
  -- 摄像头
>>>>>>> 995f407 (VALIDATED: 直方图正常显示)
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

<<<<<<< HEAD
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
=======
  frmb : framebuffer PORT MAP
  (
    rdclock => clk_50M,
    rdaddress => fb_addr,
    q => fb_data,
    wrclock => OV7670_PCLK,
    wraddress => capture_addr,
    data => capture_data,
    wren => capture_we
  );

  input_sel : input_selector PORT MAP
  (
    clk => clk_50M,
    select_input => SW(4 DOWNTO 3),
    fb_addr => fb_addr,
    fb_data => fb_data,
    tp_addr => tp_addr,
    tp_data => tp_data,
    tp_select => tp_select,
    tp_pattern => SW(2 DOWNTO 0),
    hist_addr => hist_addr, -- Unused in this module
    hist_data => hist_data, -- Unused in this module
    flow_addr => OPEN, -- Unused in this module
    flow_data => (OTHERS => '0'), -- Unused in this module
    vga_addr => vga_request_addr,
    vga_data => output_yield_data
  );

  -- Test pattern generator
  test_pattern_gen : test_pattern_generator PORT MAP
  (
    data => tp_select,
    wraddress => (OTHERS => '0'),
    wrclock => clk_50M,
    wren => '1',
    rdaddress => tp_addr,
    rdclock => clk_25M,
    q => tp_data
  );

  --   -- 直方图生成器实例化
  hist_gen : histogram_generator PORT MAP
  (
    clk => clk_50M,
    reset => KEY(2),

    -- 视频输入接口
    pixel_data => capture_data,
    pixel_valid => capture_we,
    frame_start => OV7670_vsync,
    -- 直方图存储接口
    hist_bin_addr => hist_bin_addr,
    hist_bin_data => hist_bin_data,

    -- 控制接口
    mode => SW(1 DOWNTO 0) -- 00: Y, 01: R, 10: G, 11: B
  );

  hist_disp : histogram_display PORT MAP
  (
    clk => clk_50M,
    reset => KEY(2),

    -- 视频输出接口
    hist_addr => hist_addr,
    hist_data => hist_data,

    -- 直方图数据源接口
    hist_bin_addr => hist_bin_addr,
    hist_bin_data => hist_bin_data,

    -- 直方图类型控制
    hist_type => SW(1 DOWNTO 0) -- 00: Y, 01: R, 10: G, 11: B
  );

  -- 直方图显示组件实例化
  -- hist_display : histogram_display PORT MAP(
  --   clk => clk_50M,
  --   reset => '0',

  --   -- 地址接口
  --   addr => fb_addr,

  --   -- 直方图数据输入
  --   hist_bin_data => hist_data,
  --   hist_addr => hist_addr,
  --   hist_data => fb_data,

  --   -- 直方图类型控制
  --   hist_type => SW(1 DOWNTO 0) -- 00: Y, 01: R, 10: G, 11: B
  -- );

  freq_meter : pclk_frequency_meter
  PORT MAP(
    clk_100m => clk_100M,
    reset => KEY(2),
    pclk => OV7670_PCLK,
    frequency_mhz => pclk_frequency,
    freq_valid => freq_updated
  );

  -- cam_debug : camera_debug PORT MAP
  -- (
  --   clk => clk_100M,
  --   reset => KEY(2),
>>>>>>> 995f407 (VALIDATED: 直方图正常显示)
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