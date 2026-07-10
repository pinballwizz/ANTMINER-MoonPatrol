library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
--------------------------------------------------------------------------------
library work;
use work.pace_pkg.all;
use work.video_controller_pkg.all;
use work.project_pkg.all;
use work.platform_pkg.all;
use work.target_pkg.all;
---------------------------------------------------------------------------------
entity mpatrol_top is
	port(
		clk_sys		: in std_logic; -- 36
		clk_vid		: in std_logic; -- 6
		clk_aud	    : in std_logic; -- 3.58/4
		clock_12    : in std_logic;
		clock_24    : in std_logic;
		reset		: in std_logic;
		O_VIDEO_R   : out std_logic_vector(2 downto 0);
		O_VIDEO_G	: out std_logic_vector(2 downto 0);
		O_VIDEO_B	: out std_logic_vector(1 downto 0);
		O_HSYNC		: out std_logic;
		O_VSYNC		: out std_logic;
		audio_l		: out std_logic;
		audio_r		: out std_logic;
		IN0			: in std_logic_vector(7 downto 0);
		IN1			: in std_logic_vector(7 downto 0);
		IN2			: in std_logic_vector(7 downto 0);
        AD          : out std_logic_vector(15 downto 0)
);
end mpatrol_top;
--------------------------------------------------------------------------------
architecture SYN of mpatrol_top is
	signal init       		: std_logic := '1';  
	signal clkrst_i			: from_CLKRST_t;
	signal buttons_i		: from_BUTTONS_t;
	signal switches_i		: from_SWITCHES_t;
	signal leds_o			: to_LEDS_t;
	signal inputs_i			: from_INPUTS_t;
	signal video_i			: from_VIDEO_t;
	signal video_o			: to_VIDEO_t;
	signal project_i		: from_PROJECT_IO_t;
	signal project_o		: to_PROJECT_IO_t;
	signal platform_i		: from_PLATFORM_IO_t;
	signal platform_o		: to_PLATFORM_IO_t;
	signal target_i			: from_TARGET_IO_t;
	signal target_o			: to_TARGET_IO_t;
    --
	signal sound_data		: std_logic_vector(7 downto 0);
	signal rst_audD       	: std_logic;
	signal rst_aud        	: std_logic;
    signal AUDIO		    : std_logic_vector(12 downto 0);
    signal AudioPWM         : std_logic;
    --
    signal DIP1		        : std_logic_vector(7 downto 0);
    signal DIP2		        : std_logic_vector(7 downto 0);
    --
    signal HBLANK		    : std_logic;
    signal VBLANK		    : std_logic;
    --
    signal video_r       	: std_logic_vector(5 downto 0);
    signal video_g 	    	: std_logic_vector(5 downto 0);
    signal video_b 	        : std_logic_vector(5 downto 0);
    signal video_r_x2       : std_logic_vector(5 downto 0);
    signal video_g_x2       : std_logic_vector(5 downto 0);
    signal video_b_x2       : std_logic_vector(5 downto 0);
    signal hsync_x2         : std_logic;
    signal vsync_x2         : std_logic;
-----------------------------------------------------------------------------
begin

