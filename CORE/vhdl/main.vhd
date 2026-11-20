----------------------------------------------------------------------------------
-- Phoenix for MEGA65
--
-- Wrapper for the MiSTer Phoenix core (Arcade-Phoenix_MiSTer by Dar / Sorgelig)
--
-- The Phoenix core runs on clk_main_i (11 MHz). The video output is re-sampled
-- into the clk_video_i domain (44 MHz, phase aligned to clk_main_i because both
-- come from the same MMCM), just like the MiSTer core does with clk_44.
--
-- Based on the MiSTer2MEGA65 framework (sy2002 and MJoergen), licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;              -- 11 MHz
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Game settings (clk_main_i domain)
      dip_switch_i            : in  std_logic_vector(7 downto 0);
      flip_screen_i           : in  std_logic;
      rotate_i                : in  std_logic;              -- 1 = rotate the screen (vertical game on a normal monitor)
      rot_ccw_i               : in  std_logic;              -- 0 = 90 degrees clockwise, 1 = counter-clockwise

      -- ROM download interface (clk_main_i domain), see mega65.vhd
      dn_addr_i               : in  std_logic_vector(15 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;

      -- Video output (clk_video_i domain)
      clk_video_i             : in  std_logic;              -- 44 MHz
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

-- keyboard
signal key_left            : std_logic;
signal key_right           : std_logic;
signal key_fire            : std_logic;
signal key_barrier         : std_logic;
signal key_start1          : std_logic;
signal key_start2          : std_logic;
signal key_coin            : std_logic;

-- combined controls (high active)
signal btn_left            : std_logic;
signal btn_right           : std_logic;
signal btn_fire            : std_logic;
signal btn_barrier         : std_logic;

-- reset handling: keep the core in reset while ROMs are being downloaded
signal dn_busy_cnt         : unsigned(15 downto 0) := (others => '1');
signal core_reset          : std_logic;

-- Phoenix video output (clk_main_i domain)
signal phx_ce_pix          : std_logic;
signal phx_r               : std_logic_vector(1 downto 0);
signal phx_g               : std_logic_vector(1 downto 0);
signal phx_b               : std_logic_vector(1 downto 0);
signal phx_hs              : std_logic;
signal phx_vs              : std_logic;
signal phx_hblank          : std_logic;
signal phx_vblank          : std_logic;
signal phx_audio           : std_logic_vector(11 downto 0);

-- rotated video (clk_main_i domain)
signal rot_rgb             : std_logic_vector(5 downto 0);
signal rot_hs              : std_logic;
signal rot_vs              : std_logic;
signal rot_hblank          : std_logic;
signal rot_vblank          : std_logic;

-- selected video stream (native or rotated), one pixel per clk_main_i
signal sel_rgb             : std_logic_vector(5 downto 0) := (others => '0');
signal sel_sync            : std_logic_vector(3 downto 0) := (others => '0');
signal sel_tgl             : std_logic := '0';

-- clk_video_i domain
signal v_tgl_d1            : std_logic := '0';
signal v_tgl_d2            : std_logic := '0';
signal v_tgl_d3            : std_logic := '0';
signal v_rgb_d1            : std_logic_vector(5 downto 0);
signal v_rgb_d2            : std_logic_vector(5 downto 0);
signal v_sync_d1           : std_logic_vector(3 downto 0);
signal v_sync_d2           : std_logic_vector(3 downto 0);
signal v_ce                : std_logic;
signal v_ovl_cnt           : unsigned(1 downto 0) := (others => '0');

begin

   ---------------------------------------------------------------------------------------------
   -- Controls: keyboard OR joystick port 1 OR joystick port 2 (like the MiSTer core)
   ---------------------------------------------------------------------------------------------

   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,
         key_left_o           => key_left,
         key_right_o          => key_right,
         key_fire_o           => key_fire,
         key_barrier_o        => key_barrier,
         key_start1_o         => key_start1,
         key_start2_o         => key_start2,
         key_coin_o           => key_coin
      ); -- i_keyboard

   -- Joystick: left/right move, fire = fire, up = barrier (shield)
   btn_left    <= key_left    or not joy_1_left_n_i  or not joy_2_left_n_i;
   btn_right   <= key_right   or not joy_1_right_n_i or not joy_2_right_n_i;
   btn_fire    <= key_fire    or not joy_1_fire_n_i  or not joy_2_fire_n_i;
   btn_barrier <= key_barrier or not joy_1_up_n_i    or not joy_2_up_n_i;

   ---------------------------------------------------------------------------------------------
   -- Reset: M2M resets plus "ROM download in progress" (MiSTer does the same during download)
   ---------------------------------------------------------------------------------------------

   p_dn_busy : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if dn_wr_i = '1' then
            dn_busy_cnt <= (others => '1');           -- ~6 ms at 11 MHz after the last byte
         elsif dn_busy_cnt /= 0 then
            dn_busy_cnt <= dn_busy_cnt - 1;
         end if;
      end if;
   end process p_dn_busy;

   core_reset <= '1' when reset_soft_i = '1' or reset_hard_i = '1' or dn_busy_cnt /= 0 else '0';

   ---------------------------------------------------------------------------------------------
   -- The Phoenix core
   ---------------------------------------------------------------------------------------------

   i_phoenix : entity work.phoenix
      port map (
         clk               => clk_main_i,
         reset             => core_reset,
         pause             => pause_i,
         ce_pix            => phx_ce_pix,

         dn_addr           => dn_addr_i,
         dn_data           => dn_data_i,
         dn_wr             => dn_wr_i,

         dip_switch        => dip_switch_i,
         flip_screen       => flip_screen_i,

         btn_coin          => key_coin,
         btn_player_start  => key_start2 & key_start1,
         btn_fire          => btn_fire,
         btn_left          => btn_left,
         btn_right         => btn_right,
         btn_barrier       => btn_barrier,

         video_r           => phx_r,
         video_g           => phx_g,
         video_b           => phx_b,
         video_vblank      => phx_vblank,
         video_hblank_bg   => phx_hblank,
         video_hblank_fg   => open,
         video_hs          => phx_hs,
         video_vs          => phx_vs,

         sound_fire        => open,
         sound_explode     => open,
         sound_burn        => open,
         sound_fireball    => open,
         sound_ab          => open,
         audio_select      => "000",
         audio             => phx_audio,

         -- hiscore interface is not used on the MEGA65 (yet)
         hs_address        => (others => '0'),
         hs_data_out       => open,
         hs_data_in        => (others => '0'),
         hs_write          => '0'
      ); -- i_phoenix

   -- Audio: Phoenix outputs 12-bit unsigned; M2M expects 16-bit signed (invert MSB = subtract 0x8000)
   audio_left_o  <= signed((not phx_audio(11)) & phx_audio(10 downto 0) & "0000");
   audio_right_o <= signed((not phx_audio(11)) & phx_audio(10 downto 0) & "0000");

   ---------------------------------------------------------------------------------------------
   -- Video stream at 11 MHz (one pixel per clk_main_i), like the MiSTer core's arcade_video
   --
   -- Native:  Phoenix's own 5.5 MHz output is sampled at 11 MHz, i.e. every pixel is shown
   --          twice: 478 x 208 visible (478 x 416 after the scandoubler).
   -- Rotated: rotate.vhd produces a frame locked 704 x 262 raster with a 356 x 239 visible
   --          4:3 box that contains the rotated 208 x 239 image (356 x 478 after scandoubler).
   ---------------------------------------------------------------------------------------------

   i_rotate : entity work.rotate
      port map (
         clk_i          => clk_main_i,
         rot_ccw_i      => rot_ccw_i,
         src_ce_i       => phx_ce_pix,
         src_rgb_i      => phx_r & phx_g & phx_b,
         src_hblank_i   => phx_hblank,
         src_vblank_i   => phx_vblank,
         dst_rgb_o      => rot_rgb,
         dst_hs_o       => rot_hs,
         dst_vs_o       => rot_vs,
         dst_hblank_o   => rot_hblank,
         dst_vblank_o   => rot_vblank
      ); -- i_rotate

   p_select : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if rotate_i = '1' then
            sel_rgb  <= rot_rgb;
            sel_sync <= rot_hs & rot_vs & rot_hblank & rot_vblank;
         else
            sel_rgb  <= phx_r & phx_g & phx_b;
            sel_sync <= phx_hs & phx_vs & phx_hblank & phx_vblank;
         end if;
         sel_tgl <= not sel_tgl;                      -- a new pixel every clk_main_i
      end if;
   end process p_select;

   ---------------------------------------------------------------------------------------------
   -- Transfer into the 44 MHz video clock domain
   --
   -- sel_tgl flips on every clk_main_i edge, together with the pixel registers. In the video
   -- clock domain a change of the toggle means "a new pixel is valid". Both clocks come from
   -- the same MMCM (44 = 4 * 11 MHz), so this is a synchronous transfer; the extra register
   -- stages just keep timing easy.
   --
   --    video_ce_o     : 11 MHz  (every 4th video clock)
   --    video_ce_ovl_o : 22 MHz  (every 2nd video clock), the post-scandoubler pixel clock
   ---------------------------------------------------------------------------------------------

   p_video : process(clk_video_i)
   begin
      if rising_edge(clk_video_i) then
         -- stage 1: sample everything at the same time
         v_tgl_d1  <= sel_tgl;
         v_rgb_d1  <= sel_rgb;
         v_sync_d1 <= sel_sync;

         -- stage 2/3: detect the toggle edge one stage later, so stage 2 data is stable
         v_tgl_d2  <= v_tgl_d1;
         v_tgl_d3  <= v_tgl_d2;
         v_rgb_d2  <= v_rgb_d1;
         v_sync_d2 <= v_sync_d1;

         video_ce_o     <= '0';
         video_ce_ovl_o <= '0';
         v_ovl_cnt      <= v_ovl_cnt + 1;

         if v_ce = '1' then
            video_ce_o     <= '1';
            video_ce_ovl_o <= '1';
            v_ovl_cnt      <= "00";

            -- 2-bit per channel to 8-bit per channel by bit replication
            video_red_o    <= v_rgb_d2(5 downto 4) & v_rgb_d2(5 downto 4) & v_rgb_d2(5 downto 4) & v_rgb_d2(5 downto 4);
            video_green_o  <= v_rgb_d2(3 downto 2) & v_rgb_d2(3 downto 2) & v_rgb_d2(3 downto 2) & v_rgb_d2(3 downto 2);
            video_blue_o   <= v_rgb_d2(1 downto 0) & v_rgb_d2(1 downto 0) & v_rgb_d2(1 downto 0) & v_rgb_d2(1 downto 0);
            video_hs_o     <= v_sync_d2(3);
            video_vs_o     <= v_sync_d2(2);
            video_hblank_o <= v_sync_d2(1);
            video_vblank_o <= v_sync_d2(0);
         elsif v_ovl_cnt = "01" then
            -- one pixel period is 4 video clocks: second overlay pulse 2 clocks after the first one
            video_ce_ovl_o <= '1';
         end if;
      end if;
   end process p_video;

   v_ce <= v_tgl_d2 xor v_tgl_d3;

end architecture synthesis;
