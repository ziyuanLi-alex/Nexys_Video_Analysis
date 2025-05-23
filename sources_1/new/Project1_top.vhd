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
-- CONETENT ABOVE DEPRECATED！

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_unsigned.ALL;

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

    -- number : IN STD_LOGIC_VECTOR (15 DOWNTO 0); -- 8位数字的输入数据(每个数字4位，共8*4=32位)
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

  COMPONENT clk_wiz_0
    PORT (
      clk_100M : OUT STD_LOGIC;
      clk_50M : OUT STD_LOGIC;
      clk_200M : OUT STD_LOGIC;
      clk_25M : OUT STD_LOGIC;
      locked : OUT STD_LOGIC;
      clk_in : IN STD_LOGIC
    );
  END COMPONENT;

  COMPONENT display
    PORT (
      clk : IN STD_LOGIC;
      number : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
      seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
      an : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT vga_driver
    GENERIC (
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
      FB_WIDTH : INTEGER := 320;
      FB_HEIGHT : INTEGER := 240;
      RED_BITS : INTEGER := 5;
      GREEN_BITS : INTEGER := 6;
      BLUE_BITS : INTEGER := 5;
      OUTPUT_BITS : INTEGER := 4
    );
    PORT (
      clk : IN STD_LOGIC;
      rst : IN STD_LOGIC;
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      hsync : OUT STD_LOGIC;
      vsync : OUT STD_LOGIC;
      red : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
      green : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
      blue : OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
      resolution_sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"
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
    );
  END COMPONENT;

  COMPONENT OV7670_capture
    PORT (
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
      clk : IN STD_LOGIC;
      select_input : IN STD_LOGIC;
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
      vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
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
  -- COMPONENT histogram_generator IS
  --   PORT (
  --     clk : IN STD_LOGIC; -- 时钟信号
  --     reset : IN STD_LOGIC; -- 复位信号

  --     -- 视频输入接口
  --     pixel_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 输入像素数据 (RGB565格式)
  --     pixel_valid : IN STD_LOGIC; -- 像素有效信号
  --     frame_start : IN STD_LOGIC; -- 帧开始信号

  --     -- 直方图存储接口
  --     hist_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 直方图读取地址 (0-255)
  --     hist_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据输出

  --     -- 控制接口
  --     mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0) -- 00: Y亮度直方图, 01: R直方图, 10: G直方图, 11: B直方图
  --   );
  -- END COMPONENT;

  -- -- 直方图显示
  -- COMPONENT histogram_display IS
  --   PORT (
  --     clk : IN STD_LOGIC; -- 时钟信号
  --     reset : IN STD_LOGIC; -- 复位信号

  --     -- VGA位置输入
  --     x_pos : IN STD_LOGIC_VECTOR(9 DOWNTO 0); -- X坐标 (0-639)
  --     y_pos : IN STD_LOGIC_VECTOR(9 DOWNTO 0); -- Y坐标 (0-479)
  --     active : IN STD_LOGIC; -- 显示区域有效信号

  --     -- 直方图数据输入
  --     hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- 直方图数据

  --     -- 直方图类型控制
  --     hist_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- 00: Y, 01: R, 10: G, 11: B

  --     -- 像素输出
  --     pixel_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- RGB565格式输出像素
  --     hist_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) -- 直方图读取地址
  --   );
  -- END COMPONENT;

  COMPONENT camera_debug IS
    PORT (
      clk : IN STD_LOGIC; -- 系统时钟
      reset : IN STD_LOGIC; -- 复位信号

      -- 摄像头信号
      pclk : IN STD_LOGIC; -- 摄像头PCLK
      vsync : IN STD_LOGIC; -- 垂直同步
      href : IN STD_LOGIC; -- 水平参考
      dport : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 数据端口

      -- LED调试输出（连接到板上LED）
      led_pclk_active : OUT STD_LOGIC; -- PCLK活跃指示
      led_vsync_active : OUT STD_LOGIC; -- VSYNC活跃指示  
      led_href_active : OUT STD_LOGIC; -- HREF活跃指示
      led_data_changing : OUT STD_LOGIC; -- 数据变化指示

      -- 数码管显示（可选）
      debug_counter : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- 调试计数器

      -- 状态输出
      camera_working : OUT STD_LOGIC -- 摄像头工作状态
    );
  END COMPONENT;

  COMPONENT precise_camera_debug IS
    PORT (
      clk_100m : IN STD_LOGIC; -- 100MHz系统时钟
      reset : IN STD_LOGIC;

      -- 摄像头信号
      pclk : IN STD_LOGIC;
      vsync : IN STD_LOGIC;
      href : IN STD_LOGIC;

      -- 频率输出（用于数码管显示）
      pclk_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- PCLK频率(kHz)
      vsync_freq_hz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- VSYNC频率(Hz)
      href_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- HREF频率(kHz)

      -- LED状态指示
      led_pclk_normal : OUT STD_LOGIC; -- PCLK频率正常(10-30MHz)
      led_vsync_normal : OUT STD_LOGIC; -- VSYNC频率正常(20-40Hz)
      led_href_normal : OUT STD_LOGIC; -- HREF频率正常(5-15kHz)
      led_timing_error : OUT STD_LOGIC; -- 时序异常指示

      -- 详细状态
      signals_static : OUT STD_LOGIC; -- 信号完全静止
      signals_identical : OUT STD_LOGIC -- PCLK和VSYNC完全相同
    );
  END COMPONENT;

  ----------------------------------------------------------------
  --- SIGNALS
  ----------------------------------------------------------------

  ---------------------------
  -- Clock Signals
  ---------------------------
  SIGNAL xclk : STD_LOGIC := '0';
  SIGNAL clk_100M : STD_LOGIC;
  SIGNAL clk_50M : STD_LOGIC;
  SIGNAL clk_200M : STD_LOGIC;
  SIGNAL clk_25M : STD_LOGIC;
  SIGNAL locked : STD_LOGIC;

  -- Timing signals (保持不变)
  CONSTANT CLOCK_50_FREQ : INTEGER := 50000000;
  CONSTANT BLINK_FREQ : INTEGER := 1;
  CONSTANT CNT_MAX : INTEGER := CLOCK_50_FREQ/BLINK_FREQ/2 - 1;
  CONSTANT BUZZ_MAX : INTEGER := CLOCK_50_FREQ * 3/BLINK_FREQ/2 - 1;
  SIGNAL cnt : unsigned(24 DOWNTO 0);
  SIGNAL blink : STD_LOGIC;

  ---------------------------
  -- Camera and Frame Buffer Signals
  ---------------------------
  -- Camera and Frame Buffer Signals (仅修正地址位宽)
  SIGNAL capture_addr : STD_LOGIC_VECTOR(16 DOWNTO 0); -- 修正：17位地址
  SIGNAL capture_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL capture_we : STD_LOGIC;
  SIGNAL config_finished : STD_LOGIC;

  -- 模式控制信号
  SIGNAL sw5 : STD_LOGIC := '0'; -- 运动检测器速度调整
  SIGNAL sw6 : STD_LOGIC := '0'; -- 冻结捕获
  SIGNAL survmode : STD_LOGIC := '0'; -- 监控模式（已废弃，保留兼容性）
  SIGNAL rgb : STD_LOGIC; -- RGB/YCbCr 色彩模式选择器  

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

