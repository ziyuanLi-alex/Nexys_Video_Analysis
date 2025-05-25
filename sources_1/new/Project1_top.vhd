----------------------------------------------------------------------------------
-- Project1_top.vhd - 集成光流计算和显示
--
-- 新增功能：
-- SW(4:3): 显示模式选择 (00=摄像头, 01=测试图案, 10=直方图, 11=光流)
-- SW(2:0): 测试图案模式/光流显示参数
-- SW(7:5): 光流显示控制
--   SW7: 光流使能
--   SW6-SW5: 光流显示模式 (00:原图 01:箭头 10:叠加 11:半透明)
-- SW(9:8): 光流颜色选择
--
-- 按键功能：
-- KEY0: 调整运动阈值
-- KEY1: 光流计算使能/禁用
-- KEY2: 系统复位
-- KEY3: 帧开始触发
--
-- LED指示：
-- LED(2): 光流计算活跃
-- LED(7): 光流矢量准备就绪
-- LED(8): 箭头显示状态
----------------------------------------------------------------------------------

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

    seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
    an : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    SW : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    btnu : IN STD_LOGIC;
    btnd : IN STD_LOGIC;
    btnl : IN STD_LOGIC;
    btnr : IN STD_LOGIC;

    LED : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    LEDB1 : OUT STD_LOGIC;
    LEDB2 : OUT STD_LOGIC
  );
END Project1_top;

