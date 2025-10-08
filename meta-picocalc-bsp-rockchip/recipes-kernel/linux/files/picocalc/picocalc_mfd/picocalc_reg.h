#ifndef PICOCALC_REG_H
#define PICOCALC_REG_H

#define REG_ID_TYP 0x00 // official 0x00 or custom firmware
#define REG_ID_VER 0x01 // fw version
#define REG_ID_CFG 0x02 // config
#define REG_ID_INT 0x03 // interrupt status
#define REG_ID_KEY 0x04 // key status
#define REG_ID_BKL 0x05 // backlight
#define REG_ID_DEB 0x06 // debounce cfg
#define REG_ID_FRQ 0x07 // poll freq cfg
#define REG_ID_RST 0x08 // reset
#define REG_ID_FIF 0x09 // fifo
#define REG_ID_BK2 0x0A //keyboard backlight
#define REG_ID_BAT 0x0b// battery
#define REG_ID_C64_MTX 0x0c// read c64 matrix
#define REG_ID_C64_JS 0x0d // joystick io bits
#define REG_ID_OFF 0x0e // power off

/* Most significant bit is used for masking in this driver */
/* MSB must be set on register address when writing        */
/* MSB is used as a boolean flag with 7 bit return data.   */
#define MSB_MASK (1 << 7)

#endif