BEGIN

  ----------------------------------------------------------------
  --- PORTS
  ----------------------------------------------------------------
  -- Button input handling
  KEY <= btnd & btnr & btnl & btnu; -- Combine button signals into KEY vector

  -- Switch input handling
  -- Note: SW1 to 6 used by ovregisters (mentioned in comment)
  -- rgb <= SW(3); -- Color mode selection: RGB when SW3 is on

  test_pattern_select(2 DOWNTO 0) <= SW(2 DOWNTO 0); -- Test pattern select

  OV7670_RESET <= '1'; -- Normal mode
  OV7670_PWDN <= '0'; -- Power device up
  OV7670_XCLK <= clk_25M; -- 使用从clk_wiz_0生成的25MHz时钟

  -- hist_enable <= SW(7); -- SW7: 直方图显示开关
  -- hist_mode <= SW(6 DOWNTO 5); -- SW6-SW5: 直方图类型 (00:Y, 01:R, 10:G, 11:B)
  -- frame_start <= OV7670_VSYNC; -- 帧开始信号

  -- 从VGA地址计算屏幕坐标 (简化版本，适用于320x240缩放到640x480)
  -- vga_x_coord <= STD_LOGIC_VECTOR(TO_UNSIGNED((TO_INTEGER(UNSIGNED(vga_request_addr)) MOD 320) * 2, 10));
  -- vga_y_coord <= STD_LOGIC_VECTOR(TO_UNSIGNED((TO_INTEGER(UNSIGNED(vga_request_addr)) / 320) * 2, 10));
  -- vga_display_active <= '1' WHEN TO_INTEGER(UNSIGNED(vga_request_addr)) < 76800 ELSE '0';

  -- final_pixel_data <= hist_pixel WHEN (hist_enable = '1' AND hist_pixel /= x"0000") ELSE output_yield_data;
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

  --   vga : vga_driver PORT MAP(
  --   clk => clk_25M,
  --   rst => '0',
  --   fb_addr => vga_request_addr,
  --   fb_data => final_pixel_data, -- 使用最终合成的像素数据
  --   hsync => VGA_HS,
  --   vsync => VGA_VS,
  --   red => VGA_R,
  --   green => VGA_G,
  --   blue => VGA_B,
  --   resolution_sel => "00"
  -- );

  -- ovcap : OV7670_capture PORT MAP
  -- (
  --   pclk => OV7670_PCLK,
  --   vsync => OV7670_VSYNC,
  --   href => OV7670_HREF,
  --   dport => OV7670_D,
  --   addr => capture_addr,
  --   dout => capture_data,
  --   we => capture_we,
  --   -- 废弃接口 - 连接但忽略
  --   surv => survmode,
  --   sw5 => sw5,
  --   sw6 => sw6,
  --   maxx => max
  -- );

  ovcap : OV7670_capture PORT MAP
  (
    pclk => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href => OV7670_HREF,
    dport => OV7670_D,
    addr => capture_addr,
    dout => capture_data,
    we => capture_we,
    reset => KEY(2) -- 复位信号
  );

  -- idcap : ideal_capture PORT MAP
  -- (
  --   pclk => clk_25M,
  --   vsync => OV7670_VSYNC,
  --   href => OV7670_HREF,
  --   dport => OV7670_D,
  --   addr => capture_addr,
  --   dout => capture_data,
  --   we => capture_we,
  --   reset => KEY(2) -- 复位信号
  -- );

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
  frmb : framebuffer PORT MAP
  (
    rdclock => clk_50M,
    rdaddress => fb_addr,
    q => fb_data,
    wrclock => clk_25M,
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
    wraddress => (OTHERS => '0'),
    wrclock => clk_50M,
    wren => '1',
    rdaddress => tp_addr,
    rdclock => clk_25M,
    q => tp_data
  );

  input_sel : input_selector PORT MAP
  (
    clk => clk_25M,
    select_input => SW(9),
    fb_addr => fb_addr,
    fb_data => fb_data,
    tp_addr => tp_addr,
    tp_data => tp_data,
    tp_select => tp_select,
    tp_pattern => SW(2 DOWNTO 0),
    vga_addr => vga_request_addr,
    vga_data => output_yield_data
  );

  --   -- 直方图生成器实例化
  -- hist_gen : histogram_generator PORT MAP(
  --   clk => OV7670_PCLK,
  --   reset => '0',

  --   -- 视频输入接口 - 直接使用capture数据
  --   pixel_data => capture_data,
  --   pixel_valid => capture_we,
  --   frame_start => frame_start,

  --   -- 直方图存储接口
  --   hist_addr => hist_addr,
  --   hist_data => hist_data,

  --   -- 控制接口
  --   mode => hist_mode
  -- );

  -- -- 直方图显示组件实例化
  -- hist_disp : histogram_display PORT MAP(
  --   clk => clk_25M,
  --   reset => '0',

  --   -- VGA位置输入
  --   x_pos => vga_x_coord,
  --   y_pos => vga_y_coord,
  --   active => vga_display_active,

  --   -- 直方图数据输入
  --   hist_data => hist_data,

  --   -- 直方图类型控制
  --   hist_type => hist_mode,

  --   -- 像素输出
  --   pixel_out => hist_pixel,
  --   hist_addr => hist_addr
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
  --   pclk => OV7670_PCLK,
  --   vsync => OV7670_VSYNC,
  --   href => OV7670_HREF,
  --   dport => OV7670_D,
  --   led_pclk_active => LEDB1, -- PCLK活跃指示
  --   led_vsync_active => LEDB2, -- VSYNC活跃指示
  --   led_href_active => LED(4), -- HREF活跃指示
  --   led_data_changing => data_changed, -- 数据变化指示
  --   debug_counter => cam_debug_counter, -- 调试计数器
  --   camera_working => LED(5) -- 摄像头工作状态
  -- );

  precise_debug : precise_camera_debug PORT MAP
  (
    clk_100m => clk_100M,
    reset => KEY(2),
    pclk => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href => OV7670_HREF,
    pclk_freq_khz => pclk_freq_khz, -- PCLK频率(kHz)
    vsync_freq_hz => vsync_freq_hz, -- VSYNC频率(Hz)
    href_freq_khz => href_freq_khz, -- HREF频率(kHz)
    led_pclk_normal => LED(3), -- PCLK频率正常(10-30MHz)
    led_vsync_normal => LED(4), -- VSYNC频率正常(20-40Hz)
    led_href_normal => LED(5), -- HREF频率正常(5-15kHz)
    led_timing_error => LED(6), -- 时序异常指示
    signals_static => LEDB1, -- 信号完全静止
    signals_identical => LEDB2 -- PCLK和VSYNC完全相同
  );

  ----------------------------------------------------------------
  --- Processes
  ----------------------------------------------------------------
  ----------------------------------------------------------------
  -- PROCESS (clk_50M)
  -- BEGIN
  --   IF rising_edge(clk_50M) THEN
  --     IF cnt >= CNT_MAX THEN
  --       cnt <= (OTHERS => '0');
  --       blink <= NOT blink;
  --     ELSE
  --       cnt <= cnt + 1;
  --     END IF;
  --     mSeg7 <= test_pattern_select;
  --   END IF;
  -- END PROCESS;

  -- debug_capture_process : PROCESS (OV7670_PCLK)
  -- BEGIN
  --   IF rising_edge(OV7670_PCLK) THEN
  --     -- 计算PCLK周期
  --     debug_pclk_count <= debug_pclk_count + 1;

  --     -- 统计VSYNC为低的时间
  --     IF OV7670_VSYNC = '0' THEN
  --       debug_vsync_low_count <= debug_vsync_low_count + 1;
  --     END IF;

  --     -- 检查有效捕获条件
  --     debug_valid_condition <= (NOT OV7670_VSYNC) AND OV7670_HREF;

  --     -- 监控capture活动
  --     debug_capture_active <= capture_we;

  --     IF debug_valid_condition = '1' THEN
  --       debug_pixel_count <= debug_pixel_count + 1;
  --     END IF;

  --     -- 记录最后写入的地址和数据
  --     IF capture_we = '1' THEN
  --       debug_last_addr <= capture_addr;
  --       debug_last_data <= capture_data;
  --       debug_pixel_count <= debug_pixel_count + 1;
  --       debug_total_pixels <= debug_total_pixels + 1;

  --       -- 统计非零数据
  --       IF capture_data /= x"0000" THEN
  --         debug_data_nonzero_count <= debug_data_nonzero_count + 1;
  --       END IF;

  --       -- 检测数据变化
  --       IF capture_data /= prev_data THEN
  --         data_changed <= '1';
  --       ELSE
  --         data_changed <= '0';
  --       END IF;
  --       prev_data <= capture_data;
  --     END IF;

  --     -- HREF计数
  --     IF OV7670_HREF = '1' THEN
  --       debug_href_count <= debug_href_count + 1;
  --     END IF;

  --     -- VSYNC边沿检测和帧计数
  --     vsync_prev <= OV7670_VSYNC;
  --     vsync_edge_detect <= OV7670_VSYNC AND NOT vsync_prev;

  --     IF vsync_edge_detect = '1' THEN
  --       debug_frame_count <= debug_frame_count + 1;
  --       debug_pixel_count <= (OTHERS => '0');
  --       -- 重置计数器以便观察每帧的情况
  --       debug_href_count <= (OTHERS => '0');
  --       debug_pclk_count <= (OTHERS => '0');
  --       debug_vsync_low_count <= (OTHERS => '0'); -- 重置
  --     END IF;
  --   END IF;
  -- END PROCESS;

  -- 修改现有的时钟进程，添加调试信息到七段数码管
  PROCESS (clk_50M)
  BEGIN
    IF rising_edge(clk_50M) THEN
      IF cnt >= CNT_MAX THEN
        cnt <= (OTHERS => '0');
        blink <= NOT blink;
      ELSE
        cnt <= cnt + 1;
      END IF;

      --     -- 根据开关选择显示不同的调试信息
      CASE SW(8 DOWNTO 6) IS
        WHEN "000" => mSeg7 <= test_pattern_select;
        WHEN "001" => mSeg7 <= cam_debug_counter;
        WHEN "010" => mSeg7 <= pclk_frequency; -- 017d大约为25MHz
        WHEN "011" => mSeg7 <= pclk_freq_khz; -- 41 约等于 8000
        WHEN "100" => mSeg7 <= vsync_freq_hz; -- 1F 约等于 30 
        WHEN "101" => mSeg7 <= href_freq_khz; -- F 约等于15
        WHEN "110" => mSeg7 <= capture_data;
        WHEN "111" => mSeg7 <= x"00" & OV7670_D;
        WHEN OTHERS => mSeg7 <= (OTHERS => '0');
      END CASE;
    END IF;
  END PROCESS;
  ----------------------------------------------------------------
  --- LEDS
  ----------------------------------------------------------------
  -- LED(0) <= blink;
  -- -- LED(15 DOWNTO 6) <= SW(9 DOWNTO 0);
  -- -- LED(5 DOWNTO 1) <= KEY(3 DOWNTO 0) & config_finished;
  -- LED(4) <= OV7670_VSYNC; -- 帧同步状态
  -- LED(5) <= OV7670_HREF; -- 行同步状态

  -- LEDB1 <= rgb;
  -- -- KEY <= btndpush & btnrpush & btnlpush & btnupush;

  LED(0) <= blink; -- 系统心跳
  LED(1) <= config_finished; -- 相机配置完成
  LED(2) <= KEY(2);
  LED(15) <= capture_we;
  -- LED(2) <= debug_capture_active; -- 实时捕获活动（应该闪烁）
  -- LED(3) <= OV7670_HREF; -- HREF状态（应该快速闪烁）
  -- LED(4) <= OV7670_VSYNC; -- VSYNC状态（应该慢速闪烁）
  -- LED(5) <= '1' WHEN debug_pixel_count > 0 ELSE
  -- '0'; -- 像素计数指示
  -- LED(6) <= '1' WHEN debug_href_count > 0 ELSE
  -- '0'; -- HREF计数指示
  -- LED(7) <= '1' WHEN debug_pclk_count > 0 ELSE
  -- '0'; -- PCLK计数指示
  -- LED(8) <= debug_valid_condition; -- 有效捕获条件指示
  -- LED(9) <= NOT OV7670_VSYNC; -- VSYNC反相
END rtl;