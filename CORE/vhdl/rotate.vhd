----------------------------------------------------------------------------------
-- Phoenix for MEGA65
--
-- Screen rotation for vertical arcade games, using a double frame buffer in BRAM
--
-- Input:  the native Phoenix raster (G_SRC_DX x G_SRC_DY visible pixels, one pixel
--         per src_ce, i.e. at 5.5 MHz), with registered RGB/blanking as it comes
--         out of phoenix.vhd.
-- Output: a raster of exactly the same frame period (G_OUT_HTOTAL x G_OUT_VTOTAL
--         at one pixel per clk_i, i.e. 11 MHz, 704 x 262 = 2 * 352 x 262), so the
--         output is frame locked to the input: every time the core finishes a frame,
--         the buffers are swapped and the output frame restarts.
--
--         The visible area of the output is a 4:3 "box" of G_BOX_DX x G_SRC_DX
--         pixels with the rotated G_SRC_DY x G_SRC_DX image centered in it (black
--         pillars left and right). The M2M framework stretches the core's visible
--         area to 4:3 on HDMI (and a VGA monitor does the same), so the box width
--         is chosen such that the image ends up with the original aspect ratio.
--         Phoenix: visible area 239 x 208 (MiSTer: arcade_video WIDTH = 239), shown
--         by MiSTer with an aspect ratio of 478:373, i.e. 373:478 when rotated:
--         G_BOX_DX = 4/3 * 208 * 478/373 = 355.4 -> 356.
--
--   rot_ccw_i = '0': rotate 90 degrees clockwise          (MAME ROT90)
--   rot_ccw_i = '1': rotate 90 degrees counter-clockwise  (MAME ROT270)
--
-- Double buffering: the core writes into one buffer while the output reads the
-- other one, so there is no tearing; latency is one frame.
--
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rotate is
   generic (
      G_SRC_DX       : natural := 239;    -- native visible width  (must be <= 256)
      G_SRC_DY       : natural := 208;    -- native visible height (must be <= 256)
      G_OUT_HTOTAL   : natural := 704;    -- output clocks per line
      G_OUT_VTOTAL   : natural := 262;    -- output lines per frame
      G_BOX_DX       : natural := 356;    -- visible output width (4:3 box)
      G_HS_START     : natural := 450;    -- output hsync start (inside horizontal blank)
      G_HS_END       : natural := 502;    -- output hsync end (exclusive), 52 clocks = 4.7 us
      G_VS_START     : natural := 245;    -- output vsync start line (inside vertical blank)
      G_VS_END       : natural := 248     -- output vsync end line (exclusive)
   );
   port (
      clk_i          : in  std_logic;     -- 11 MHz Phoenix clock
      rot_ccw_i      : in  std_logic;

      -- native input (registered outputs of phoenix.vhd, valid when src_ce_i = '1')
      src_ce_i       : in  std_logic;
      src_rgb_i      : in  std_logic_vector(5 downto 0);
      src_hblank_i   : in  std_logic;
      src_vblank_i   : in  std_logic;

      -- rotated output, one pixel per clk_i
      dst_rgb_o      : out std_logic_vector(5 downto 0);
      dst_hs_o       : out std_logic;
      dst_vs_o       : out std_logic;
      dst_hblank_o   : out std_logic;
      dst_vblank_o   : out std_logic
   );
end entity rotate;

architecture synthesis of rotate is

   constant C_IMG_X0    : natural := (G_BOX_DX - G_SRC_DY) / 2;   -- first image column inside the box

   -- 2 buffers of 256 x 256 entries (only G_SRC_DX x G_SRC_DY are used): address = buf & y & x
   type ram_t is array (0 to 2**17 - 1) of std_logic_vector(5 downto 0);
   signal ram           : ram_t;
   attribute ram_style  : string;
   attribute ram_style of ram : signal is "block";

   -- write side (native raster)
   signal wr_x          : unsigned(8 downto 0) := (others => '0');
   signal wr_y          : unsigned(8 downto 0) := (others => '0');
   signal wr_buf        : std_logic := '0';
   signal wr_en         : std_logic;
   signal wr_addr       : std_logic_vector(16 downto 0);
   signal src_active_d  : std_logic := '0';
   signal src_vblank_d  : std_logic := '0';
   signal frame_done    : std_logic;

   -- read side (rotated raster)
   signal out_x         : natural range 0 to G_OUT_HTOTAL - 1 := 0;
   signal out_y         : natural range 0 to G_OUT_VTOTAL - 1 := 0;
   signal rd_buf        : std_logic := '1';
   signal rd_addr       : std_logic_vector(16 downto 0);
   signal rd_data       : std_logic_vector(5 downto 0);

   -- stage 1 (same clock as the RAM read)
   signal s1_img        : std_logic := '0';
   signal s1_hblank     : std_logic := '1';
   signal s1_vblank     : std_logic := '1';
   signal s1_hs         : std_logic := '0';
   signal s1_vs         : std_logic := '0';

