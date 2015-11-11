configuration BsdTcpC {
    provides interface BSDTCP[uint8_t sockid];
} implementation {
    components MainC, BsdTcpP, IPStackC, IPAddressC;
    components new TimerMilliC();
    components new VirtualizeTimerC(TMilli, 16);
    
    VirtualizeTimerC.TimerFrom -> TimerMilliC;
    
    BsdTcpP.Boot -> MainC.Boot;
    BsdTcpP.IP -> IPStackC.IP[IANA_TCP];
    BsdTcpP.IPAddress -> IPAddressC.IPAddress;
    BsdTcpP.Timer -> VirtualizeTimerC.Timer;
    
    BSDTCP = BsdTcpP.BSDTCP;
}
