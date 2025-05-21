library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity histogram_generator is
port (
    data : in std_logic_vector(15 downto 0);         -- Input pixel data
    wraddress : in std_logic_vector(12 downto 0);    -- Write address
    wrclock : in std_logic;                          -- Write clock
    wren : in std_logic;                             -- Write enable
    rdaddress : in std_logic_vector(12 downto 0);    -- Read address for display buffer
    rdclock : in std_logic;                          -- Read clock
    q : out std_logic_vector(15 downto 0)            -- Output pixel value for display
);
end entity;

architecture rtl of histogram_generator is
    -- Constants for display dimensions and colors
    constant HIST_WIDTH : integer := 192;    -- 64 bins * 3 pixels width per bin
    constant HIST_HEIGHT : integer := 256;   -- Maximum height for histogram
    constant DISPLAY_WIDTH : integer := 256; -- Width of display area including margins
    
    -- Color definitions (RGB444)
    constant COLOR_RED : std_logic_vector(15 downto 0) := X"070F";    -- Red channel histogram
    constant COLOR_GREEN : std_logic_vector(15 downto 0) := X"F070";   -- Green channel histogram
    constant COLOR_BLUE : std_logic_vector(15 downto 0) := X"070F";    -- Blue channel histogram
    constant COLOR_BACKGROUND : std_logic_vector(15 downto 0) := X"0000"; -- Black background
    constant COLOR_GRID : std_logic_vector(15 downto 0) := X"4444";     -- Grey grid lines
    
    -- Type definitions for histogram and display buffer
    type histogram_array is array(0 to 47) of unsigned(15 downto 0);
    type display_buffer_type is array(0 to 8191) of std_logic_vector(15 downto 0);
    
    -- Histogram data storage
    signal histogram : histogram_array := (others => (others => '0'));
    
    -- Display buffer (reusing the same structure as framebuffer)
    signal display_buffer : display_buffer_type := (others => COLOR_BACKGROUND);
    
    -- Temporary signals for color extraction
    signal red_value : unsigned(3 downto 0);
    signal green_value : unsigned(3 downto 0);
    signal blue_value : unsigned(3 downto 0);
    
    -- Signals for bin indexing
    signal red_bin : integer range 0 to 15;
    signal green_bin : integer range 0 to 15;
    signal blue_bin : integer range 0 to 15;
    
    -- Normalized histogram values (scaled to fit the display height)
    signal norm_histogram : histogram_array := (others => (others => '0'));
    
    -- Maximum values in each channel for normalization
    signal max_red : unsigned(15 downto 0) := (others => '0');
    signal max_green : unsigned(15 downto 0) := (others => '0');
    signal max_blue : unsigned(15 downto 0) := (others => '0');
    
    -- Flag to indicate the histogram has been updated and display needs refresh
    signal update_display : std_logic := '0';
    
    -- Frame counter for normalization timing
    signal frame_counter : unsigned(7 downto 0) := (others => '0');
    
    -- Special address for reset
    constant RESET_ADDRESS : std_logic_vector(12 downto 0) := "1111111111111";
    signal reset_histogram : std_logic := '0';
    
    -- Function to calculate display address from x,y coordinates
    function get_display_addr(x: integer; y: integer) return integer is
    begin
        return y * DISPLAY_WIDTH + x;
    end function;
    
