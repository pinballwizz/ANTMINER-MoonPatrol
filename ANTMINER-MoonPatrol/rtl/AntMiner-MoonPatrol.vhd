---------------------------------------------------------------------------------
--                        Moon Patrol - AntMiner S9
--                              Code from MISTER
--
--                         Modified for AntMiner S9 
--                            by pinballwiz.org 
--                               23/06/2026
---------------------------------------------------------------------------------
-- Keyboard inputs :
--   5 : Add coin
--   2 : Start 2 players
--   1 : Start 1 player
--   LEFT Ctrl   : Fire
--   UP arrow    : Jump
--   RIGHT arrow : Fast
--   LEFT arrow  : Slow
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;
---------------------------------------------------------------------------------
entity mpatrol_antminer is
port(
	clock_50    : in std_logic;
   	I_RESET     : in std_logic;
	O_VIDEO_R	: out std_logic_vector(2 downto 0); 
	O_VIDEO_G	: out std_logic_vector(2 downto 0);
	O_VIDEO_B	: out std_logic_vector(1 downto 0);
	O_HSYNC		: out std_logic;
	O_VSYNC		: out std_logic;
	O_AUDIO_L 	: out std_logic;
	O_AUDIO_R 	: out std_logic;
   	ps2_clk     : in std_logic;
	ps2_dat     : inout std_logic;
	led         : out std_logic_vector(7 downto 0);
	aled        : out std_logic_vector(3 downto 0);
	joy         : in std_logic_vector(7 downto 0);
	dipsw       : in std_logic_vector(7 downto 0)
 );
end mpatrol_antminer;
------------------------------------------------------------------------------
architecture struct of mpatrol_antminer is

 signal clock_36        : std_logic;
 signal clock_24        : std_logic;
 signal clock_18        : std_logic;
 signal clock_12        : std_logic;
 signal clock_9         : std_logic;
 signal clock_7         : std_logic;
 signal clock_6         : std_logic;
 signal clock_3p58      : std_logic;
 --
 signal reset           : std_logic;
 signal pll_lock        : std_logic;
 --
 signal kbd_intr        : std_logic;
 signal kbd_scancode    : std_logic_vector(7 downto 0);
 signal joy_BBBBFRLDU   : std_logic_vector(9 downto 0);
 --
 signal IN0             : std_logic_vector(7 downto 0);
 signal IN1             : std_logic_vector(7 downto 0);
 signal IN2             : std_logic_vector(7 downto 0);
 --
 constant CLOCK_FREQ    : integer := 27E6;
 signal counter_clk     : std_logic_vector(25 downto 0);
 signal clock_4hz       : std_logic;
 signal AD              : std_logic_vector(15 downto 0);
 ---------------------------------------------------------------------------
component mpatrol_clocks
port(
  clk_out1          : out    std_logic;
  clk_out2          : out    std_logic;
  clk_out3          : out    std_logic;
  locked            : out    std_logic;
  clk_in1           : in     std_logic
 );
end component;
----------------------------------------------------------------------------
begin

reset <= not I_RESET;
aled(3 downto 0) <= "1111"; -- turn unused onboard leds off
----------------------------------------------------------------------------
Clocks: mpatrol_clocks
    port map (
        clk_in1   => clock_50,
        clk_out1  => clock_36,
        clk_out2  => clock_24,
	    clk_out3  => clock_7,
	    locked    => pll_lock	
    );
----------------------------------------------------------------------------
-- Clocks Divide

process (clock_36)
begin
 if rising_edge(clock_36) then
  clock_18  <= not clock_18;
 end if;
end process;
--
process (clock_24)
begin
 if rising_edge(clock_24) then
  clock_12  <= not clock_12;
 end if;
end process;
--
process (clock_12)
begin
 if rising_edge(clock_12) then
  clock_6  <= not clock_6;
 end if;
end process;
--
process (clock_18)
begin
 if rising_edge(clock_18) then
  clock_9  <= not clock_9;
 end if;
end process;
--
process (clock_7)
begin
 if rising_edge(clock_7) then
  clock_3p58  <= not clock_3p58;
 end if;
end process;
---------------------------------------------------------------------------
-- Inputs

IN0 <= "1111" & not joy_BBBBFRLDU(7) & '1' & not joy_BBBBFRLDU(6) & not joy_BBBBFRLDU(5);
IN1 <= not joy_BBBBFRLDU(4) & '1' & not joy_BBBBFRLDU(0) & "111" & not joy_BBBBFRLDU(2) & not joy_BBBBFRLDU(3);
IN2 <= not joy_BBBBFRLDU(4) & '1' & not joy_BBBBFRLDU(0) & "111" & not joy_BBBBFRLDU(2) & not joy_BBBBFRLDU(3);
---------------------------------------------------------------------------
-- Main

mpatrol : entity work.mpatrol_top
  port map (
 clk_sys    => clock_36,
 clk_vid    => clock_6,
 clock_24   => clock_24,
 clk_aud    => clock_3p58,
 clock_12   => clock_12,
 reset      => reset,
 O_VIDEO_R  => O_VIDEO_R,
 O_VIDEO_G  => O_VIDEO_G,
 O_VIDEO_B  => O_VIDEO_B,
 O_HSYNC    => O_HSYNC,
 O_VSYNC    => O_VSYNC,
 audio_l    => O_AUDIO_L,
 audio_r    => O_AUDIO_R,
 IN0        => IN0,
 IN1        => IN1,
 IN2        => IN2,
 AD         => AD
 );
------------------------------------------------------------------------------
-- get scancode from keyboard

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_9,
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);
------------------------------------------------------------------------------
-- translate scancode to joystick

joystick : entity work.kbd_joystick
port map (
  clk         => clock_9,
  kbdint      => kbd_intr,
  kbdscancode => std_logic_vector(kbd_scancode), 
  joy_BBBBFRLDU  => joy_BBBBFRLDU 
);
------------------------------------------------------------------------------
-- debug

process(reset, clock_24)
begin
  if reset = '1' then
   clock_4hz <= '0';
   counter_clk <= (others => '0');
  else
    if rising_edge(clock_24) then
      if counter_clk = CLOCK_FREQ/8 then
        counter_clk <= (others => '0');
        clock_4hz <= not clock_4hz;
        led(7 downto 0) <= not AD(14 downto 7);
      else
        counter_clk <= counter_clk + 1;
      end if;
    end if;
  end if;
end process;
------------------------------------------------------------------------------
end struct;