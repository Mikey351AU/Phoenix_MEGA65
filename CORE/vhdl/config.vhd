----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Configuration data for the Shell
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   clk_i       : in std_logic;

   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);

   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end entity config;

architecture beh of config is

--------------------------------------------------------------------------------------------------------------------
-- String and character constants (specific for the Anikki-16x16 font)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant CHR_LINE_1  : character := character'val(196);
constant CHR_LINE_5  : string := CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1;
constant CHR_LINE_10 : string := CHR_LINE_5 & CHR_LINE_5;
constant CHR_LINE_50 : string := CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10;

--------------------------------------------------------------------------------------------------------------------
-- Welcome and Help Screens (Selectors 0x1000 .. 0x1FFF)
--------------------------------------------------------------------------------------------------------------------


-- define the amount of WHS array elements: between 1 and 16
constant WHS_RECORDS   : natural := 2;

-- define the maximum amount of pages per WHS array element: between 1 and 256
-- (this is necessary because Vivado does not support unconstrained arrays in a record)
constant WHS_MAX_PAGES : natural := 2;

 -- !!! DO NOT TOUCH !!!
constant SEL_WHS           : std_logic_vector(15 downto 0) := x"1000";
type WHS_INDEX_TYPE is array (0 to WHS_MAX_PAGES - 1) of natural;
type WHS_RECORD_TYPE is record
   page_count  : natural;
   page_start  : WHS_INDEX_TYPE;
   page_length : WHS_INDEX_TYPE;
end record;
type WHS_RECORD_ARRAY_TYPE is array (0 to WHS_RECORDS - 1) of WHS_RECORD_TYPE;

-- START YOUR CONFIGURATION BELOW THIS LINE

-- IMPORTANT: Phoenix's OSM resolution is 352 x 416 pixels (VGA_DX/VGA_DY in globals.vhd), so that the
-- OSM fits into the VGA picture both in rotated (356 x 478) and in native (478 x 416) mode. This means
-- the on-screen-menu has 22 x 26 characters. Minus the frame, every line can have at most
-- 20 characters and every screen at most 24 lines.

constant SCR_WELCOME : string :=

   " Phoenix for MEGA65\n" &
   " Version 0.2\n\n" &

   " MiSTer core by Dar\n" &
   " and Sorgelig\n\n" &

   -- We are not insisting. But it would be nice if you gave us credit for MiSTer2MEGA65 by leaving these lines in
   " Powered by\n" &
   " MiSTer2MEGA65 by\n" &
   " sy2002 and MJoergen\n\n" &

   " Crsr L/R  Move\n" &
   " Space     Fire\n" &
   " Crsr Up   Shield\n" &
   " 5         Coin\n" &
   " 1 / 2     Start\n" &
   " Help      Menu\n\n" &

   " Joystick 1 or 2:\n" &
   " Up = Shield\n\n" &

   " Press Space\n";

constant HELP_1 : string :=

   "\n Phoenix V0.2\n\n" &

   " ROMs: unzip the\n" &
   " MAME set 'phoenix'\n" &
   " to the SD card:\n" &
   " /arcade/phoenix/\n\n" &

   " Screen: Phoenix is\n" &
   " a vertical game.\n" &
   " Rotate CW or CCW is\n" &
   " for normal screens,\n" &
   " No rotation is for\n" &
   " a rotated monitor.\n\n" &

   " Crsr right: next\n" &
   " Space: close";

constant HELP_2 : string :=

   "\n Dip switches\n\n" &

   " Lives: ships/game\n" &
   " Bonus: score for\n" &
   " 1st/2nd extra ship\n" &
   " Cocktail: flips the\n" &
   " screen for player 2\n\n" &

   " Changes to the dip\n" &
   " switches need a\n" &
   " reset.\n\n\n" &

   " Crsr left: back\n" &
   " Space: close";

-- Concatenate all your Welcome and Help screens into one large string, so that during synthesis one large string ROM can be build.
constant WHS_DATA : string := SCR_WELCOME & HELP_1 & HELP_2;

constant SCR_WELCOME_START : natural := 0;
constant HELP_1_START      : natural := SCR_WELCOME'length;
constant HELP_2_START      : natural := HELP_1_START + HELP_1'length;