begin
    -- Extract color components from input data (assuming RGB444 format from the VGA driver)
    red_value <= unsigned(data(7 downto 4));
    green_value <= unsigned(data(11 downto 8));
    blue_value <= unsigned(data(3 downto 0));
    
    -- Map color values to bin indexes
    red_bin <= to_integer(red_value);
    green_bin <= to_integer(green_value);
    blue_bin <= to_integer(blue_value);
    
    -- Check if reset is requested
    reset_histogram <= '1' when wraddress = RESET_ADDRESS and wren = '1' else '0';

    -- Process for updating histogram
    process(wrclock)
        variable max_val : unsigned(15 downto 0);
    begin
        if rising_edge(wrclock) then
            -- Handle reset request
            if reset_histogram = '1' then
                -- Reset all histogram bins and normalization values
                for i in 0 to 47 loop
                    histogram(i) <= (others => '0');
                    norm_histogram(i) <= (others => '0');
                end loop;
                max_red <= (others => '0');
                max_green <= (others => '0');
                max_blue <= (others => '0');
                frame_counter <= (others => '0');
                update_display <= '1';  -- Trigger a display refresh
                
            elsif wren = '1' then
                -- Increment the appropriate bins for each color channel
                -- Avoid overflow by checking
                if histogram(red_bin) < X"FFFF" then
                    histogram(red_bin) <= histogram(red_bin) + 1;
                end if;
                
                if histogram(16 + green_bin) < X"FFFF" then
                    histogram(16 + green_bin) <= histogram(16 + green_bin) + 1;
                end if;
                
                if histogram(32 + blue_bin) < X"FFFF" then
                    histogram(32 + blue_bin) <= histogram(32 + blue_bin) + 1;
                end if;
                
                -- Increment frame counter for periodic normalization and display update
                frame_counter <= frame_counter + 1;
                
                -- Every 64 frames, normalize histogram and update display
                if frame_counter = X"3F" then
                    -- Find maximum values for each channel
                    max_val := (others => '0');
                    for i in 0 to 15 loop
                        if histogram(i) > max_val then
                            max_val := histogram(i);
                        end if;
                    end loop;
                    max_red <= max_val;
                    
                    max_val := (others => '0');
                    for i in 16 to 31 loop
                        if histogram(i) > max_val then
                            max_val := histogram(i);
                        end if;
                    end loop;
                    max_green <= max_val;
                    
                    max_val := (others => '0');
                    for i in 32 to 47 loop
                        if histogram(i) > max_val then
                            max_val := histogram(i);
                        end if;
                    end loop;
                    max_blue <= max_val;
                    
                    -- Calculate normalized histogram values
                    for i in 0 to 15 loop
                        if max_red > 0 then
                            norm_histogram(i) <= resize(histogram(i) * 200 / max_red, 16);
                        else
                            norm_histogram(i) <= (others => '0');
                        end if;
                    end loop;
                    
                    for i in 16 to 31 loop
                        if max_green > 0 then
                            norm_histogram(i) <= resize(histogram(i) * 200 / max_green, 16);
                        else
                            norm_histogram(i) <= (others => '0');
                        end if;
                    end loop;
                    
                    for i in 32 to 47 loop
                        if max_blue > 0 then
                            norm_histogram(i) <= resize(histogram(i) * 200 / max_blue, 16);
                        else
                            norm_histogram(i) <= (others => '0');
                        end if;
                    end loop;
                    
                    -- Signal to update the display
                    update_display <= '1';
                    frame_counter <= (others => '0');
                end if;
            end if;
            
            -- Update display buffer when requested
            if update_display = '1' then
                -- Reset display buffer to background color
                for i in 0 to 8191 loop
                    display_buffer(i) <= COLOR_BACKGROUND;
                end loop;
                
                -- Draw grid lines
                for y in 0 to HIST_HEIGHT-1 loop
                    if y mod 40 = 0 then  -- Horizontal grid lines
                        for x in 0 to HIST_WIDTH-1 loop
                            if get_display_addr(x, y) < 8192 then
                                display_buffer(get_display_addr(x, y)) <= COLOR_GRID;
                            end if;
                        end loop;
                    end if;
                end loop;
                
                for x in 0 to HIST_WIDTH-1 loop
                    if x mod 12 = 0 then  -- Vertical grid lines
                        for y in 0 to HIST_HEIGHT-1 loop
                            if get_display_addr(x, y) < 8192 then
                                display_buffer(get_display_addr(x, y)) <= COLOR_GRID;
                            end if;
                        end loop;
                    end if;
                end loop;
                
                -- Draw red histogram (bins 0-15)
                for bin in 0 to 15 loop
                    -- Get height for this bin
                    for y in 0 to to_integer(norm_histogram(bin))-1 loop
                        -- Each bin is 3 pixels wide
                        for w in 0 to 2 loop
                            if get_display_addr(bin*4 + w, HIST_HEIGHT-1 - y) < 8192 then
                                display_buffer(get_display_addr(bin*4 + w, HIST_HEIGHT-1 - y)) <= COLOR_RED;
                            end if;
                        end loop;
                    end loop;
                end loop;
                
                -- Draw green histogram (bins 16-31)
                for bin in 0 to 15 loop
                    -- Get height for this bin
                    for y in 0 to to_integer(norm_histogram(bin+16))-1 loop
                        -- Each bin is 3 pixels wide
                        for w in 0 to 2 loop
                            if get_display_addr(bin*4 + w + 64, HIST_HEIGHT-1 - y) < 8192 then
                                display_buffer(get_display_addr(bin*4 + w + 64, HIST_HEIGHT-1 - y)) <= COLOR_GREEN;
                            end if;
                        end loop;
                    end loop;
                end loop;
                
                -- Draw blue histogram (bins 32-47)
                for bin in 0 to 15 loop
                    -- Get height for this bin
                    for y in 0 to to_integer(norm_histogram(bin+32))-1 loop
                        -- Each bin is 3 pixels wide
                        for w in 0 to 2 loop
                            if get_display_addr(bin*4 + w + 128, HIST_HEIGHT-1 - y) < 8192 then
                                display_buffer(get_display_addr(bin*4 + w + 128, HIST_HEIGHT-1 - y)) <= COLOR_BLUE;
                            end if;
                        end loop;
                    end loop;
                end loop;
                
                update_display <= '0';  -- Reset update flag
            end if;
        end if;
    end process;

    -- Process for reading display buffer data
    process(rdclock)
    begin
        if rising_edge(rdclock) then
            -- Read from display buffer using the provided read address
            if to_integer(unsigned(rdaddress)) < 8192 then
                q <= display_buffer(to_integer(unsigned(rdaddress)));
            else
                q <= COLOR_BACKGROUND;
            end if;
        end if;
    end process;
    
end architecture;