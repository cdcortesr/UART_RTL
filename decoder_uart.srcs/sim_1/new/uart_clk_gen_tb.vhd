library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.oversample_pkg.ALL;

entity uart_clk_gen_tb is
end entity;

architecture sim of uart_clk_gen_tb is
    constant CLK_FREQ_HZ : positive := 5_500_000;
    constant BAUD_RATE   : positive := 115_200;
    constant OVERSAMPLE  : oversample_t := x16;
    constant CLK_PERIOD  : time     := 1 sec / CLK_FREQ_HZ;

    signal in_clk  : std_logic := '0';
    signal rst_n     : std_logic := '1';
    signal tx_tick : std_logic;
    signal rx_tick : std_logic;
    signal done    : boolean   := false;
    signal rx_cnt  : natural   := 0;
begin

    -- device under test
    uut : entity work.uart_clk_gen
        generic map (
			MASTER_CLOCK=> CLK_FREQ_HZ,
			BAUD_RATE   => BAUD_RATE,
			OVERSAMPLE  => OVERSAMPLE)
        port map (
			in_clk	=> in_clk,
			rst_n	=> rst_n,
			tx_tick => tx_tick, 
			rx_tick => rx_tick
			);

    -- clock: stops when the test is done so the simulation ends by itself
    clk_gen : process
    begin
        while not done 
		loop
            in_clk <= '0'; wait for CLK_PERIOD / 2;
            in_clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- count rx ticks
    rx_counter : process (rx_tick)
    begin
        if rising_edge(rx_tick) then
            rx_cnt <= rx_cnt + 1;
        end if;
    end process;

    -- stimulus and checks
    stim : process
        constant N_BITS : positive := 1000;
        variable t_start, t_end : time;
        variable cnt_start      : natural;
        variable measured_baud  : real;
        variable rx_per_bit     : real;
    begin
        rst_n <= '0';
        wait for 10 * CLK_PERIOD;
        wait until rising_edge(in_clk);
        rst_n <= '1';
		-- First tx tick
        wait until rising_edge(tx_tick);         
        t_start   := now;
        cnt_start := rx_cnt;
		-- Check final values after an amount of N_BITS are ticked in tx channel
        for i in 1 to N_BITS loop				
            wait until rising_edge(tx_tick);
        end loop;
        t_end := now;

        -- divide by 1 ns, not 1 ps: time/time returns an integer, and
        -- 1000 bits is ~8.7e9 ps, which would overflow a 32-bit integer
        measured_baud := real(N_BITS) /
                         (real((t_end - t_start) / 1 ns) * 1.0e-9);
        rx_per_bit    := real(rx_cnt - cnt_start) / real(N_BITS);

        report "measured baud = " & real'image(measured_baud) & " rx ticks/bit = " & real'image(rx_per_bit);

        if (abs(measured_baud - real(BAUD_RATE)) / real(BAUD_RATE) < 0.001) then
			report "baud rate error below 0.1 %";
		else
			report "baud rate error above 0.1 %" severity error;
		end if;

        if (abs(rx_per_bit - to_real(OVERSAMPLE)) < 0.05) then
			report "oversampling error less than 5%";
		else
			report "oversampling error greater than 5%"	severity error;
		end if;
        report "testbench finished";
        done <= true;
        wait;
    end process;

end architecture;