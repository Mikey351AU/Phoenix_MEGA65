----------------------------------------------------------------------------------
-- Phoenix for MEGA65
--
-- MEGA65 main file that contains the whole machine (based on the MiSTer2MEGA65 framework)
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out video_mode_type;        -- Defined in video_modes_pkg.vhd
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync  

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- HyperRAM Clock Domain
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic;
   hr_core_read_o          : out std_logic;
   hr_core_address_o       : out std_logic_vector(31 downto 0);
   hr_core_writedata_o     : out std_logic_vector(15 downto 0);
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0);
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0);
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic;  -- Core is too slow

   --------------------------------------------------------------------------------------------------------
   -- Video Clock Domain
   --------------------------------------------------------------------------------------------------------

   video_clk_o             : out std_logic;
   video_rst_o             : out std_logic;
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   clk_i                   : in  std_logic;              -- 100 MHz clock

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- Phoenix's 11 MHz clock
   main_rst_o              : out std_logic;              -- CORE's reset, synchronized

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. power led and drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks and paddles input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;
   main_joy_1_up_n_o       : out std_logic;
   main_joy_1_down_n_o     : out std_logic;
   main_joy_1_left_n_o     : out std_logic;
   main_joy_1_right_n_o    : out std_logic;
   main_joy_1_fire_n_o     : out std_logic;
   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;
   main_joy_2_up_n_o       : out std_logic;
   main_joy_2_down_n_o     : out std_logic;
   main_joy_2_left_n_o     : out std_logic;
   main_joy_2_right_n_o    : out std_logic;
   main_joy_2_fire_n_o     : out std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);
   main_rtc_i              : in  std_logic_vector(64 downto 0);

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out std_logic;
   iec_atn_n_o             : out std_logic;
   iec_clk_en_o            : out std_logic;
   iec_clk_n_i             : in  std_logic;
   iec_clk_n_o             : out std_logic;
   iec_data_en_o           : out std_logic;
   iec_data_n_i            : in  std_logic;
   iec_data_n_o            : out std_logic;
   iec_srq_en_o            : out std_logic;
   iec_srq_n_i             : in  std_logic;
   iec_srq_n_o             : out std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_en_o               : out std_logic;  -- Enable port, active high
   cart_phi2_o             : out std_logic;
   cart_dotclock_o         : out std_logic;
   cart_dma_i              : in  std_logic;
   cart_reset_oe_o         : out std_logic;
   cart_reset_i            : in  std_logic;
   cart_reset_o            : out std_logic;
   cart_game_oe_o          : out std_logic;
   cart_game_i             : in  std_logic;
   cart_game_o             : out std_logic;
   cart_exrom_oe_o         : out std_logic;
   cart_exrom_i            : in  std_logic;
   cart_exrom_o            : out std_logic;
   cart_nmi_oe_o           : out std_logic;
   cart_nmi_i              : in  std_logic;
   cart_nmi_o              : out std_logic;
   cart_irq_oe_o           : out std_logic;
   cart_irq_i              : in  std_logic;
   cart_irq_o              : out std_logic;
   cart_roml_oe_o          : out std_logic;
   cart_roml_i             : in  std_logic;
   cart_roml_o             : out std_logic;
   cart_romh_oe_o          : out std_logic;
   cart_romh_i             : in  std_logic;
   cart_romh_o             : out std_logic;
   cart_ctrl_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_ba_i               : in  std_logic;
   cart_rw_i               : in  std_logic;
   cart_io1_i              : in  std_logic;
   cart_io2_i              : in  std_logic;
   cart_ba_o               : out std_logic;
   cart_rw_o               : out std_logic;
   cart_io1_o              : out std_logic;
   cart_io2_o              : out std_logic;
   cart_addr_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_a_i                : in  unsigned(15 downto 0);
   cart_a_o                : out unsigned(15 downto 0);
   cart_data_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_d_i                : in  unsigned( 7 downto 0);
   cart_d_o                : out unsigned( 7 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk               : std_logic;               -- Phoenix main clock (11 MHz)
signal main_rst               : std_logic;
signal video_clk              : std_logic;               -- Video clock (44 MHz)
signal video_rst              : std_logic;

---------------------------------------------------------------------------------------------
-- Options menu items (0-based line numbers in config.vhd's OPTM_ITEMS)
---------------------------------------------------------------------------------------------

constant C_MENU_ROT_CW        : natural := 5;
constant C_MENU_ROT_CCW       : natural := 6;
constant C_MENU_ROT_OFF       : natural := 7;
constant C_MENU_LIVES_3       : natural := 13;
constant C_MENU_LIVES_4       : natural := 14;
constant C_MENU_LIVES_5       : natural := 15;
constant C_MENU_LIVES_6       : natural := 16;
constant C_MENU_BONUS_3K      : natural := 22;
constant C_MENU_BONUS_4K      : natural := 23;
constant C_MENU_BONUS_5K      : natural := 24;
constant C_MENU_BONUS_6K      : natural := 25;
constant C_MENU_COCKTAIL      : natural := 28;
constant C_MENU_FLIP          : natural := 29;
constant C_MENU_HDMI_16_9_50  : natural := 34;
constant C_MENU_HDMI_16_9_60  : natural := 35;
constant C_MENU_HDMI_4_3_50   : natural := 36;
constant C_MENU_HDMI_5_4_50   : natural := 37;
constant C_MENU_HDMI_640_60   : natural := 38;
constant C_MENU_HDMI_720_5994 : natural := 39;
constant C_MENU_SVGA_800_60   : natural := 40;
constant C_MENU_CRT_EMULATION : natural := 43;
constant C_MENU_HDMI_ZOOM     : natural := 44;
constant C_MENU_IMPROVE_AUDIO : natural := 45;

---------------------------------------------------------------------------------------------
-- main_clk (Phoenix clock domain)
---------------------------------------------------------------------------------------------

signal main_dip_switch        : std_logic_vector(7 downto 0);
signal main_flip_screen       : std_logic;
signal main_rotate            : std_logic;
signal main_rot_ccw           : std_logic;

signal main_dn_addr           : std_logic_vector(15 downto 0);
signal main_dn_data           : std_logic_vector(7 downto 0);
signal main_dn_wr             : std_logic;
signal main_dn_hsk_out        : std_logic_vector(22 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- ROM loader: QNICE writes one byte per address into device C_DEV_PHX_ROM_FIRST + n
type rom_state_t is (ROM_IDLE, ROM_SEND, ROM_RELEASE, ROM_DONE);
signal qnice_rom_state        : rom_state_t := ROM_IDLE;
signal qnice_rom_sel          : std_logic;               -- the current device is one of the Phoenix ROMs
signal qnice_rom_ce           : std_logic;
signal qnice_rom_we           : std_logic;
signal qnice_rom_wait         : std_logic;
signal qnice_rom_send         : std_logic := '0';
signal qnice_rom_rcv          : std_logic;
signal qnice_rom_payload      : std_logic_vector(22 downto 0) := (others => '0');  -- addr(14..0) & data(7..0)

begin

   hr_core_write_o      <= '0';
   hr_core_read_o       <= '0';
   hr_core_address_o    <= (others => '0');
   hr_core_writedata_o  <= (others => '0');
   hr_core_byteenable_o <= (others => '0');
   hr_core_burstcount_o <= (others => '0');

   -- Tristate all expansion port drivers that we can directly control
   cart_ctrl_oe_o       <= '0';
   cart_addr_oe_o       <= '0';
   cart_data_oe_o       <= '0';

   -- Due to a bug in the R5/R6 boards, the cartridge port needs to be enabled for joystick port 2 to work
   cart_en_o            <= '1';

   cart_reset_oe_o      <= '0';
   cart_game_oe_o       <= '0';
   cart_exrom_oe_o      <= '0';
   cart_nmi_oe_o        <= '0';
   cart_irq_oe_o        <= '0';
   cart_roml_oe_o       <= '0';
   cart_romh_oe_o       <= '0';

   -- Default values for all signals
   cart_phi2_o          <= '0';
   cart_reset_o         <= '1';
   cart_dotclock_o      <= '0';
   cart_game_o          <= '1';
   cart_exrom_o         <= '1';
   cart_nmi_o           <= '1';
   cart_irq_o           <= '1';
   cart_roml_o          <= '0';
   cart_romh_o          <= '0';
   cart_ba_o            <= '0';
   cart_rw_o            <= '0';
   cart_io1_o           <= '0';
   cart_io2_o           <= '0';
   cart_a_o             <= (others => '0');
   cart_d_o             <= (others => '0');

   main_joy_1_up_n_o    <= '1';
   main_joy_1_down_n_o  <= '1';
   main_joy_1_left_n_o  <= '1';
   main_joy_1_right_n_o <= '1';
   main_joy_1_fire_n_o  <= '1';
   main_joy_2_up_n_o    <= '1';
   main_joy_2_down_n_o  <= '1';
   main_joy_2_left_n_o  <= '1';
   main_joy_2_right_n_o <= '1';
   main_joy_2_fire_n_o  <= '1';

   -- IEC port is not used
   iec_reset_n_o        <= '1';
   iec_atn_n_o          <= '1';
   iec_clk_en_o         <= '0';
   iec_clk_n_o          <= '1';
   iec_data_en_o        <= '0';
   iec_data_n_o         <= '1';
   iec_srq_en_o         <= '0';
   iec_srq_n_o          <= '1';

   -- MMCME2_ADV clock generator: 11 MHz (Phoenix) and 44 MHz (video)
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => clk_i,           -- expects 100 MHz
         main_clk_o        => main_clk,
         main_rst_o        => main_rst,
         video_clk_o       => video_clk,
         video_rst_o       => video_rst
      ); -- clk_gen

   main_clk_o  <= main_clk;
   main_rst_o  <= main_rst;
   video_clk_o <= video_clk;
   video_rst_o <= video_rst;

   ---------------------------------------------------------------------------------------------
   -- main_clk (Phoenix clock domain)
   ---------------------------------------------------------------------------------------------

   -- MEGA65's power led: By default, it is on and glows green when the MEGA65 is powered on.
   -- We switch it to blue when a long reset is detected and as long as the user keeps pressing the preset button
   main_power_led_o     <= '1';
   main_power_led_col_o <= x"0000FF" when main_reset_m2m_i else x"00FF00";

   -- No drives: drive led stays off
   main_drive_led_o     <= '0';
   main_drive_led_col_o <= x"00FF00";

   -- Dip switches (same mapping as the MiSTer core's Arcade-Phoenix.sv):
   --    bit 7:    cabinet (0 = upright, 1 = cocktail)
   --    bit 6..4: factory, always 0
   --    bit 3..2: bonus life (00 = 3k/30k, 01 = 4k/40k, 10 = 5k/50k, 11 = 6k/60k)
   --    bit 1..0: lives      (00 = 3, 01 = 4, 10 = 5, 11 = 6)
   p_dip : process(main_clk)
      variable lives : std_logic_vector(1 downto 0);
      variable bonus : std_logic_vector(1 downto 0);
   begin
      if rising_edge(main_clk) then
         lives := "00";
         if    main_osm_control_i(C_MENU_LIVES_4) = '1' then lives := "01";
         elsif main_osm_control_i(C_MENU_LIVES_5) = '1' then lives := "10";
         elsif main_osm_control_i(C_MENU_LIVES_6) = '1' then lives := "11";
         end if;

         bonus := "00";
         if    main_osm_control_i(C_MENU_BONUS_4K) = '1' then bonus := "01";
         elsif main_osm_control_i(C_MENU_BONUS_5K) = '1' then bonus := "10";
         elsif main_osm_control_i(C_MENU_BONUS_6K) = '1' then bonus := "11";
         end if;

         main_dip_switch  <= main_osm_control_i(C_MENU_COCKTAIL) & "000" & bonus & lives;
         main_flip_screen <= main_osm_control_i(C_MENU_FLIP);

         -- Screen: rotate CW (default), rotate CCW or no rotation
         main_rotate      <= not main_osm_control_i(C_MENU_ROT_OFF);
         main_rot_ccw     <= main_osm_control_i(C_MENU_ROT_CCW);
      end if;
   end process p_dip;

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i,

         clk_main_speed_i     => CORE_CLK_SPEED,

         dip_switch_i         => main_dip_switch,
         flip_screen_i        => main_flip_screen,
         rotate_i             => main_rotate,
         rot_ccw_i            => main_rot_ccw,

         dn_addr_i            => main_dn_addr,
         dn_data_i            => main_dn_data,
         dn_wr_i              => main_dn_wr,

         -- Video output (video_clk domain)
         clk_video_i          => video_clk,
         video_ce_o           => video_ce_o,
         video_ce_ovl_o       => video_ce_ovl_o,
         video_red_o          => video_red_o,
         video_green_o        => video_green_o,
         video_blue_o         => video_blue_o,
         video_vs_o           => video_vs_o,
         video_hs_o           => video_hs_o,
         video_hblank_o       => video_hblank_o,
         video_vblank_o       => video_vblank_o,

         -- audio output (pcm format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks and paddles/mouse/potentiometers
         joy_1_up_n_i         => main_joy_1_up_n_i,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,

         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i
      ); -- i_main

   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   qnice_video_mode_o <= C_VIDEO_SVGA_800_60   when qnice_osm_control_i(C_MENU_SVGA_800_60)    = '1' else
                         C_VIDEO_HDMI_720_5994 when qnice_osm_control_i(C_MENU_HDMI_720_5994)  = '1' else
                         C_VIDEO_HDMI_640_60   when qnice_osm_control_i(C_MENU_HDMI_640_60)    = '1' else
                         C_VIDEO_HDMI_5_4_50   when qnice_osm_control_i(C_MENU_HDMI_5_4_50)    = '1' else
                         C_VIDEO_HDMI_4_3_50   when qnice_osm_control_i(C_MENU_HDMI_4_3_50)    = '1' else
                         C_VIDEO_HDMI_16_9_50  when qnice_osm_control_i(C_MENU_HDMI_16_9_50)   = '1' else
                         C_VIDEO_HDMI_16_9_60;

   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_scandoubler_o        <= '1';                                         -- VGA output: 31 kHz (15 kHz native is doubled)
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);   -- 0 = raw audio, 1 = use filters from globals.vhd
   qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_ZOOM);       -- 0 = no zoom/crop

   -- Standard VGA (31 kHz) on the analog output
   qnice_retro15kHz_o         <= '0';
   qnice_csync_o              <= '0';
   qnice_osm_cfg_scaling_o    <= (others => '1');

   -- ascal filters: nearest neighbour; polyphase ("CRT emulation") via the menu
   qnice_ascal_mode_o         <= "00";
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports: not needed, Phoenix reads both joysticks
   qnice_flip_joyports_o      <= '0';

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   qnice_rom_sel <= '1' when unsigned(qnice_dev_id_i) >= unsigned(C_DEV_PHX_ROM_FIRST) and
                             unsigned(qnice_dev_id_i) <= unsigned(C_DEV_PHX_ROM_LAST) else '0';

   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o     <= x"EEEE";
      qnice_dev_wait_o     <= '0';
      qnice_rom_ce         <= '0';
      qnice_rom_we         <= '0';

      -- Phoenix ROMs (write only; reads return 0)
      if qnice_rom_sel = '1' then
         qnice_rom_ce      <= qnice_dev_ce_i;
         qnice_rom_we      <= qnice_dev_we_i;
         qnice_dev_data_o  <= x"0000";
         qnice_dev_wait_o  <= qnice_rom_wait;
      end if;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------------
   -- ROM loader: QNICE clock domain -> Phoenix clock domain
   --
   -- Every write of the M2M ROM auto-loader is handed over to the Phoenix clock domain with
   -- an XPM handshake. QNICE is stalled (qnice_dev_wait_o) until the byte has arrived, so
   -- no byte can be lost, independent of the clock ratio.
   --
   -- Device C_DEV_PHX_ROM_FIRST + n, byte offset a (0..2047) -> Phoenix dn_addr = n * 0x800 + a
   -- Writes outside the first 2 kB of 4k-window 0 (e.g. to a CSR window) are ignored.
   ---------------------------------------------------------------------------------------------

   p_rom_loader : process(qnice_clk_i)
   begin
      if rising_edge(qnice_clk_i) then
         case qnice_rom_state is
            when ROM_IDLE =>
               if qnice_rom_ce = '1' and qnice_rom_we = '1' then
                  if qnice_dev_addr_i(27 downto 11) = "00000000000000000" then
                     qnice_rom_payload <= qnice_dev_id_i(3 downto 0) & qnice_dev_addr_i(10 downto 0) &
                                          qnice_dev_data_i(7 downto 0);
                     qnice_rom_send    <= '1';
                     qnice_rom_state   <= ROM_SEND;
                  else
                     qnice_rom_state   <= ROM_DONE;     -- ignore, but complete the bus cycle
                  end if;
               end if;

            when ROM_SEND =>
               if qnice_rom_rcv = '1' then
                  qnice_rom_send  <= '0';
                  qnice_rom_state <= ROM_RELEASE;
               end if;

            when ROM_RELEASE =>
               if qnice_rom_rcv = '0' then
                  qnice_rom_state <= ROM_DONE;
               end if;

            when ROM_DONE =>
               -- wait until QNICE ends the bus cycle
               if not (qnice_rom_ce = '1' and qnice_rom_we = '1') then
                  qnice_rom_state <= ROM_IDLE;
               end if;
         end case;

         if qnice_rst_i = '1' then
            qnice_rom_state <= ROM_IDLE;
            qnice_rom_send  <= '0';
         end if;
      end if;
   end process p_rom_loader;

   -- stall QNICE for the whole duration of a write, except when the transfer is done
   qnice_rom_wait <= '1' when qnice_rom_ce = '1' and qnice_rom_we = '1' and qnice_rom_state /= ROM_DONE else '0';

   i_rom_cdc : xpm_cdc_handshake
      generic map (
         DEST_EXT_HSK   => 0,        -- internal handshake: dest_req is a one clock pulse
         DEST_SYNC_FF   => 3,
         SRC_SYNC_FF    => 3,
         WIDTH          => 23
      )
      port map (
         src_clk        => qnice_clk_i,
         src_in         => qnice_rom_payload,
         src_send       => qnice_rom_send,
         src_rcv        => qnice_rom_rcv,
         dest_clk       => main_clk,
         dest_req       => main_dn_wr,
         dest_ack       => '0',
         dest_out       => main_dn_hsk_out
      ); -- i_rom_cdc

   main_dn_addr <= "0" & main_dn_hsk_out(22 downto 8);
   main_dn_data <= main_dn_hsk_out(7 downto 0);

end architecture synthesis;

