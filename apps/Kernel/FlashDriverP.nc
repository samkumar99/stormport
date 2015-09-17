module FlashDriverP
{
    provides
    {
        interface Driver;
        interface Init;
    }
    uses
    {
        interface FastSpiByte;
        interface HplSam4lSPIChannel;
        interface Resource;
        interface GeneralIO as CS;
    }
}
implementation
{

    void sleep()
    {
        volatile uint32_t i;
        for (i=0;i<100;i++);
    }

    enum {
        OP_IDLE,
        OP_WRITE,
        OP_READ
    } operation;

    uint32_t addr;
    uint8_t *buf;
    uint32_t len;
    simple_callback_t callback;
    uint8_t callback_pending;
    uint8_t spi_busy;
    command error_t Init.init()
    {
        spi_busy = 0;
        callback_pending = 0;
        call HplSam4lSPIChannel.setMode(0,0);
        return SUCCESS;
    }

    event void Resource.granted()
    {
        uint32_t i;
        switch(operation)
        {
            case OP_IDLE:
                call Resource.release();
                return;
            case OP_WRITE:
                call CS.clr();
                sleep();
                call FastSpiByte.write(0x58); // RMW through buffer 1
                call FastSpiByte.write((uint8_t)(addr >> 16));
                call FastSpiByte.write((uint8_t)(addr >> 8));
                call FastSpiByte.write((uint8_t)(addr));
                for (i=0; i < len; i++) {
                    call FastSpiByte.write(buf[i]);
                }
                sleep();
                call CS.set();
                call Resource.release();
                callback_pending =1;
                return;
            case OP_READ:
                call CS.clr();
                sleep();
                call FastSpiByte.write(0x1B);
                call FastSpiByte.write((uint8_t)(addr >> 16));
                call FastSpiByte.write((uint8_t)(addr >> 8));
                call FastSpiByte.write((uint8_t)(addr));
                call FastSpiByte.write(0x00);
                call FastSpiByte.write(0x00);
                for (i = 0; i < len; i++)
                {
                    buf[i] = call FastSpiByte.write(0x00);
                }
                call CS.set();
                call Resource.release();
                callback_pending =1;
                return;
        }
    }

    async command syscall_rv_t Driver.syscall_ex(
        uint32_t number, uint32_t arg0,
        uint32_t arg1, uint32_t arg2,
        uint32_t *argx)
    {
        switch(number & 0xFF)
        {
                       //      ar0   arg1    arg2     arx[0], argx[1]   argx[2]
            case 0x01: //read flash(addr, buf, len, cb, r)
            {
                if (spi_busy || callback_pending) return 1;
                addr = arg0+0x80000;
                buf = arg1;
                len = arg2;
                if (addr + len > 0x3ffffff) {
                    return 1;
                }
                callback.addr = argx[0];
                callback.r = (void*) argx[1];
                operation = OP_READ;
                spi_busy =1;
                call Resource.request();
                return 0;
            }
            case 0x02: //write flash(addr, buf, len, cb, r)
            {
                if (spi_busy || callback_pending) return 1;
                addr = arg0+0x80000;
                buf = arg1;
                len = arg2;
                if (addr + len > 0x3ffffff) {
                    return 1;
                }
                callback.addr = argx[0];
                callback.r = (void*) argx[1];
                operation = OP_WRITE;
                spi_busy = 1;
                call Resource.request();
                return 0;
            }
            break;
        }
    }
    command driver_callback_t Driver.peek_callback()
    {
        if (callback_pending) {
            return (driver_callback_t)&callback;
        }
        return NULL;
    }
    command void Driver.pop_callback()
    {
        callback_pending = 0;
        spi_busy = 0;
    }

}