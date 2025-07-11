library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

entity SCCBMaster is
    generic(
        GInputClock :   integer := 50_000_000;                  --  FPGA' nin ana clock hizi
        GBusClock   :   integer := 400_000                      --  SCCB hattinin calistirilmasi icin belirlenecek hiz (400 kHz SCCB fast mode)
    );          
	port(       
		PIClock     :   in      std_logic;                      --  Sistem clock girisi
        PIReset     :   in      std_logic;                      --  Reset(active low) girisi
        PIEnable    :   in      std_logic;                      --  SCCB hattini aktif edecek enable girisi
        PIAddress   :   in      std_logic_vector(6 downto 0);   --  SCCB hattina bagli olan slave cihazlarinin ana adreslerini isaret eden giris
        PIRegister  :   in      std_logic_vector(7 downto 0);   --  Slave birimin islem yapilacak register adresini belirten giris
        PIWriteData :   in      std_logic_vector(7 downto 0);   --  Master -> Slave yonunde yazilacak data
        PIStart     :   in      std_logic;                      --  SCCB master backend calistirma girisi
        PODone      :   out     std_logic;                      --  SCCB arayuzunun yazma islemini bitirdigini belirten cikis
        POReady     :   out     std_logic;                      --  SCCB arayuzunun islem yapmaya hazir oldugunu belirten cikis
        PIOSIOD     :   inout   std_logic;                      --  SCCB seri data cikisi - girisi
        POSIOC      :   out     std_logic                       --  SCCB seri clock cikisi
	);
end SCCBMaster;

architecture Behavioral of SCCBMaster is


    type        TStatesWrite        is  (idle, start_condition, send_addr, addr_dc, send_reg, reg_dc, send_data, data_dc, stop);
    signal      SStateWriteBase     :   TStatesWrite                        :=  idle;
    
    constant    CClockCountMax      :   integer                             :=  (GInputClock / GBusClock);
    
    signal      SStart              :   std_logic                           :=  '0';
    signal      SStartReg           :   std_logic                           :=  '0';
    signal      SStartedWrite       :   std_logic                           :=  '0';  

    signal      SEnable             :   std_logic                           :=  '0';
    signal      SAddress            :   std_logic_vector(6 downto 0)        :=  (others => '0');
    signal      SRegister           :   std_logic_vector(7 downto 0)        :=  (others => '0');
    signal      SWriteData          :   std_logic_vector(7 downto 0)        :=  (others => '0');
    signal      SBusy               :   std_logic                           :=  '0';    
    signal      SBusy2              :   std_logic                           :=  '0';               
    signal      SDone               :   std_logic                           :=  '0';
    signal      SReady              :   std_logic                           :=  '0';

    signal      SDataClockRef       :   std_logic                           :=  '0';
    signal      SDataClockRefPrev   :   std_logic                           :=  '0';
    
    -- signal      SSIODClock          :   std_logic                        :=    '0';   --  DEBUG AMACLIDIR!
    -- signal      SSIODClockPrev      :   std_logic;                                    --  DEBUG AMACLIDIR!
    signal      SSIOCClock          :   std_logic                           :=  '1';
    signal      SSIOCClockPrev      :   std_logic;      
    
    signal      SSIODWrite          :   std_logic                           :=  '0';
    signal      SSIODRead           :   std_logic                           :=  '0';
    signal      SSIOCWrite          :   std_logic                           :=  '0';
    signal      SSIOCRead           :   std_logic                           :=  '0';  
    
    signal      SAddr               :   std_logic_vector(6 downto 0)        :=  (others => '0');
    signal      SReg                :   std_logic_vector(7 downto 0)        :=  (others => '0');
    signal      SData               :   std_logic_vector(7 downto 0)        :=  (others => '0');
    
    signal      SAddrReg            :   std_logic_vector(6 downto 0)        :=  (others => '0');
    signal      SRegReg             :   std_logic_vector(7 downto 0)        :=  (others => '0');
    signal      SDataReg            :   std_logic_vector(7 downto 0)        :=  (others => '0'); 
    signal      SCounter            :   integer range 0 to 8                :=  0;

    signal      SCounterSCCB        :   integer range 0 to CClockCountMax   :=  0;
    signal	    SCounter2           :	integer range 0 to 3                :=  0;
    