ARCHITECTURE rtl OF Project1_top IS

  ----------------------------------------------------------------
  --- COMPONENTS (包含现有的所有组件)
  ---------------------------------------------------------------- 

  -- [保留所有现有组件声明]
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
      pclk : IN STD_LOGIC;
      vsync : IN STD_LOGIC;
      href : IN STD_LOGIC;
      dport : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
      addr : OUT STD_LOGIC_VECTOR (16 DOWNTO 0);
      dout : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      we : OUT STD_LOGIC;
      reset : IN STD_LOGIC
    );
  END COMPONENT;

  COMPONENT framebuffer
    PORT (
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT test_pattern_generator IS
    PORT (
      data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wraddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      wrclock : IN STD_LOGIC;
      wren : IN STD_LOGIC;
      rdaddress : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      rdclock : IN STD_LOGIC;
      q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT input_selector IS
    PORT (
      clk : IN STD_LOGIC;
      select_input : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      fb_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      fb_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      tp_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_select : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      tp_pattern : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      vga_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      vga_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      hist_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      hist_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      flow_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      flow_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT histogram_generator IS
    PORT (
      clk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      pixel_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      pixel_valid : IN STD_LOGIC;
      frame_start : IN STD_LOGIC;
      hist_bin_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      hist_bin_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT histogram_display IS
    PORT (
      clk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      hist_addr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
      hist_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      hist_bin_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      hist_bin_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      hist_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
    );
  END COMPONENT;

  -- 新增光流组件
  COMPONENT optical_flow_vector_calculator IS
    GENERIC (
      IMAGE_WIDTH : INTEGER := 320;
      IMAGE_HEIGHT : INTEGER := 240;
      VECTOR_GRID_X : INTEGER := 16;
      VECTOR_GRID_Y : INTEGER := 12;
      BLOCK_SIZE : INTEGER := 20;
      SEARCH_RANGE : INTEGER := 4
    );
    PORT (
      clk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      current_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      current_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      current_valid : IN STD_LOGIC;
      frame_start : IN STD_LOGIC;
      vector_request_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      vector_x : OUT SIGNED(7 DOWNTO 0);
      vector_y : OUT SIGNED(7 DOWNTO 0);
      vector_valid : OUT STD_LOGIC;
      processing_active : OUT STD_LOGIC;
      vectors_ready : OUT STD_LOGIC;
      current_vector_index : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT arrow_optical_flow_display IS
    GENERIC (
      IMAGE_WIDTH : INTEGER := 320;
      IMAGE_HEIGHT : INTEGER := 240;
      ARROW_GRID_X : INTEGER := 16;
      ARROW_GRID_Y : INTEGER := 12;
      ARROW_SIZE : INTEGER := 8;
      MIN_THRESHOLD : INTEGER := 10
    );
    PORT (
      clk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      bg_addr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      bg_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      bg_valid : IN STD_LOGIC;
      vector_addr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      vector_x : IN SIGNED(7 DOWNTO 0);
      vector_y : IN SIGNED(7 DOWNTO 0);
      vector_valid : IN STD_LOGIC;
      vga_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      vga_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      vga_pixel : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      vga_valid : OUT STD_LOGIC;
      display_mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      arrow_color : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      motion_threshold : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      arrow_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT precise_camera_debug IS
    PORT (
      clk_100m : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      pclk : IN STD_LOGIC;
      vsync : IN STD_LOGIC;
      href : IN STD_LOGIC;
      pclk_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      vsync_freq_hz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      href_freq_khz : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      led_pclk_normal : OUT STD_LOGIC;
      led_vsync_normal : OUT STD_LOGIC;
      led_href_normal : OUT STD_LOGIC;
      led_timing_error : OUT STD_LOGIC;
      signals_static : OUT STD_LOGIC;
      signals_identical : OUT STD_LOGIC
    );
  END COMPONENT;

  ----------------------------------------------------------------
  --- SIGNALS (包含现有信号和新增光流信号)
  ----------------------------------------------------------------

  -- [保留所有现有信号]
  SIGNAL xclk : STD_LOGIC := '0';
  SIGNAL clk_100M : STD_LOGIC;
  SIGNAL clk_50M : STD_LOGIC;
  SIGNAL clk_200M : STD_LOGIC;
  SIGNAL clk_25M : STD_LOGIC;
  SIGNAL locked : STD_LOGIC;

  CONSTANT CLOCK_50_FREQ : INTEGER := 50000000;
  CONSTANT BLINK_FREQ : INTEGER := 1;
  CONSTANT CNT_MAX : INTEGER := CLOCK_50_FREQ/BLINK_FREQ/2 - 1;
  SIGNAL cnt : unsigned(24 DOWNTO 0);
  SIGNAL blink : STD_LOGIC;

  SIGNAL capture_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL capture_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL capture_we : STD_LOGIC;
  SIGNAL config_finished : STD_LOGIC;

  SIGNAL KEY : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL mSEG7 : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
  
  SIGNAL vga_request_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL output_yield_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL fb_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL fb_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL tp_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL tp_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL tp_select : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL hist_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL hist_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL hist_bin_addr : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL hist_bin_data : STD_LOGIC_VECTOR(15 DOWNTO 0);

  -- 新增光流相关信号
  SIGNAL flow_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL flow_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  
  -- 光流计算器信号
  SIGNAL flow_calc_enable : STD_LOGIC;
  SIGNAL flow_current_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL flow_current_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL flow_current_valid : STD_LOGIC;
  SIGNAL flow_frame_start : STD_LOGIC;
  SIGNAL flow_vector_request_addr : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL flow_vector_x : SIGNED(7 DOWNTO 0);
  SIGNAL flow_vector_y : SIGNED(7 DOWNTO 0);
  SIGNAL flow_vector_valid : STD_LOGIC;
  SIGNAL flow_processing_active : STD_LOGIC;
  SIGNAL flow_vectors_ready : STD_LOGIC;
  SIGNAL flow_current_vector_index : STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- 箭头显示信号
  SIGNAL arrow_display_enable : STD_LOGIC;
  SIGNAL arrow_bg_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL arrow_bg_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL arrow_bg_valid : STD_LOGIC;
  SIGNAL arrow_vector_addr : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL arrow_vga_x : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL arrow_vga_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL arrow_vga_pixel : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL arrow_vga_valid : STD_LOGIC;
  SIGNAL arrow_display_mode : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL arrow_color : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL arrow_motion_threshold : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL arrow_count : STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- 调试信号
  SIGNAL pclk_freq_khz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL vsync_freq_hz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
  SIGNAL href_freq_khz : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

BEGIN

  ----------------------------------------------------------------
  --- PORTS MAPPING
  ----------------------------------------------------------------
  
  KEY <= btnd & btnr & btnl & btnu;
  
  OV7670_RESET <= '1';
  OV7670_PWDN <= '0';
  OV7670_XCLK <= clk_25M;

  -- 光流控制信号
  flow_calc_enable <= '1'; -- SW7开关 + KEY1按键
  arrow_display_enable <= '1';
  arrow_display_mode <= SW(6 DOWNTO 5);
  arrow_color <= SW(2 DOWNTO 0);
  arrow_motion_threshold <= "0001" & SW(3 DOWNTO 0); -- 运动阈值
  flow_frame_start <= OV7670_VSYNC;

  ----------------------------------------------------------------
  --- COMPONENT INSTANCES
  ----------------------------------------------------------------

  -- [保留所有现有组件实例]
  clk_wiz : clk_wiz_0
  PORT MAP(
    clk_100M => clk_100M,
    clk_50M => clk_50M,
    clk_200M => clk_200M,
    clk_25M => clk_25M,
    locked => locked,
    clk_in => CLOCK_100
  );

  disp : display PORT MAP (
    clk => CLOCK_100,
    number => mSEG7,
    seg => seg,
    an => an
  );

  ovdr : OV7670_driver PORT MAP (
    iclk50 => clk_50M,
    config_finished => config_finished,
    sioc => ov7670_sioc,
    siod => ov7670_siod,
    sw => SW,
    key => KEY
  );

  vga : vga_driver PORT MAP(
    clk => clk_25M,
    rst => '0',
    fb_addr => vga_request_addr,
    fb_data => output_yield_data,
    hsync => VGA_HS,
    vsync => VGA_VS,
    red => VGA_R,
    green => VGA_G,
    blue => VGA_B,
    resolution_sel => "00"
  );

  ovcap : OV7670_capture PORT MAP (
    pclk => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href => OV7670_HREF,
    dport => OV7670_D,
    addr => capture_addr,
    dout => capture_data,
    we => capture_we,
    reset => KEY(2)
  );

  frmb : framebuffer PORT MAP (
    rdclock => clk_50M,
    rdaddress => fb_addr,
    q => fb_data,
    wrclock => OV7670_PCLK,
    wraddress => capture_addr,
    data => capture_data,
    wren => capture_we
  );

  input_sel : input_selector PORT MAP (
    clk => clk_50M,
    select_input => SW(4 DOWNTO 3),
    fb_addr => fb_addr,
    fb_data => fb_data,
    tp_addr => tp_addr,
    tp_data => tp_data,
    tp_select => tp_select,
    tp_pattern => SW(2 DOWNTO 0),
    hist_addr => hist_addr,
    hist_data => hist_data,
    flow_addr => flow_addr,
    flow_data => flow_data,
    vga_addr => vga_request_addr,
    vga_data => output_yield_data
  );

  test_pattern_gen : test_pattern_generator PORT MAP (
    data => tp_select,
    wraddress => (OTHERS => '0'),
    wrclock => clk_50M,
    wren => '1',
    rdaddress => tp_addr,
    rdclock => clk_25M,
    q => tp_data
  );

  hist_gen : histogram_generator PORT MAP (
    clk => clk_100M,
    reset => KEY(2),
    pixel_data => capture_data,
    pixel_valid => capture_we,
    frame_start => OV7670_vsync,
    hist_bin_addr => hist_bin_addr,
    hist_bin_data => hist_bin_data,
    mode => SW(1 DOWNTO 0)
  );

  hist_disp : histogram_display PORT MAP (
    clk => clk_100M,
    reset => KEY(2),
    hist_addr => hist_addr,
    hist_data => hist_data,
    hist_bin_addr => hist_bin_addr,
    hist_bin_data => hist_bin_data,
    hist_type => SW(1 DOWNTO 0)
  );

  -- 新增光流组件实例
  optical_flow_calc : optical_flow_vector_calculator PORT MAP (
    clk => clk_100M,
    reset => KEY(2),
    enable => flow_calc_enable,
    current_addr => flow_current_addr,
    current_data => flow_current_data,
    current_valid => flow_current_valid,
    frame_start => flow_frame_start,
    vector_request_addr => flow_vector_request_addr,
    vector_x => flow_vector_x,
    vector_y => flow_vector_y,
    vector_valid => flow_vector_valid,
    processing_active => flow_processing_active,
    vectors_ready => flow_vectors_ready,
    current_vector_index => flow_current_vector_index
  );

  arrow_flow_display : arrow_optical_flow_display PORT MAP (
    clk => clk_100M,
    reset => KEY(2),
    enable => arrow_display_enable,
    bg_addr => arrow_bg_addr,
    bg_data => arrow_bg_data,
    bg_valid => arrow_bg_valid,
    vector_addr => arrow_vector_addr,
    vector_x => flow_vector_x,
    vector_y => flow_vector_y,
    vector_valid => flow_vector_valid,
    vga_x => arrow_vga_x,
    vga_y => arrow_vga_y,
    vga_pixel => arrow_vga_pixel,
    vga_valid => arrow_vga_valid,
    display_mode => arrow_display_mode,
    arrow_color => arrow_color,
    motion_threshold => arrow_motion_threshold,
    arrow_count => arrow_count
  );

  precise_debug : precise_camera_debug PORT MAP (
    clk_100m => clk_100M,
    reset => KEY(2),
    pclk => OV7670_PCLK,
    vsync => OV7670_VSYNC,
    href => OV7670_HREF,
    pclk_freq_khz => pclk_freq_khz,
    vsync_freq_hz => vsync_freq_hz,
    href_freq_khz => href_freq_khz,
    led_pclk_normal => LED(3),
    led_vsync_normal => LED(4),
    led_href_normal => LED(5),
    led_timing_error => LED(6),
    signals_static => LEDB1,
    signals_identical => LEDB2
  );

  ----------------------------------------------------------------
  --- 光流数据路由逻辑
  ----------------------------------------------------------------
  
  -- 光流计算器与帧缓冲区连接
  flow_current_data <= fb_data;
  flow_current_valid <= '1'; -- 简化：假设framebuffer数据总是有效
  
  -- 光流显示数据路由
  PROCESS (SW(4 DOWNTO 3), flow_addr, arrow_vga_pixel, fb_data)
  BEGIN
    IF SW(4 DOWNTO 3) = "11" THEN -- 光流显示模式
      flow_data <= arrow_vga_pixel;
      arrow_bg_data <= fb_data;
      arrow_bg_valid <= '1';
    ELSE
      flow_data <= (OTHERS => '0');
      arrow_bg_data <= (OTHERS => '0');
      arrow_bg_valid <= '0';
    END IF;
  END PROCESS;

  -- VGA坐标传递给箭头显示模块
  arrow_vga_x <= STD_LOGIC_VECTOR(TO_UNSIGNED(
    (TO_INTEGER(UNSIGNED(vga_request_addr)) MOD 320), 10));
  arrow_vga_y <= STD_LOGIC_VECTOR(TO_UNSIGNED(
    (TO_INTEGER(UNSIGNED(vga_request_addr)) / 320), 10));

  -- 矢量地址连接
  flow_vector_request_addr <= arrow_vector_addr;

  ----------------------------------------------------------------
  --- PROCESSES
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

      -- 七段数码管显示选择
      CASE SW(8 DOWNTO 6) IS
        WHEN "000" => mSeg7 <= tp_select;
        WHEN "001" => mSeg7 <= pclk_freq_khz;
        WHEN "010" => mSeg7 <= vsync_freq_hz;
        WHEN "011" => mSeg7 <= href_freq_khz;
        WHEN "100" => mSeg7 <= capture_data;
        WHEN "101" => mSeg7 <= x"00" & flow_current_vector_index;
        WHEN "110" => mSeg7 <= x"00" & arrow_count;
        WHEN "111" => mSeg7 <= STD_LOGIC_VECTOR(resize(unsigned(flow_vector_x), 8)) & 
                              STD_LOGIC_VECTOR(resize(unsigned(flow_vector_y), 8));
        WHEN OTHERS => mSeg7 <= (OTHERS => '0');
      END CASE;
    END IF;
  END PROCESS;

  ----------------------------------------------------------------
  --- LED状态指示
  ----------------------------------------------------------------
  
  LED(0) <= blink; -- 系统心跳
  LED(1) <= config_finished; -- 相机配置完成  
  LED(2) <= flow_processing_active; -- 光流计算活跃
  LED(7) <= flow_vectors_ready; -- 光流矢量准备就绪
  LED(8) <= arrow_display_enable; -- 箭头显示状态
  LED(9) <= flow_calc_enable; -- 光流计算使能状态
  LED(10) <= capture_we; -- 摄像头数据写入状态
  LED(11) <= OV7670_VSYNC; -- 垂直同步状态
  LED(12) <= OV7670_HREF; -- 水平同步状态
  LED(15) <= KEY(2); -- 复位按键状态

END rtl;