----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/22/2026 05:37:24 PM
-- Design Name: 
-- Module Name: uart_fifo_rx - Behavioral
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

entity uart_fifo_rx is
    Port ( fifo_rx_in : in STD_LOGIC_VECTOR (7 downto 0);
           fifo_rx_out : out STD_LOGIC_VECTOR (7 downto 0);
           nEmpty : out STD_LOGIC);
end uart_fifo_rx;

architecture Behavioral of uart_fifo_rx is

begin


end Behavioral;