begin

   SStart      <=  PIStart;
    SEnable     <=  PIEnable;
    SAddress    <=  PIAddress;  
    SRegister   <=  PIRegister; 
    SWriteData  <=  PIWriteData;
    PODone      <=  SDone;
    POReady     <=  SReady;	

    POSIOC      <=  SSIOCWrite when (SStateWriteBase = idle or SStateWriteBase = start_condition or SStateWriteBase = stop ) else
                    SSIOCClock;
    
    PIOSIOD     <=  SSIODWrite when SEnable = '1' else 'Z';

    SStartReg   <=  '1' when SStart = '1' and SEnable = '1' else
                    '0' when (SSIOCClock = '0' and SSIOCClockPrev = '1') or PIReset = '0' or SEnable = '0' else
                    SStartReg;

READY : process(PIClock, PIReset)
    begin
        if PIReset = '0' then
            SReady      <= '0';
        elsif rising_edge(PIClock) then
            if SStateWriteBase = idle then
                SReady  <= '1';
            else
                SReady  <= '0';
            end if;
        end if;
    end process;

DATA_CAPTURE : process(PIClock, PIReset)
    begin
        if PIReset = '0' then
            SAddrReg        <= (others => '0');
            SRegReg         <= (others => '0');
            SDataReg        <= (others => '0');
        elsif rising_edge(PIClock) then
            if SStart = '1' then
                SAddrReg    <= SAddress;
                SRegReg     <= SRegister;
                SDataReg    <= SWriteData;
            elsif SSIOCClock = '0' and SSIOCClockPrev = '1' then
                SAddrReg    <= SAddrReg;
                SRegReg     <= SRegReg; 
                SDataReg    <= SDataReg;
            else
                SAddrReg    <= SAddrReg;
                SRegReg     <= SRegReg; 
                SDataReg    <= SDataReg;
            end if;
        end if;
    end process;

CLKGEN : process(PIClock)
        variable    VCounter        : integer range 0 to CClockCountMax     := 0;
    begin
        if rising_edge(PIClock) then
            --SSIODClockPrev      <= SSIODClock;
            SSIOCClockPrev      <= SSIOCClock;
            SDataClockRefPrev   <=  SDataClockRef;
            
				if SCounterSCCB = (CClockCountMax / 4) - 1 then
					SDataClockRef   <= not SDataClockRef;
					if SCounter2 = 1 then
						--SSIODClock  <= not SSIODClock;
						SSIOCClock   <= not SSIOCClock;
						SCounter2 <= 0;
					else
						SCounter2 <= SCounter2 + 1;
					end if;
					SCounterSCCB	<= 0;
				else
					SCounterSCCB    <= SCounterSCCB +1;
				end if;

        end if;
    end process;

DATA_WRITE : process(PIClock, PIReset)
        variable VCounter : integer range 0 to 16 := 0;
    begin
        if PIReset = '0' then
            SStateWriteBase <= idle;
            SStartedWrite   <= '0';
            SAddr           <= (others => '0');
            SReg            <= (others => '0');
            SData           <= (others => '0');
            SSIODWrite      <= 'Z';
            SSIOCWrite      <= '1';
            SBusy           <= '0';
            SDone           <= '0';
            SBusy2          <= '0';
            VCounter        := 0;
            SCounter        <=  7;
        elsif rising_edge(PIClock) then
            case SStateWriteBase is

when idle =>
                    if SSIOCClock = '0' and SSIOCClockPrev = '1' then
                        if SStartReg = '1' then
                            SSIODWrite   <= '1';
                            SSIOCWrite   <= '1';
                            SStartedWrite    <= '1';
                            SDone       <= '0';
                            SAddr       <= SAddrReg;
                            SReg        <= SRegReg;
                            SData       <= SDataReg;
                        else
                            SAddr       <= (others => '0');
                            SReg        <= (others => '0');
                            SData       <= (others => '0');
                            SStateWriteBase      <= idle;
                            SSIODWrite   <= 'Z';
                            SSIOCWrite   <= '1';
                            SStartedWrite    <= '0';
                            SDone       <= '1';
                        end if;
                    elsif SSIOCClock = '1' and SSIOCClockPrev = '0' and SStartedWrite = '1' then    
                        SSIODWrite   <= '0';
                        
                        SStartedWrite    <= '0';
                        SStateWriteBase <= start_condition;
                    end if;

