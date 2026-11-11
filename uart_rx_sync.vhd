----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/22/2026 05:37:24 PM
-- Design Name: 
-- Module Name: uart_rx_sync - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rx_sync is
    Port ( uart_rx : 	in STD_LOGIC;
           uart_rx_db : out STD_LOGIC := '0';	--Debounced signal
           clk : 		in STD_LOGIC;
		   rst_n :		in STD_LOGIC
		   );
end uart_rx_sync;

architecture Behavioral of uart_rx_sync is
signal ff1 : std_logic := '0';
begin
    process (clk)
    begin
		if (rst_n='0') then
			ff1 <= '0';
			uart_rx_db <= '0';
		else
			ff1 <= uart_rx;
			uart_rx_db <= ff1;
		end if;
    end process;

end Behavioral;
