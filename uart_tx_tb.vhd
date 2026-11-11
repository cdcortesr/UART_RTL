-- ============================================================================
--     uart_tx_tb                                                     
--                                                             
-- ============================================================================
--  Engineer  : Chris C.              2026-11-08
-- ----------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture Sim of uart_tx_tb is
    constant BAUD_RATE : positive := 115_200;
    constant CLK_PERIOD  : time     := 1 sec / BAUD_RATE;

    signal clk_tx_s     : std_logic := '0';
    signal rst_n_s      : std_logic := '0';
    signal ready_s      : std_logic := '0';
    signal data_tx_s    : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_s      : std_logic := '0';
    signal tx_serial_s  : std_logic;

begin
    uut : entity work.uart_tx1
        generic map (
            stop_bits_g => 1,
            flow_ctrl_g => 0,
            data_bits_g => 8,
            parity_g    => "ODD"
        )
        port map (
            clk_tx_p   => clk_tx_s,
            rst_n_p      => rst_n_s,
            ready_p    => ready_s,
            data_tx_p  => data_tx_s,
            valid_p    => valid_s,
            tx_serial_p=> tx_serial_s
        );

    tb: process
        variable i : integer := 0;
    begin
        wait for 100 ns;
        rst_n_s <= '1';
        wait for 100 ns;
        for i in 0 to 255 loop
            data_tx_s <= std_logic_vector(to_unsigned(i, 8));
            valid_s <= '1';
            wait until rising_edge(ready_s);
            valid_s <= '0';
            wait until rising_edge(clk_tx_s);
        end loop;

        wait;
    end process;

    proc_clk_tx: process
    begin
        while true loop
            clk_tx_s <= '0'; wait for CLK_PERIOD / 2;
            clk_tx_s <= '1'; wait for CLK_PERIOD / 2;
        end loop;
    end process;

end Sim;
