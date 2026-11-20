----------------------------------------------------------------------------------
-- Phoenix for MEGA65
--
-- Xilinx/Vivado drop-in replacement for the MiSTer core's rtl/dpram.vhd, which
-- uses Intel's altsyncram. Same entity name, generics and ports, so the
-- Phoenix sources do not need to change. Infers a true dual port block RAM with
-- registered address and unregistered output (1 clock read latency), which is
-- what the altsyncram configuration ("UNREGISTERED" outdata) was doing.
--
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram is
   generic (
      addr_width_g : integer := 8;
      data_width_g : integer := 8
   );
   port (
      address_a   : in  std_logic_vector(addr_width_g-1 downto 0);
      address_b   : in  std_logic_vector(addr_width_g-1 downto 0);
      clock_a     : in  std_logic := '1';
      clock_b     : in  std_logic;
      data_a      : in  std_logic_vector(data_width_g-1 downto 0);
      data_b      : in  std_logic_vector(data_width_g-1 downto 0) := (others => '0');
      enable_a    : in  std_logic := '1';
      enable_b    : in  std_logic := '1';
      wren_a      : in  std_logic := '0';
      wren_b      : in  std_logic := '0';
      q_a         : out std_logic_vector(data_width_g-1 downto 0);
      q_b         : out std_logic_vector(data_width_g-1 downto 0)
   );
end entity dpram;

architecture rtl of dpram is

   type ram_t is array (0 to 2**addr_width_g-1) of std_logic_vector(data_width_g-1 downto 0);
   shared variable ram : ram_t := (others => (others => '0'));

   attribute ram_style : string;
   attribute ram_style of ram : variable is "block";

begin

   port_a : process(clock_a)
   begin
      if rising_edge(clock_a) then
         if enable_a = '1' then
            if wren_a = '1' then
               ram(to_integer(unsigned(address_a))) := data_a;
            end if;
            q_a <= ram(to_integer(unsigned(address_a)));    -- write-first (= NEW_DATA)
         end if;
      end if;
   end process port_a;

   port_b : process(clock_b)
   begin
      if rising_edge(clock_b) then
         if enable_b = '1' then
            if wren_b = '1' then
               ram(to_integer(unsigned(address_b))) := data_b;
            end if;
            q_b <= ram(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process port_b;

end architecture rtl;

