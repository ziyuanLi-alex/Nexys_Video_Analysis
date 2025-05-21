LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY vga_driver IS
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
END ENTITY vga_driver;

ARCHITECTURE Behavioral OF vga_driver IS
    -- Horizontal and vertical counters
    SIGNAL h_count    : INTEGER RANGE 0 TO H_WHOLE_LINE-1 := 0;
    SIGNAL v_count    : INTEGER RANGE 0 TO V_WHOLE_FRAME-1 := 0;
    
    -- Display active region flags
    SIGNAL h_active   : STD_LOGIC := '0';
    SIGNAL v_active   : STD_LOGIC := '0';
    SIGNAL display_on : STD_LOGIC := '0';
    
    -- Pixel coordinates within the display area
    SIGNAL x_pos      : INTEGER RANGE 0 TO H_VISIBLE_AREA-1 := 0;
    SIGNAL y_pos      : INTEGER RANGE 0 TO V_VISIBLE_AREA-1 := 0;
    
    -- Frame buffer address calculation
    SIGNAL fb_x       : INTEGER RANGE 0 TO FB_WIDTH-1 := 0;
    SIGNAL fb_y       : INTEGER RANGE 0 TO FB_HEIGHT-1 := 0;
    SIGNAL fb_index   : INTEGER RANGE 0 TO FB_WIDTH*FB_HEIGHT-1 := 0;
    
    -- Color component extraction
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL r_data     : STD_LOGIC_VECTOR(RED_BITS-1 DOWNTO 0);
    SIGNAL g_data     : STD_LOGIC_VECTOR(GREEN_BITS-1 DOWNTO 0);
    SIGNAL b_data     : STD_LOGIC_VECTOR(BLUE_BITS-1 DOWNTO 0);
    
    -- Scaling factors (can be adjusted based on resolution_sel)
    CONSTANT SCALE_X  : INTEGER := H_VISIBLE_AREA / FB_WIDTH;  -- Default for 640x480
    CONSTANT SCALE_Y  : INTEGER := V_VISIBLE_AREA / FB_HEIGHT; -- Default for 640x480
    
    -- Pre-calculated address pipeline
    SIGNAL addr_valid : STD_LOGIC := '0';
    SIGNAL fb_addr_reg : STD_LOGIC_VECTOR(12 DOWNTO 0) := (OTHERS => '0');
    
BEGIN
    -- VGA timing generation process
    vga_timing: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                h_count <= 0;
                v_count <= 0;
                hsync <= '1';  -- Sync pulses are active low
                vsync <= '1';
                h_active <= '0';
                v_active <= '0';
                display_on <= '0';
            ELSE
                -- Horizontal counter
                IF h_count < H_WHOLE_LINE-1 THEN
                    h_count <= h_count + 1;
                ELSE
                    h_count <= 0;
                    -- Vertical counter
                    IF v_count < V_WHOLE_FRAME-1 THEN
                        v_count <= v_count + 1;
                    ELSE
                        v_count <= 0;
                    END IF;
                END IF;
                
                -- Generate HSYNC
                IF (h_count >= H_VISIBLE_AREA + H_FRONT_PORCH) AND 
                   (h_count < H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE) THEN
                    hsync <= '0';  -- Active low sync pulse
                ELSE
                    hsync <= '1';
                END IF;
                
                -- Generate VSYNC
                IF (v_count >= V_VISIBLE_AREA + V_FRONT_PORCH) AND 
                   (v_count < V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE) THEN
                    vsync <= '0';  -- Active low sync pulse
                ELSE
                    vsync <= '1';
                END IF;
                
                -- Determine active display region
                IF h_count < H_VISIBLE_AREA THEN
                    h_active <= '1';
                    x_pos <= h_count;
                ELSE
                    h_active <= '0';
                END IF;
                
                IF v_count < V_VISIBLE_AREA THEN
                    v_active <= '1';
                    y_pos <= v_count;
                ELSE
                    v_active <= '0';
                END IF;
                
                display_on <= h_active AND v_active;
            END IF;
        END IF;
    END PROCESS vga_timing;
    
    -- Frame buffer address calculation - separate process to ensure proper timing
    address_calc: PROCESS(clk)
        VARIABLE scaled_x : INTEGER;
        VARIABLE scaled_y : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            IF h_active = '1' AND v_active = '1' THEN
                -- Ensure x and y are properly bounded to prevent overflow
                -- Scale down the display coordinates to get frame buffer coordinates
                scaled_x := x_pos / SCALE_X;
                scaled_y := y_pos / SCALE_Y;
                
                -- Make sure we don't exceed buffer dimensions
                IF scaled_x >= FB_WIDTH THEN
                    scaled_x := FB_WIDTH - 1;
                END IF;
                
                IF scaled_y >= FB_HEIGHT THEN
                    scaled_y := FB_HEIGHT - 1;
                END IF;
                
                -- Calculate linear address in frame buffer
                fb_index <= scaled_y * FB_WIDTH + scaled_x;
                addr_valid <= '1';
            ELSE
                addr_valid <= '0';
            END IF;
            
            -- Register address to ensure stable output
            fb_addr_reg <= STD_LOGIC_VECTOR(TO_UNSIGNED(fb_index, 13));
        END IF;
    END PROCESS address_calc;
    
    -- Output the calculated address
    fb_addr <= fb_addr_reg;
    
    -- Color output process
    color_output: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF display_on = '1' THEN
                -- Extract color components from the RGB565 pixel data
                r_data <= fb_data(15 DOWNTO 11);  -- 5 bits for red
                g_data <= fb_data(10 DOWNTO 5);   -- 6 bits for green
                b_data <= fb_data(4 DOWNTO 0);    -- 5 bits for blue
                
                -- Output the colors with appropriate bit width conversion
                red   <= r_data(RED_BITS-1 DOWNTO RED_BITS-OUTPUT_BITS);
                green <= g_data(GREEN_BITS-1 DOWNTO GREEN_BITS-OUTPUT_BITS);
                blue  <= b_data(BLUE_BITS-1 DOWNTO BLUE_BITS-OUTPUT_BITS);
            ELSE
                -- Outside the visible area, output black
                red   <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue  <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS color_output;
    
END Behavioral;