DIP1 <= "11111110"; -- ({4'b1111, ~status[6], ~status[5], ~status[12], ~status[11]}),
DIP2 <= "11111011"; -- ({1'b1, ~status[13], 3'b111, ~status[14], 1'b1, 1'b1}),//cheat, nu, nu, nu, coinmode, cab, flip 

--      DIP1  <= "11111110";  -- 1C/1C, 10/30/50K, 3 lives
--      DIP2   01xxxxxx = cheat on // 11xxxxxx = cheat off

------------------------------------------------------------------------------
	clkrst_i.clk(0) <= clk_sys;
	clkrst_i.clk(1) <= clk_vid;

--	clkrst_i.arst <= reset;
--	clkrst_i.arst_n <= not clkrst_i.arst;
  
	process (clk_sys)
		variable count : std_logic_vector (11 downto 0) := (others => '0');
	begin
		if rising_edge(clk_sys) then
			if count = X"FFF" then
				init <= '0';
			else
				count := count + 1;
				init <= '1';
			end if;
		end if;
	end process;

	process (clk_sys) begin
		if rising_edge(clk_sys) then
			clkrst_i.arst    <= init or reset;
			clkrst_i.arst_n  <= not clkrst_i.arst;
		end if;
	end process;

	process (clk_aud) begin
		if rising_edge(clk_aud) then
			rst_audD <= clkrst_i.arst;
			rst_aud  <= rst_audD;
		end if;
	end process;

  GEN_RESETS : for i in 0 to 3 generate

    process (clkrst_i)
      variable rst_r : std_logic_vector(2 downto 0) := (others => '0');
    begin
      if clkrst_i.arst = '1' then
        rst_r := (others => '1');
      elsif rising_edge(clkrst_i.clk(i)) then
        rst_r := rst_r(rst_r'left-1 downto 0) & '0';
      end if;
      clkrst_i.rst(i) <= rst_r(rst_r'left);
    end process;

  end generate GEN_RESETS;


	video_i.clk <= clkrst_i.clk(1);	-- by convention
	video_i.clk_ena <= '1';
	video_i.reset <= clkrst_i.rst(1);
--------------------------------------------------------------------------
pace_inst : entity work.pace                                            
	port map (
		clkrst_i			=> clkrst_i,
		palmode				=> '1',
		buttons_i			=> buttons_i,
		switches_i			=> (others => '1'),
		IN0        			=> IN0,
		IN1        			=> IN1,
		IN2        			=> IN2,
		DIP1        		=> DIP1,
		DIP2        		=> DIP2,
		leds_o				=> open,
		inputs_i			=> inputs_i,
		video_i				=> video_i,
		video_o				=> video_o,
		sound_data_o		=> sound_data,
        AD                  => AD
);
---------------------------------------------------------------------------  
  HBLANK <= video_o.hblank;
  VBLANK <= video_o.vblank;
  --
  video_r <= video_o.rgb.r(9 downto 6) & "00" when HBLANK = '0' and VBLANK = '0' else "000000";
  video_g <= video_o.rgb.g(9 downto 6) & "00" when HBLANK = '0' and VBLANK = '0' else "000000";
  video_b <= video_o.rgb.b(9 downto 6) & "00" when HBLANK = '0' and VBLANK = '0' else "000000";
---------------------------------------------------------------------------
  u_dblscan : entity work.scandoubler
    port map (
		clk_sys     => clock_24,
		r_in        => video_r,
		g_in        => video_g,
		b_in        => video_b,
		hs_in       => video_o.hsync,
		vs_in       => video_o.vsync,
		r_out       => video_r_x2,
		g_out       => video_g_x2,
		b_out       => video_b_x2,
		hs_out      => hsync_x2,
		vs_out      => vsync_x2,
		scanlines   => "00"
	);
-------------------------------------------------------------------------
-- to output

	O_VIDEO_R 	<= video_r_x2(5 downto 3);
	O_VIDEO_G 	<= video_g_x2(5 downto 3);
	O_VIDEO_B 	<= video_b_x2(5 downto 4);
	O_HSYNC		<= hsync_x2;
	O_VSYNC		<= vsync_x2;
-------------------------------------------------------------------------
moon_patrol_sound_board : entity work.moon_patrol_sound_board
	port map(
		clock_3p58   		=> clk_aud,
		reset        		=> rst_aud,
		select_sound 		=> sound_data,		
		audio_out    		=> AUDIO
);
------------------------------------------------------------------------- 
--dac

  u_dac : entity work.dac
	generic map(
	  msbi_g => 12
	)
	port  map(
	  clk_i   => clock_12,
	  res_n_i => '1',
	  dac_i   => AUDIO,
	  dac_o   => AudioPWM
	);

  audio_l <= AudioPWM;
  audio_r <= AudioPWM;
------------------------------------------------------------------------ 		
end SYN;