library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity display is
    Port(clk : in  std_logic;                         -- 100MHzϵͳʱ��
         number : in  std_logic_vector (15 downto 0); -- 8�����ֵ���������(ÿ������4λ����8*4=32λ)
         seg : out  std_logic_vector (6 downto 0);    -- ���ݶ�(���λΪС����)
         an : out  std_logic_vector (7 downto 0));    -- ����ѡ���
end display;

architecture Behavioral of display is

    signal cnt: std_logic_vector (19 downto 0);
    signal anode_select: std_logic_vector (1 downto 0); -- 3λ����ɨ���źţ�Ҳ��״̬��״̬
    signal digit_data: std_logic_vector (3 downto 0); -- ��ǰ��ʾ����������
    signal segment_data: std_logic_vector (6 downto 0); -- �߶�����������ź�(����С����)
    signal an_tmp: std_logic_vector (7 downto 0);       -- δ��ʹ�ܶ����ǰ������ɨ���ź�(8λ)

begin
    -- ������
    process(clk)
    begin
        if rising_edge(clk) then
            cnt <= cnt + '1';
        end if;
    end process;
    
    -- �����λ����Ϊɨ��״̬ (ÿ������ˢ���ʣ�100MHz/2^20 �� 95.3Hz)
    anode_select <= cnt(19 downto 18);
    
    -- ����ɨ�� (3-8������)
    with anode_select select
        an_tmp <=
            "11111110" when "00",
            "11111101" when "01",
            "11111011" when "10",
            "11110111" when "11",
            "11111111" when others;
    
    -- Ӧ�õ͵�ƽʹ�ܿ���
    an <= an_tmp;

    -- ����ѡ���·����
    with anode_select select
        digit_data <=
            number(3 downto 0)   when "00",
            number(7 downto 4)   when "01",
            number(11 downto 8)  when "10",
            number(15 downto 12) when "11",
            "0000"               when others;
    
    -- ʮ�����Ƶ��߶���������� (gfedcba)
    with digit_data select
        segment_data <=
            "1000000" when "0000", -- 0
            "1111001" when "0001", -- 1
            "0100100" when "0010", -- 2
            "0110000" when "0011", -- 3
            "0011001" when "0100", -- 4
            "0010010" when "0101", -- 5
            "0000010" when "0110", -- 6
            "1111000" when "0111", -- 7
            "0000000" when "1000", -- 8
            "0010000" when "1001", -- 9
            "0001000" when "1010", -- A
            "0000011" when "1011", -- b
            "1000110" when "1100", -- C
            "0100001" when "1101", -- d
            "0000110" when "1110", -- E
            "0001110" when "1111", -- F
            "1111111" when others; -- ȫ��
    
    -- ���С������߶����� (С���������λ)
    seg <= segment_data;
    
end Behavioral;