-- Fill the WHS array with page start addresses and the length of each page.
-- Make sure that array element 0 is always your Welcome page. If you don't use a welcome page, fill everything with zeros.
constant WHS : WHS_RECORD_ARRAY_TYPE := (
   --- Welcome Screen
   (page_count    => 1,
    page_start    => (SCR_WELCOME_START,  0),
    page_length   => (SCR_WELCOME'length, 0)),

   --- Help pages
   (page_count    => 2,
    page_start    => (HELP_1_START,  HELP_2_START),
    page_length   => (HELP_1'length, HELP_2'length))
);

--------------------------------------------------------------------------------------------------------------------
-- Set start folder for file browser and specify config file for menu persistence (Selectors 0x0100 and 0x0101)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_DIR_START     : std_logic_vector(15 downto 0) := x"0100";
constant SEL_CFG_FILE      : std_logic_vector(15 downto 0) := x"0101";

-- START YOUR CONFIGURATION BELOW THIS LINE

constant DIR_START         : string := "/arcade/phoenix";
constant CFG_FILE          : string := "/arcade/phoenix/phxcfg";

--------------------------------------------------------------------------------------------------------------------
-- General configuration settings: Reset, Pause, OSD behavior, Ascal, etc. (Selector 0x0110)
--------------------------------------------------------------------------------------------------------------------

constant SEL_GENERAL       : std_logic_vector(15 downto 0) := x"0110";  -- !!! DO NOT TOUCH !!!

-- START YOUR CONFIGURATION BELOW THIS LINE

-- at a minimum, keep the reset line active for this amount of "QNICE loops" (see gencfg.asm).
-- "0" means: deactivate this feature
constant RESET_COUNTER     : natural := 100;

-- put the core in PAUSE state if any OSD opens (MiSTer default for Phoenix: "Pause when OSD is open: On")
constant OPTM_PAUSE        : boolean := true;

-- show the welcome screen in general
constant WELCOME_ACTIVE    : boolean := true;

-- shall the welcome screen also be shown after the core is reset?
-- (only relevant if WELCOME_ACTIVE is true)
constant WELCOME_AT_RESET  : boolean := false;

-- keyboard and joystick connection during reset and OSD
constant KEYBOARD_AT_RESET : boolean := false;
constant JOY_1_AT_RESET    : boolean := false;
constant JOY_2_AT_RESET    : boolean := false;

constant KEYBOARD_AT_OSD   : boolean := false;
constant JOY_1_AT_OSD      : boolean := false;
constant JOY_2_AT_OSD      : boolean := false;

-- Avalon Scaler settings (see ascal.vhd, used for HDMI output only)
constant ASCAL_USAGE       : natural := 2;
constant ASCAL_MODE        : natural := 0;   -- see ascal.vhd for the meaning of this value

-- Save on-screen-display settings if the file specified by CFG_FILE exists and if it has
-- the length of OPTM_SIZE bytes. If the first byte of the file has the value 0xFF then it
-- is considered as "default", i.e. the menu items specified by OPTM_G_STDSEL are selected.
-- If the file does not exists, then settings are not saved and OPTM_G_STDSEL always denotes the standard settings.
constant SAVE_SETTINGS     : boolean := true;

-- Virtual drives are not used by Phoenix, but the framework still reads these constants
constant VD_ANTI_THRASHING_DELAY : natural := 2000;
constant VD_ITERATION_SIZE       : natural := 100;

--------------------------------------------------------------------------------------------------------------------
-- Name and version of the core  (Selector 0x0200)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_CORENAME      : std_logic_vector(15 downto 0) := x"0200";

-- START YOUR CONFIGURATION BELOW THIS LINE

-- Currently this is only used in the debug console. Use the welcome screen and the
-- help system to display the name and version of your core to the end user
constant CORENAME          : string := "PHOENIX FOR MEGA65 V0.2";

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu  (Selectors 0x0300 .. 0x0312): DO NOT TOUCH
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!! Selectors for accessing the menu configuration data
constant SEL_OPTM_ITEMS       : std_logic_vector(15 downto 0) := x"0300";
constant SEL_OPTM_GROUPS      : std_logic_vector(15 downto 0) := x"0301";
constant SEL_OPTM_STDSEL      : std_logic_vector(15 downto 0) := x"0302";
constant SEL_OPTM_LINES       : std_logic_vector(15 downto 0) := x"0303";
constant SEL_OPTM_START       : std_logic_vector(15 downto 0) := x"0304";
constant SEL_OPTM_ICOUNT      : std_logic_vector(15 downto 0) := x"0305";
constant SEL_OPTM_MOUNT_DRV   : std_logic_vector(15 downto 0) := x"0306";
constant SEL_OPTM_SINGLESEL   : std_logic_vector(15 downto 0) := x"0307";
constant SEL_OPTM_MOUNT_STR   : std_logic_vector(15 downto 0) := x"0308";
constant SEL_OPTM_DIMENSIONS  : std_logic_vector(15 downto 0) := x"0309";
constant SEL_OPTM_SAVING_STR  : std_logic_vector(15 downto 0) := x"030A";
constant SEL_OPTM_HELP        : std_logic_vector(15 downto 0) := x"0310";
constant SEL_OPTM_CRTROM      : std_logic_vector(15 downto 0) := x"0311";
constant SEL_OPTM_CRTROM_STR  : std_logic_vector(15 downto 0) := x"0312";

-- !!! DO NOT TOUCH !!! Configuration constants for OPTM_GROUPS (shell.asm and menu.asm expect them to be like this)
constant OPTM_G_TEXT       : integer := 16#00000#;         -- text that cannot be selected
constant OPTM_G_CLOSE      : integer := 16#000FF#;        -- menu items that closes menu
constant OPTM_G_STDSEL     : integer := 16#00100#;        -- item within a group that is selected by default
constant OPTM_G_LINE       : integer := 16#00200#;        -- draw a line at this position
constant OPTM_G_START      : integer := 16#00400#;        -- selector / cursor position after startup (only use once!)
                                                          -- 16#00800# is used in OPTM_G_MOUNT_DRV (OPTM_G_SINGLESEL)
constant OPTM_G_HEADLINE   : integer := 16#01000#;        -- like OPTM_G_TEXT but will be shown in a brigher color
                                                          -- 16#02000# is used in OPTM_G_HELP (plus OPTM_G_SINGLESEL)
                                                          -- 16#04000# is used in OPTM_G_SUBMENU
constant OPTM_G_SINGLESEL  : integer := 16#08000#;        -- single select item
constant OPTM_G_MOUNT_DRV  : integer := 16#08800#;        -- line item means: mount drive; first occurance = drive 0, second = drive 1, ...
constant OPTM_G_HELP       : integer := 16#0A000#;        -- line item means: help screen; first occurance = WHS(1), second = WHS(2), ...
constant OPTM_G_SUBMENU    : integer := 16#0C000#;        -- starts/ends a section that is treated as submenu
constant OPTM_G_LOAD_ROM   : integer := 16#18000#;        -- line item means: load ROM; first occurance = rom 0, second = rom 1, ...

constant OPTM_GTC          : natural := 17;                -- Amount of significant bits in OPTM_G_* constants

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu: START YOUR CONFIGURATION BELOW THIS LINE
--------------------------------------------------------------------------------------------------------------------

-- Strings with which %s will be replaced in case the menu item is of type OPTM_G_MOUNT_DRV
constant OPTM_S_MOUNT      : string := "<Mount>";
constant OPTM_S_CRTROM     : string := "<Load>";
constant OPTM_S_SAVING     : string := "<Saving>";

-- Size of menu and menu items
-- CAUTION: 1. End each line (also the last one) with a \n and make sure empty lines / separator lines are only consisting of a "\n"
--             Do use a lower case \n. If you forget one of them or if you use upper case, you will run into undefined behavior.
--          2. Start each line that contains an actual menu item (multi- or single-select) with a Space character,
--             otherwise you will experience visual glitches.
--
-- IMPORTANT: The menu item positions (0-based line numbers) are used as C_MENU_* constants in mega65.vhd.
--            If you change this menu, update mega65.vhd accordingly.
constant OPTM_SIZE         : natural := 50;  -- amount of items including empty lines:
                                             -- needs to be equal to the number of lines in OPTM_ITEMS and amount of items in OPTM_GROUPS
                                             -- IMPORTANT: If SAVE_SETTINGS is true and OPTM_SIZE changes: Make sure to re-generate and
                                             -- and re-distribute the config file. You can make a new one using M2M/tools/make_config.sh

-- Net size of the Options menu on the screen in characters (excluding the frame, which is hardcoded to two characters)
-- Without submenus: Use OPTM_SIZE as height, otherwise count how large the actually visible main menu is.
-- Phoenix's OSM is 22 x 26 characters, so OPTM_DX <= 20 and OPTM_DY <= 24
constant OPTM_DX           : natural := 20;
constant OPTM_DY           : natural := 16;

constant OPTM_ITEMS        : string :=

   " Phoenix\n"               &    --  0
   "\n"                       &    --  1

   " Screen: %s\n"            &    --  2  Screen rotation submenu
   " Screen\n"                &    --  3
   "\n"                       &    --  4
   " Rotate CW\n"             &    --  5
   " Rotate CCW\n"            &    --  6
   " No rotation\n"           &    --  7
   "\n"                       &    --  8
   " Back\n"                  &    --  9

   " Lives: %s\n"             &    -- 10  Lives submenu
   " Lives\n"                 &    -- 11
   "\n"                       &    -- 12
   " 3\n"                     &    -- 13
   " 4\n"                     &    -- 14
   " 5\n"                     &    -- 15
   " 6\n"                     &    -- 16
   "\n"                       &    -- 17
   " Back\n"                  &    -- 18

   " Bonus: %s\n"             &    -- 19  Bonus submenu
   " Bonus life\n"            &    -- 20
   "\n"                       &    -- 21
   " 3k / 30k\n"              &    -- 22
   " 4k / 40k\n"              &    -- 23
   " 5k / 50k\n"              &    -- 24
   " 6k / 60k\n"              &    -- 25
   "\n"                       &    -- 26
   " Back\n"                  &    -- 27

   " Cocktail cabinet\n"      &    -- 28
   " Flip screen\n"           &    -- 29
   "\n"                       &    -- 30

   " HDMI: %s\n"              &    -- 31  HDMI submenu
   " HDMI mode\n"             &    -- 32
   "\n"                       &    -- 33
   " 720p 50 Hz\n"           &    -- 34
   " 720p 60 Hz\n"           &    -- 35
   " 576p 4:3\n"             &    -- 36
   " 576p 5:4\n"             &    -- 37
   " 640x480\n"              &    -- 38
   " 720x480\n"              &    -- 39
   " 800x600\n"              &    -- 40
   "\n"                       &    -- 41
   " Back\n"                  &    -- 42

   " HDMI: CRT emulation\n"   &    -- 43
   " HDMI: Zoom-in\n"         &    -- 44
   " Audio improvements\n"    &    -- 45
   "\n"                       &    -- 46
   " About & Help\n"          &    -- 47
   "\n"                       &    -- 48
   " Close Menu\n";                -- 49

-- Group ids: must start with 1 and be monotonic increasing
constant OPTM_G_Rotate     : integer := 1;
constant OPTM_G_Lives      : integer := 2;
constant OPTM_G_Bonus      : integer := 3;
constant OPTM_G_Cocktail   : integer := 4;
constant OPTM_G_Flip       : integer := 5;
constant OPTM_G_HDMI       : integer := 6;
constant OPTM_G_CRT        : integer := 7;
constant OPTM_G_Zoom       : integer := 8;
constant OPTM_G_Audio      : integer := 9;
constant OPTM_G_About      : integer := 10;

-- !!! DO NOT TOUCH !!!
type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 2**OPTM_GTC- 1;

constant OPTM_GROUPS       : OPTM_GTYPE := ( OPTM_G_TEXT + OPTM_G_HEADLINE,            --  0 Headline "Phoenix"
                                             OPTM_G_LINE,                              --  1 Line

                                             OPTM_G_SUBMENU + OPTM_G_START,            --  2 Screen submenu START; cursor start
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  3 Headline
                                             OPTM_G_LINE,                              --  4 Line
                                             OPTM_G_Rotate + OPTM_G_STDSEL,            --  5 Rotate CW (default)
                                             OPTM_G_Rotate,                            --  6 Rotate CCW
                                             OPTM_G_Rotate,                            --  7 No rotation
                                             OPTM_G_LINE,                              --  8 Line
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  9 Back / Screen submenu END

                                             OPTM_G_SUBMENU,                           -- 10 Lives submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 11 Headline
                                             OPTM_G_LINE,                              -- 12 Line
                                             OPTM_G_Lives + OPTM_G_STDSEL,             -- 13 3 lives (default)
                                             OPTM_G_Lives,                             -- 14 4 lives
                                             OPTM_G_Lives,                             -- 15 5 lives
                                             OPTM_G_Lives,                             -- 16 6 lives
                                             OPTM_G_LINE,                              -- 17 Line
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 18 Back / Lives submenu END

                                             OPTM_G_SUBMENU,                           -- 19 Bonus submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 20 Headline
                                             OPTM_G_LINE,                              -- 21 Line
                                             OPTM_G_Bonus + OPTM_G_STDSEL,             -- 22 3k/30k (default)
                                             OPTM_G_Bonus,                             -- 23 4k/40k
                                             OPTM_G_Bonus,                             -- 24 5k/50k
                                             OPTM_G_Bonus,                             -- 25 6k/60k
                                             OPTM_G_LINE,                              -- 26 Line
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 27 Back / Bonus submenu END

                                             OPTM_G_Cocktail + OPTM_G_SINGLESEL,       -- 28 Cocktail cabinet (off by default)
                                             OPTM_G_Flip     + OPTM_G_SINGLESEL,       -- 29 Flip screen (off by default)
                                             OPTM_G_LINE,                              -- 30 Line

                                             OPTM_G_SUBMENU,                           -- 31 HDMI submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 32 Headline
                                             OPTM_G_LINE,                              -- 33 Line
                                             OPTM_G_HDMI,                              -- 34 720p 50 Hz 16:9
                                             OPTM_G_HDMI + OPTM_G_STDSEL,              -- 35 720p 60 Hz 16:9 (default: Phoenix runs at ~60 Hz)
                                             OPTM_G_HDMI,                              -- 36 576p 50 Hz 4:3
                                             OPTM_G_HDMI,                              -- 37 576p 50 Hz 5:4
                                             OPTM_G_HDMI,                              -- 38 640x480 60 Hz
                                             OPTM_G_HDMI,                              -- 39 720x480 59.94 Hz
                                             OPTM_G_HDMI,                              -- 40 800x600 60 Hz
                                             OPTM_G_LINE,                              -- 41 Line
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 42 Back / HDMI submenu END

                                             OPTM_G_CRT     + OPTM_G_SINGLESEL,        -- 43 HDMI: CRT emulation
                                             OPTM_G_Zoom    + OPTM_G_SINGLESEL,        -- 44 HDMI: Zoom-in
                                             OPTM_G_Audio   + OPTM_G_SINGLESEL,        -- 45 Audio improvements
                                             OPTM_G_LINE,                              -- 46 Line
                                             OPTM_G_About   + OPTM_G_HELP,             -- 47 About & Help -> WHS(1)
                                             OPTM_G_LINE,                              -- 48 Line
                                             OPTM_G_CLOSE                              -- 49 Close Menu
                                           );

--------------------------------------------------------------------------------------------------------------------
-- !!! CAUTION: M2M FRAMEWORK CODE !!! DO NOT TOUCH ANYTHING BELOW THIS LINE !!!
--------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------
-- Address Decoding
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(clk_i)
   -- return ASCII value of given string at the position defined by index (zero-based)
   pure function str2data(str : string; index : integer) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := index + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return X"0000"; -- zero terminated strings
      end if;
   end function str2data;

   -- return the dimensions of the Options menu
   pure function getDXDY(dx, dy, index: natural) return std_logic_vector is
   begin
      case index is
         when 0 => return std_logic_vector(to_unsigned(dx + 2, 16));
         when 1 => return std_logic_vector(to_unsigned(dy + 2, 16));
         when others => return X"0000";
      end case;
   end function getDXDY;

   -- convert bool to std_logic_vector
   pure function bool2slv(b: boolean) return std_logic_vector is
   begin
      if b then
         return x"0001";
      else
         return x"0000";
      end if;
   end function bool2slv;

   -- return the General Configuration settings
   function getGenConf(index: natural) return std_logic_vector is
   begin
      case index is
         when 1      => return std_logic_vector(to_unsigned(RESET_COUNTER, 16));
         when 2      => return bool2slv(OPTM_PAUSE);
         when 3      => return bool2slv(WELCOME_ACTIVE);
         when 4      => return bool2slv(WELCOME_AT_RESET);
         when 5      => return bool2slv(KEYBOARD_AT_RESET);
         when 6      => return bool2slv(JOY_1_AT_RESET);
         when 7      => return bool2slv(JOY_2_AT_RESET);
         when 8      => return bool2slv(KEYBOARD_AT_OSD);
         when 9      => return bool2slv(JOY_1_AT_OSD);
         when 10     => return bool2slv(JOY_2_AT_OSD);
         when 11     => return std_logic_vector(to_unsigned(ASCAL_USAGE, 16));
         when 12     => return std_logic_vector(to_unsigned(ASCAL_MODE, 16));
         when 13     => return std_logic_vector(to_unsigned(VD_ANTI_THRASHING_DELAY, 16));
         when 14     => return std_logic_vector(to_unsigned(VD_ITERATION_SIZE, 16));
         when 15     => return bool2slv(SAVE_SETTINGS);
         when others => return x"0000";
      end case;
   end function getGenConf;

   variable index           : integer;
   variable whs_page_index  : integer;
   variable whs_array_index : integer;

begin

   if falling_edge(clk_i) then

      index := to_integer(unsigned(address_i(11 downto 0)));
      whs_page_index  := to_integer(unsigned(address_i(19 downto 12)));
      whs_array_index := to_integer(unsigned(address_i(23 downto 20)));

      data_o <= x"EEEE";

      -----------------------------------------------------------------------------------
      -- Welcome & Help System: upper 4 bits of address equal SEL_WHS' upper 4 bits
      -----------------------------------------------------------------------------------

      if address_i(27 downto 24) = SEL_WHS(15 downto 12) then

         if  whs_array_index < WHS_RECORDS then
            if index = 4095 then
               data_o <= std_logic_vector(to_unsigned(WHS(whs_array_index).page_count, 16));
            else
               if index < WHS(whs_array_index).page_length(whs_page_index) then
                  data_o <= str2data(WHS_DATA, WHS(whs_array_index).page_start(whs_page_index) + index);
               else
                  data_o <= (others => '0'); -- zero-terminated strings
               end if;
            end if;
         end if;

      -----------------------------------------------------------------------------------
      -- All other selectors, which are 16-bit values
      -----------------------------------------------------------------------------------

      else

         case address_i(27 downto 12) is
            when SEL_GENERAL           => data_o <= getGenConf(index);
            when SEL_DIR_START         => data_o <= str2data(DIR_START, index);
            when SEL_CFG_FILE          => data_o <= str2data(CFG_FILE, index);
            when SEL_CORENAME          => data_o <= str2data(CORENAME, index);
            when SEL_OPTM_ITEMS        => data_o <= str2data(OPTM_ITEMS, index);
            when SEL_OPTM_MOUNT_STR    => data_o <= str2data(OPTM_S_MOUNT, index);
            when SEL_OPTM_CRTROM_STR   => data_o <= str2data(OPTM_S_CRTROM, index);
            when SEL_OPTM_SAVING_STR   => data_o <= str2data(OPTM_S_SAVING, index);
            when SEL_OPTM_GROUPS       => data_o <= std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15)) &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(14)) & "0" &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(12)) & "0000" &
                                                    std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(7 downto 0));
            when SEL_OPTM_STDSEL       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(8));
            when SEL_OPTM_LINES        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(9));
            when SEL_OPTM_START        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(10));
            when SEL_OPTM_MOUNT_DRV    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(11));
            when SEL_OPTM_HELP         => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(13));
            when SEL_OPTM_SINGLESEL    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15));
            when SEL_OPTM_CRTROM       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(16));
            when SEL_OPTM_ICOUNT       => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_SIZE, 8));
            when SEL_OPTM_DIMENSIONS   => data_o <= getDXDY(OPTM_DX, OPTM_DY, index);

            when others                => null;
         end case;
      end if;
   end if;
end process;

end architecture beh;

