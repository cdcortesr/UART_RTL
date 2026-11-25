----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/22/2026 05:37:24 PM
-- Design Name: 
-- Module Name: uart_clk_gen - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------




package oversample_pkg is
    type oversample_t is (x8, x16);
	function to_real(o : oversample_t) return real;
end package oversample_pkg;

package body oversample_pkg is
	function to_real(o : oversample_t) return real is
    begin
        case o is
            when X8  => return 8.0;
            when X16 => return 16.0;
        end case;
    end function;
end package body oversample_pkg;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.oversample_pkg.ALL;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- UART baud rate and minimum clock frequency for x16 oversampling
--
-- Baud Rate (bps)  | Minimum Clock Frequency
-- -----------------|-------------------------
-- 9600             | 153.6 kHz
-- 19200            | 307.2 kHz
-- 38400            | 614.4 kHz
-- 57600            | 921.6 kHz
-- 115200           | 1.8432 MHz
--
-- Formula: F_CLK_MIN = BAUD_RATE * 16


entity uart_clk_gen is
    generic (
        BAUD_RATE	: integer := 115_200;		-- Target baud rate
        MASTER_CLOCK: integer := 36_000_000;	-- System clock frequency: 36Mhz
		OVERSAMPLE	: oversample_t := x16		-- x16 rx ticks per bit
    );
    Port (
		in_clk 	: in STD_LOGIC;
		rst_n	: in STD_LOGIC := '1';
		tx_tick : out STD_LOGIC:= '0';
		rx_tick : out STD_LOGIC:= '0'			-- Two clocks are generated one for tx and one for rx SMs
		);			
end uart_clk_gen; 

architecture Behavioral of uart_clk_gen is
	
	-- Numerically Controlled Oscillator 
	constant ratio_tx : real := real(MASTER_CLOCK)/real(BAUD_RATE);	
	constant ratio_rx : real := ratio_tx/to_real(OVERSAMPLE);
	-- Increment word for 32 bit buffer
    constant phase_inc_tx : unsigned(31 downto 0) := to_unsigned(integer((2.0**32)/ratio_tx),32);
	constant phase_inc_rx : unsigned(31 downto 0) := to_unsigned(integer((2.0**32)/ratio_rx),32);
	-- Accumulator buffer
    signal phase_acc_tx : unsigned(31 downto 0):= (others => '0');                     
    signal phase_acc_rx : unsigned(31 downto 0):= (others => '0');
	
begin
	
	process
	begin
		report "ratio rx = " & real'image(ratio_rx) & "ratio tx = " & real'image(ratio_tx);
		report "phase_inc_tx = " & integer'image(to_integer(phase_inc_tx));
		report "phase_inc_rx = " & integer'image(to_integer(phase_inc_rx));
		wait;
	end process;	
	-- tx_tick
	process (in_clk, rst_n)
    begin
		if rst_n='0' then
			tx_tick <= '0';
			phase_acc_tx <= (others => '0');
		else
			if (rising_edge(in_clk)) then
				if(phase_acc_tx > phase_acc_tx + phase_inc_tx)then
					tx_tick <= '1';
				end if;
				phase_acc_tx <= phase_acc_tx + phase_inc_tx;
			end if;
			if falling_edge(in_clk) then
				tx_tick <= '0';
			end if;
		end if;
    end process; 
	-- rx_tick
	process (in_clk)
    begin
		if rst_n='0' then
			rx_tick <= '0';
			phase_acc_rx <= (others => '0');
		else
			if (rising_edge(in_clk)) then
				if(phase_acc_rx > phase_acc_rx + phase_inc_rx)then
					rx_tick <= '1';
				end if;
				phase_acc_rx <= phase_acc_rx + phase_inc_rx;
			end if;
			if falling_edge(in_clk) then
				rx_tick <= '0';
			end if;
		end if;
    end process; 

end Behavioral;