begin

   ---------------------------------------------------------------------------------------------
   -- Write side: store the native frame
   ---------------------------------------------------------------------------------------------

   -- end of the visible frame = rising edge of vblank (sampled on src_ce_i)
   frame_done <= src_ce_i and src_vblank_i and not src_vblank_d;

   wr_en   <= '1' when src_ce_i = '1' and src_hblank_i = '0' and src_vblank_i = '0' and
                       wr_x < G_SRC_DX and wr_y < G_SRC_DY else '0';
   wr_addr <= wr_buf & std_logic_vector(wr_y(7 downto 0)) & std_logic_vector(wr_x(7 downto 0));

   p_write : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if src_ce_i = '1' then
            src_vblank_d <= src_vblank_i;
            src_active_d <= not src_hblank_i and not src_vblank_i;

            if src_vblank_i = '1' then
               wr_x <= (others => '0');
               wr_y <= (others => '0');
               if src_vblank_d = '0' then
                  wr_buf <= not wr_buf;                       -- frame complete: write the other buffer next
               end if;
            elsif src_hblank_i = '0' then
               if wr_x /= 511 then
                  wr_x <= wr_x + 1;
               end if;
            elsif src_active_d = '1' then                     -- end of a visible line
               wr_x <= (others => '0');
               if wr_y /= 511 then
                  wr_y <= wr_y + 1;
               end if;
            end if;
         end if;
      end if;
   end process p_write;

   ---------------------------------------------------------------------------------------------
   -- Frame buffer RAM: simple dual port, one write and one read port, same clock
   ---------------------------------------------------------------------------------------------

   p_ram : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' then
            ram(to_integer(unsigned(wr_addr))) <= src_rgb_i;
         end if;
         rd_data <= ram(to_integer(unsigned(rd_addr)));
      end if;
   end process p_ram;

   ---------------------------------------------------------------------------------------------
   -- Read side: rotated output raster, frame locked to the input
   ---------------------------------------------------------------------------------------------

   -- source coordinates of the output pixel
   p_rd_addr : process(all)
      variable img_x : natural range 0 to G_SRC_DY - 1;
      variable src_x : natural range 0 to 255;
      variable src_y : natural range 0 to 255;
   begin
      if out_x >= C_IMG_X0 and out_x < C_IMG_X0 + G_SRC_DY then
         img_x := out_x - C_IMG_X0;
      else
         img_x := 0;
      end if;

      if out_y < G_SRC_DX then
         if rot_ccw_i = '0' then
            -- clockwise: output line = source column, output column runs from source bottom to top
            src_x := out_y;
            src_y := G_SRC_DY - 1 - img_x;
         else
            -- counter-clockwise: output line = source column from the right, column = source row
            src_x := G_SRC_DX - 1 - out_y;
            src_y := img_x;
         end if;
      else
         src_x := 0;
         src_y := 0;
      end if;

      rd_addr <= rd_buf & std_logic_vector(to_unsigned(src_y, 8)) & std_logic_vector(to_unsigned(src_x, 8));
   end process p_rd_addr;

   p_read : process(clk_i)
   begin
      if rising_edge(clk_i) then
         -- stage 1: timing for the pixel whose RAM read happens in this very clock
         s1_hblank <= '1' when out_x >= G_BOX_DX else '0';
         s1_vblank <= '1' when out_y >= G_SRC_DX else '0';
         s1_img    <= '1' when out_x >= C_IMG_X0 and out_x < C_IMG_X0 + G_SRC_DY and out_y < G_SRC_DX else '0';
         s1_hs     <= '1' when out_x >= G_HS_START and out_x < G_HS_END else '0';
         s1_vs     <= '1' when out_y >= G_VS_START and out_y < G_VS_END else '0';

         -- stage 2: outputs
         dst_rgb_o    <= rd_data when s1_img = '1' else (others => '0');
         dst_hblank_o <= s1_hblank;
         dst_vblank_o <= s1_vblank;
         dst_hs_o     <= s1_hs;
         dst_vs_o     <= s1_vs;

         -- raster counters
         if frame_done = '1' then
            -- the core just finished a frame in wr_buf: show it, restart the output frame
            rd_buf <= wr_buf;
            out_x  <= 0;
            out_y  <= 0;
         elsif out_x = G_OUT_HTOTAL - 1 then
            out_x <= 0;
            if out_y = G_OUT_VTOTAL - 1 then
               out_y <= 0;
            else
               out_y <= out_y + 1;
            end if;
         else
            out_x <= out_x + 1;
         end if;
      end if;
   end process p_read;

end architecture synthesis;

