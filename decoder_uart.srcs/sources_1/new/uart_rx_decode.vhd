-- ============================================================================
--     uart_rx_decode                                                     
--     FSM decoding the sampled serial stream                              
-- ============================================================================
--  Author   : Chris C.              2026-11-07
-- VHDL-2008
-- ----------------------------------------------------------------------------

package cust_type_pkg is
	-- FSM States
	type state is (				
		IDLE,
		START,
		DATA,
		PARITY,
		STOP
	);
	-- Custom types for limiting parity and oversampling
	type parity_t is (		
		ODD,
		EVEN,
		MARK,
		SPACE,
		NONE
	);
	
	type oversample_t is (
	   x16,
	   x8
	);
end package cust_type_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cust_type_pkg.ALL;


entity uart_rx_decode is
	Generic (
		Stop_b_g 		: natural := 1;
		flow_ctrl_g		: boolean := false;
		oversampling_g	: oversample_t := x16;
		data_bits_g		: integer := 8;
		parity_g		: parity_t := ODD
	);
	Port (
		rx_serial_p : in STD_LOGIC;
		clk_rx_p  	: in STD_LOGIC;				-- x8 or x16 of baud rate
		rst_n_p	  	: in STD_LOGIC := '1';
		ready_p	  	: in STD_LOGIC;
		valid_p	  	: out STD_LOGIC := '0';		-- Keeps HIGH until next frame is detected
		data_rx_p 	: out STD_LOGIC_VECTOR (data_bits_g -1 downto 0) := (others => '0');
		-- frame_err_p and parity_err_p communicate errors in the received frame.  
		-- data_rx_p is communicated independently of the error signals
		frame_err_p	: out BOOLEAN := FALSE;		-- Active if the stop bit is not HIGH at sampling point
		parity_err_p: out BOOLEAN := FALSE		-- Both flags get cleared once a new frame is detected
	);
end entity uart_rx_decode;

architecture RTL of uart_rx_decode is
	signal rx_state_s    	: state := IDLE;
	signal buffer_s			: STD_LOGIC_VECTOR (data_bits_g -1 downto 0) := (others => '0');
	signal st_detected_s 	: BOOLEAN := FALSE;
																				  
	signal half_bit_s		: BOOLEAN := FALSE;
	signal full_bit_s		: BOOLEAN := FALSE;
	signal bits_in_frame_s : natural := 0;

						 
	function verify_parity (frame2check_v: STD_LOGIC_VECTOR(data_bits_g -1 downto 0); parity_bit_v: STD_LOGIC) return BOOLEAN is
										 
								   
	variable calc_parity_v : STD_LOGIC := '0';
	begin
		case parity_g is
			when ODD =>
				for i in frame2check_v'range loop
					calc_parity_v := frame2check_v(i) xor calc_parity_v;
				end loop;
				if (calc_parity_v = NOT parity_bit_v) then
					return TRUE;
				end if;
			when EVEN =>
				for i in frame2check_v'range loop
					calc_parity_v := frame2check_v(i) xor calc_parity_v;
				end loop;
				if (calc_parity_v = parity_bit_v) then
					return TRUE;
				end if;				
			when MARK =>
				if (parity_bit_v='1')then
					return TRUE;
				end if;
			when SPACE =>
				if (parity_bit_v='0')then
					return TRUE;
				end if;
			when NONE =>
				return TRUE;
		end case;
		return FALSE;
	end function verify_parity;
	
begin
	FSM: process(clk_rx_p, rst_n_p)
	begin
		if (rst_n_p = '0') then
			valid_p		<= '0';
			rx_state_s	<= IDLE;
			buffer_s	<= (others => '0');
			data_rx_p 	<= (others => '0');
			frame_err_p 	<= FALSE;
			parity_err_p	<= FALSE;
			st_detected_s 	<= FALSE;
								
		elsif (rising_edge(clk_rx_p)) then
			case rx_state_s is
				when IDLE =>
					if (falling_edge(rx_serial_p)) then
						-- When start is detected, previous frame signals are cleared		
						valid_p <= '0';
						buffer_s	<= (others => '0');
						data_rx_p 	<= (others => '0');
						frame_err_p <= FALSE;
						parity_err_p <= FALSE;
						st_detected_s <= TRUE;
						rx_state_s <= START;
					end if;
				when START =>
					if (rx_serial_p = '1' AND half_bit_s = TRUE)then
						-- Start condition didnt hold at sampling point
						rx_state_s <= IDLE;
						st_detected_s <= FALSE;
					elsif (full_bit_s = TRUE) then
							rx_state_s <= DATA;
					end if;
				when DATA =>
					if (half_bit_s = TRUE AND bits_in_frame_s <= data_bits_g+1) then
						buffer_s(bits_in_frame_s - 1) <= rx_serial_p;
					end if;
					if (bits_in_frame_s = data_bits_g+1 AND full_bit_s = TRUE) then
						-- End of last data bit
						if (parity_g = NONE)then
							rx_state_s <= STOP;
						else
							rx_state_s <= PARITY;
			  
						end if;
					end if;
				when PARITY =>
					if (half_bit_s = TRUE) then
						  
						if (not verify_parity(buffer_s, rx_serial_p))then
							parity_err_p <= TRUE;
						end if;
					end if;
					if (full_bit_s = TRUE) then
						rx_state_s <= STOP;
					end if;
				when STOP =>
					if (half_bit_s = TRUE) then
						valid_p <= '1';
						data_rx_p <= buffer_s;
						if (rx_serial_p = '0')then
							frame_err_p <= TRUE;
						end if;
					end if;
					if (full_bit_s = TRUE) then
						rx_state_s <= IDLE when ready_p = '1' else STOP;	-- Hold FSM until sink is ready to receive data
						st_detected_s <= FALSE;		-- Set to false so halfbit process stops counting until next frame is detected
					end if;
			end case;
		end if;
	end process FSM;
	-- halfbit process counts the number of oversampling clock cycles and generates a half_bit and full_bit signal to be used by the FSM
	halfbit: process (clk_rx_p, rst_n_p) 
	variable count_v : natural := 0;
	begin
		if (rst_n_p = '0') then
			count_v		:= 0;
			bits_in_frame_s	<= 0;
			half_bit_s	<= FALSE;
			full_bit_s <= FALSE;
		elsif(st_detected_s = TRUE AND rising_edge(clk_rx_p)) then
			count_v := count_v + 1;
			case oversampling_g is
				when x8 =>
					if (count_v = 4) then
						half_bit_s <= TRUE;
					elsif (count_v = 8) then
						count_v := 0;
						bits_in_frame_s <= bits_in_frame_s + 1;
						full_bit_s <= TRUE;
					else
						half_bit_s <= FALSE;
						full_bit_s <= FALSE;
					end if;
				when x16 =>
					if (count_v = 8) then
						half_bit_s <= TRUE;
					elsif (count_v = 16) then
						count_v := 0;
						bits_in_frame_s <= bits_in_frame_s + 1;
						full_bit_s <= TRUE;
					else
						half_bit_s <= FALSE;
						full_bit_s <= FALSE;
					end if;					
			end case;
			if (rx_state_s = STOP AND full_bit_s = TRUE) then
				bits_in_frame_s <= 0;
			end if;
		end if;
	end process halfbit;
	
end architecture RTL;