when start_condition =>
                    if SSIOCClock = '0' and SSIOCClockPrev = '1' then
                        SBusy <= '1';
                        if SBusy = '1' then
                            SBusy2 <= '1';
                        end if;
                        SSIOCWrite   <= '0';
                    elsif SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' and SBusy2 = '1' then
                        if SAddr(6) = '1' then
                            SSIODWrite <= '1';
                            SAddr <= std_logic_vector(shift_left(unsigned(SAddr), 1));
                        elsif SAddr(6) = '0' then
                            SSIODWrite <= '0';
                            SAddr <= std_logic_vector(shift_left(unsigned(SAddr), 1));
                        end if;
                        SBusy   <= '0';
                        SBusy2   <= '0';                            
                        SStateWriteBase      <= send_addr;

                        
                    else
                        SStateWriteBase      <= start_condition;
                    end if;

when send_addr =>
                    if SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' then
                        if VCounter <= 5 then
                            VCounter    := VCounter + 1;
                            if(SAddr(6) = '1') then
                                SSIODWrite   <= '1';
                                SAddr       <= std_logic_vector(shift_left(unsigned(SAddr), 1));
                            elsif (SAddr(6) = '0') then
                                SSIODWrite   <= '0';
                                SAddr       <= std_logic_vector(shift_left(unsigned(SAddr), 1));
                            end if;
                        else
                            VCounter    := 0;
                            SSIODWrite   <= '0'; ---->>>> Don't Care Bit!
                            SStateWriteBase      <= addr_dc;
                            SBusy       <= '0';
                        end if;
                    else
                        SStateWriteBase      <= send_addr;
                    end if;

                when addr_dc =>
                    if SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' then
                        SAddr   <=  (others => '0');
                    elsif SDataClockRef = '0' and SDataClockRefPrev = '1' and SSIOCClock = '0' then
                        SStateWriteBase      <= send_reg;
                    end if;
        
when send_reg =>
                    if SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' then
                        SBusy <= '1';
                        if SBusy = '1' then
                            if VCounter <= 7 then
                                VCounter    := VCounter + 1;
                                if(SReg(7) = '1') then
                                    SSIODWrite   <= '1';
                                    SReg        <= std_logic_vector(shift_left(unsigned(SReg), 1));
                                elsif (SReg(7) = '0') then
                                    SSIODWrite   <= '0';
                                    SReg        <= std_logic_vector(shift_left(unsigned(SReg), 1));
                                end if;
                            else
                                SBusy <= '0';
                                VCounter    := 0;
                                SSIODWrite   <= '0'; ---->>>> Don't Care Bit!
                                SStateWriteBase      <= reg_dc;
                            end if;
                        end if;
                    end if;
                
when reg_dc =>
                    if SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' then
                        SReg   <=  (others => '0');
                        SStateWriteBase      <= send_data;
                        if(SData(7) = '1') then
                            SSIODWrite   <= '1';
                            SData       <= std_logic_vector(shift_left(unsigned(SData), 1));
                            SBusy <= '0';
                        elsif (SData(7) = '0') then
                            SSIODWrite   <= '0';
                            SData       <= std_logic_vector(shift_left(unsigned(SData), 1));
                            SBusy <= '0';
                        end if;
                    end if;
                
when send_data =>
                    if SDataClockRef = '1' and SDataClockRefPrev = '0' and SSIOCClock = '0' then
                        if VCounter     <= 6 then
                            VCounter    := VCounter + 1;
                            if(SData(7) = '1') then
                                SSIODWrite   <= '1';
                                SData       <= std_logic_vector(shift_left(unsigned(SData), 1));
                            elsif (SData(7) = '0') then
                                SSIODWrite   <= '0';
                                SData       <= std_logic_vector(shift_left(unsigned(SData), 1));
                            end if;
                        else
                            
                            SSIODWrite   <= '0'; ----
                            SBusy <= '1';
                            if SBusy = '1' then
                                VCounter    := 0;
                                SStateWriteBase      <= data_dc;
                                SBusy <= '0';
                            end if;
                            
                        end if;
                    end if;

when stop =>
                    SSIOCWrite   <= '1';
                    if SSIOCClock = '1' and SSIOCClockPrev = '0' then
                          SSIODWrite   <= '1';
                        SBusy       <= '1';
                        SAddr       <= (others => '0');
                        SReg        <= (others => '0');
                        SData       <= (others => '0');
                        if SBusy = '1' then
                            --SReady      <= '1';
                            SStateWriteBase      <= idle;
                            SDone       <= '1';
                        
                            SBusy       <= '0';
                        end if;
                    elsif SSIOCClock = '0' and SSIOCClockPrev = '1' then
                        SSIODWrite   <= '1';
                    end if;

                when others =>
            end case;
        end if;
    end process;

end Behavioral;