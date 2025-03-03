library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.NoCPackage.all;

entity Thor_buffer is
generic(
    select_protection : integer range 0 to 3);
port(
    clock:      in  std_logic;
    reset:      in  std_logic;
    clock_rx:   in  std_logic;
    rx:         in  std_logic;
    data_in:    in  regflit;
    credit_o:   out std_logic;
    h:          out std_logic;
    ack_h:      in  std_logic;
    data_av:    out std_logic;
    data:       out regflit;
    data_ack:   in  std_logic;
    sender:     out std_logic);
end Thor_buffer;

architecture Thor_buffer of Thor_buffer is

type fila_out is (REQ_ROUTING, SEND_DATA);
signal next_state, current_state : fila_out;

signal pull: std_logic;
signal bufferHead : regflit;
signal has_data: std_logic;
signal has_data_and_sending : std_logic;
signal counter : integer;

signal sending : std_logic;
signal sent : std_logic;

begin

    HammingGenerate: if(select_protection = 1) generate
        hamming_buffer: entity work.fifo_buffer(hamming_buffer)
        generic map(
				BUFFER_DEPTH => TAM_BUFFER ,
                BUFFER_WIDTH => regflit'length)
        port map(
            reset =>     reset,
            clock =>     clock_rx,
            tail =>      data_in,
            push =>      rx,
            pull =>      pull,
            counter =>   counter,
            head =>      bufferHead
    );
    end generate HammingGenerate ;
	
	matrixGenerate: if(select_protection = 2) generate
        matrix_buffer: entity work.fifo_buffer(matrix_buffer)
        generic map(BUFFER_DEPTH => TAM_BUFFER ,
                BUFFER_WIDTH => regflit'length)
        port map(
            reset =>     reset,
            clock =>     clock_rx,
            tail =>      data_in,
            push =>      rx,
            pull =>      pull,
            counter =>   counter,
            head =>      bufferHead
    );
    end generate matrixGenerate ;
	
	clcGenerate: if(select_protection = 3) generate
        matrix_buffer: entity work.fifo_buffer(clc_buffer)
        generic map(BUFFER_DEPTH => TAM_BUFFER ,
                BUFFER_WIDTH => regflit'length)
        port map(
            reset =>     reset,
            clock =>     clock_rx,
            tail =>      data_in,
            push =>      rx,
            pull =>      pull,
            counter =>   counter,
            head =>      bufferHead
    );
    end generate clcGenerate ;
	
	ThorGenerate: if(select_protection = 0) generate
		thorbuffer : entity work.fifo_buffer_real
        generic map(BUFFER_DEPTH => TAM_BUFFER ,
                BUFFER_WIDTH => regflit'length)
        port map(
            reset =>     reset,
            clock =>     clock_rx,
            tail =>      data_in,
            push =>      rx,
            pull =>      pull,
            counter =>   counter,
            head =>      bufferHead
    );
    end generate ThorGenerate ;

    data <= bufferHead;
    data_av <= has_data_and_sending;
    credit_o <= '1' when (counter /= TAM_BUFFER or pull = '1') else '0';
    sender <= sending;
    h <= has_data and not sending;

    pull <= data_ack and has_data_and_sending;
    has_data <= '1' when (counter /= 0) else '0';
    has_data_and_sending <= has_data and sending;

    process(current_state, ack_h, sent)
    begin
        next_state <= current_state;
        case current_state is
            when REQ_ROUTING =>
                if ack_h = '1' then
                    next_state <= SEND_DATA;
                end if;

            when SEND_DATA =>
                if sent = '1' then
                    next_state <= REQ_ROUTING;
                end if;
        end case;
    end process;

    process(reset, clock)
    begin
        if reset = '1' then
            current_state <= REQ_ROUTING;
        elsif rising_edge(clock) then
            current_state <= next_state;
        end if;
    end process;

    process(current_state, sent)
    begin
        case current_state is
            when SEND_DATA =>
                sending <= not sent;
            when others =>
                sending <= '0';
        end case;
    end process;

    process(reset, clock)
        variable flit_index : integer;
        variable counter_flit : integer;
    begin
        if reset = '1' then
            sent <= '0';
        elsif rising_edge(clock) then
            if sending = '1' then
                if data_ack = '1' and has_data = '1' then
                    sent <= '0';
                    if flit_index = 1 then
                        counter_flit :=  to_integer(unsigned(bufferHead));
                    elsif counter_flit /= 1 then
                        counter_flit := counter_flit - 1;
                    else -- counter_flit = 1
                        sent <= '1';
                    end if;
                    flit_index := flit_index + 1;
                else
                end if;
            else
                flit_index := 0;
                counter_flit := 0;
                sent <= '0';
            end if;
        end if;
    end process;

end Thor_buffer;
