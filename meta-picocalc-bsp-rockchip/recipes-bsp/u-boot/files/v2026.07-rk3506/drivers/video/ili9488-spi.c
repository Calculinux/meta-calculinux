/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * ILI9488 SPI DM_VIDEO driver for PicoCalc (320x320 RGB565).
 *
 * Init / window / pixel path ported from Linux picocalc_lcd_fb/ili9488_fb.c.
 * Backlight: one I2C write to the PicoCalc MFD (addr 0x1f, reg 0x05|0x80).
 */

#include <bmp_layout.h>
#include <dm.h>
#include <i2c.h>
#include <log.h>
#include <spi.h>
#include <time.h>
#include <video.h>
#include <asm/gpio.h>
#include <dm/device_compat.h>
#include <linux/delay.h>

#define ILI9488_WIDTH		320
#define ILI9488_HEIGHT		320
#define ILI9488_BPP		16
#define ILI9488_FB_SIZE		(ILI9488_WIDTH * ILI9488_HEIGHT * 2)

#define LOGO_WIDTH		160
#define LOGO_HEIGHT		160
#define LOGO_X			((ILI9488_WIDTH - LOGO_WIDTH) / 2)
#define LOGO_Y			((ILI9488_HEIGHT - LOGO_HEIGHT) / 2)
#define LOGO_HOLD_MS		1000

/* PicoCalc MFD backlight (picocalc_mfd_bkl): write reg|0x80 = brightness */
#define PICOCALC_MFD_I2C_ADDR	0x1f
#define PICOCALC_BKL_REG	0x05
#define PICOCALC_BKL_VALUE	0x80

extern const u8 calculinux_logo_bmp[];
extern const u32 calculinux_logo_bmp_len;

struct ili9488_priv {
	struct gpio_desc dc;
	struct gpio_desc reset;
	ulong last_sync_ms;
	bool splash_done;
	bool sync_active;
};

static int ili9488_spi_write(struct udevice *dev, const void *buf, size_t len)
{
	return dm_spi_xfer(dev, len * 8, buf, NULL, SPI_XFER_BEGIN | SPI_XFER_END);
}

static int ili9488_write_cmd(struct udevice *dev, u8 cmd)
{
	struct ili9488_priv *priv = dev_get_priv(dev);
	int ret;

	ret = dm_gpio_set_value(&priv->dc, 0);
	if (ret)
		return ret;
	return ili9488_spi_write(dev, &cmd, 1);
}

static int ili9488_write_data(struct udevice *dev, const u8 *data, size_t len)
{
	struct ili9488_priv *priv = dev_get_priv(dev);
	int ret;

	if (!len)
		return 0;
	ret = dm_gpio_set_value(&priv->dc, 1);
	if (ret)
		return ret;
	return ili9488_spi_write(dev, data, len);
}

static int ili9488_write_reg(struct udevice *dev, u8 cmd, const u8 *data,
			     size_t len)
{
	int ret;

	ret = ili9488_write_cmd(dev, cmd);
	if (ret)
		return ret;
	return ili9488_write_data(dev, data, len);
}

static int ili9488_reset(struct udevice *dev)
{
	struct ili9488_priv *priv = dev_get_priv(dev);

	/* ACTIVE_HIGH reset: assert, deassert, assert (matches Linux raw GPIO) */
	dm_gpio_set_value(&priv->reset, 1);
	mdelay(10);
	dm_gpio_set_value(&priv->reset, 0);
	mdelay(10);
	dm_gpio_set_value(&priv->reset, 1);
	mdelay(10);
	return 0;
}

static int ili9488_init_display(struct udevice *dev)
{
	static const u8 gamma_p[] = {
		0x00, 0x03, 0x09, 0x08, 0x16, 0x0A, 0x3F, 0x78,
		0x4C, 0x09, 0x0A, 0x08, 0x16, 0x1A, 0x0F
	};
	static const u8 gamma_n[] = {
		0x00, 0x16, 0x19, 0x03, 0x0F, 0x05, 0x32, 0x45,
		0x46, 0x04, 0x0E, 0x0D, 0x35, 0x37, 0x0F
	};
	static const u8 pwr1[] = { 0x17, 0x15 };
	static const u8 vcom[] = { 0x00, 0x12, 0x80 };
	static const u8 frctrl[] = { 0xD0, 0x11 };
	static const u8 disfn[] = { 0x02, 0x02, 0x3B };
	static const u8 adj3[] = { 0xA9, 0x51, 0x2C, 0x82 };
	u8 v;
	int ret;

	ret = ili9488_reset(dev);
	if (ret)
		return ret;

	ret = ili9488_write_reg(dev, 0xE0, gamma_p, sizeof(gamma_p));
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0xE1, gamma_n, sizeof(gamma_n));
	if (ret)
		return ret;

	ret = ili9488_write_reg(dev, 0xC0, pwr1, sizeof(pwr1));
	if (ret)
		return ret;
	v = 0x41;
	ret = ili9488_write_reg(dev, 0xC1, &v, 1);
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0xC5, vcom, sizeof(vcom));
	if (ret)
		return ret;

	v = 0x48; /* MADCTL: MX | BGR — matches Linux ili9488_fb */
	ret = ili9488_write_reg(dev, 0x36, &v, 1);
	if (ret)
		return ret;
	v = 0x55; /* 16bpp RGB565 */
	ret = ili9488_write_reg(dev, 0x3A, &v, 1);
	if (ret)
		return ret;
	v = 0x00;
	ret = ili9488_write_reg(dev, 0xB0, &v, 1);
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0xB1, frctrl, sizeof(frctrl));
	if (ret)
		return ret;
	ret = ili9488_write_cmd(dev, 0x21); /* INVON */
	if (ret)
		return ret;
	v = 0x02;
	ret = ili9488_write_reg(dev, 0xB4, &v, 1);
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0xB6, disfn, sizeof(disfn));
	if (ret)
		return ret;
	v = 0xC6;
	ret = ili9488_write_reg(dev, 0xB7, &v, 1);
	if (ret)
		return ret;
	v = 0x00;
	ret = ili9488_write_reg(dev, 0xE9, &v, 1);
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0xF7, adj3, sizeof(adj3));
	if (ret)
		return ret;

	ret = ili9488_write_cmd(dev, 0x11); /* sleep out */
	if (ret)
		return ret;
	mdelay(120);
	ret = ili9488_write_cmd(dev, 0x29); /* display on */
	if (ret)
		return ret;
	mdelay(20);

	return 0;
}

static int ili9488_set_addr_win(struct udevice *dev, int xs, int ys, int xe,
				int ye)
{
	u8 col[] = { xs >> 8, xs & 0xff, xe >> 8, xe & 0xff };
	u8 row[] = { ys >> 8, ys & 0xff, ye >> 8, ye & 0xff };
	int ret;

	ret = ili9488_write_reg(dev, 0x2A, col, sizeof(col));
	if (ret)
		return ret;
	ret = ili9488_write_reg(dev, 0x2B, row, sizeof(row));
	if (ret)
		return ret;
	return ili9488_write_cmd(dev, 0x2C);
}

static int ili9488_flush_fb(struct udevice *dev)
{
	struct video_priv *uc_priv = dev_get_uclass_priv(dev);
	struct ili9488_priv *priv = dev_get_priv(dev);
	u16 *fb = uc_priv->fb;
	u8 line[ILI9488_WIDTH * 2];
	int y, x, ret;

	ret = ili9488_set_addr_win(dev, 0, 0, ILI9488_WIDTH - 1,
				   ILI9488_HEIGHT - 1);
	if (ret)
		return ret;

	ret = dm_gpio_set_value(&priv->dc, 1);
	if (ret)
		return ret;

	/*
	 * Panel wants big-endian RGB565 on the wire (Linux ili9488_fb byte
	 * swap). Framebuffer stays LE for vidconsole / video_bmp.
	 */
	for (y = 0; y < ILI9488_HEIGHT; y++) {
		u16 *src = fb + y * ILI9488_WIDTH;

		for (x = 0; x < ILI9488_WIDTH; x++) {
			u16 px = src[x];

			line[x * 2] = px >> 8;
			line[x * 2 + 1] = px & 0xff;
		}
		ret = ili9488_spi_write(dev, line, sizeof(line));
		if (ret)
			return ret;
	}

	return 0;
}

static int ili9488_backlight_on(struct udevice *dev)
{
	struct udevice *bus, *chip;
	int ret;

	ret = uclass_get_device_by_seq(UCLASS_I2C, 2, &bus);
	if (ret) {
		debug("%s: i2c2 not found (%d)\n", __func__, ret);
		return ret;
	}

	ret = i2c_get_chip(bus, PICOCALC_MFD_I2C_ADDR, 1, &chip);
	if (ret) {
		debug("%s: MFD 0x%02x not found (%d)\n", __func__,
		      PICOCALC_MFD_I2C_ADDR, ret);
		return ret;
	}

	ret = dm_i2c_reg_write(chip, PICOCALC_BKL_REG | 0x80, PICOCALC_BKL_VALUE);
	if (ret)
		dev_err(dev, "backlight I2C write failed: %d\n", ret);

	return ret;
}

static int ili9488_show_splash(struct udevice *dev)
{
	struct ili9488_priv *priv = dev_get_priv(dev);
	const struct bmp_image *bmp = (const void *)calculinux_logo_bmp;
	int ret;

	if (calculinux_logo_bmp_len < sizeof(struct bmp_header) ||
	    bmp->header.signature[0] != 'B' || bmp->header.signature[1] != 'M') {
		dev_err(dev, "invalid embedded logo BMP\n");
		return -EINVAL;
	}

	/*
	 * Mark done first: video_bmp_display() calls video_sync(), which is
	 * ignored while sync_active (bus already claimed). Flush explicitly.
	 */
	priv->splash_done = true;
	ret = video_bmp_display(dev, (ulong)calculinux_logo_bmp, LOGO_X, LOGO_Y,
				false);
	if (ret) {
		dev_err(dev, "logo blit failed: %d\n", ret);
		return ret;
	}

	ret = ili9488_flush_fb(dev);
	if (ret)
		return ret;

	mdelay(LOGO_HOLD_MS);
	priv->last_sync_ms = get_timer(0);
	return 0;
}

static int ili9488_video_sync(struct udevice *vid)
{
	struct ili9488_priv *priv = dev_get_priv(vid);
	int ret;

	/* video_bmp_display → video_sync re-entrancy while bus is claimed */
	if (priv->sync_active)
		return 0;

	priv->sync_active = true;

	ret = dm_spi_claim_bus(vid);
	if (ret) {
		priv->sync_active = false;
		return ret;
	}

	if (!priv->splash_done) {
		ret = ili9488_show_splash(vid);
		goto out;
	}

	/* Rate-limit full-frame SPI pushes (same idea as Flipper SPI video). */
	if (get_timer(priv->last_sync_ms) < CONFIG_VIDEO_SYNC_MS) {
		ret = 0;
		goto out;
	}

	ret = ili9488_flush_fb(vid);
	priv->last_sync_ms = get_timer(0);

out:
	dm_spi_release_bus(vid);
	priv->sync_active = false;
	return ret;
}

static int ili9488_probe(struct udevice *dev)
{
	struct ili9488_priv *priv = dev_get_priv(dev);
	struct video_priv *uc_priv = dev_get_uclass_priv(dev);
	int ret;

	uc_priv->xsize = ILI9488_WIDTH;
	uc_priv->ysize = ILI9488_HEIGHT;
	uc_priv->bpix = VIDEO_BPP16;

	ret = gpio_request_by_name(dev, "dc-gpios", 0, &priv->dc, GPIOD_IS_OUT);
	if (ret) {
		dev_err(dev, "dc-gpios: %d\n", ret);
		return ret;
	}

	ret = gpio_request_by_name(dev, "reset-gpios", 0, &priv->reset,
				   GPIOD_IS_OUT);
	if (ret) {
		dev_err(dev, "reset-gpios: %d\n", ret);
		return ret;
	}

	ret = dm_spi_claim_bus(dev);
	if (ret) {
		dev_err(dev, "SPI claim: %d\n", ret);
		return ret;
	}

	ret = ili9488_init_display(dev);
	dm_spi_release_bus(dev);
	if (ret) {
		dev_err(dev, "panel init: %d\n", ret);
		return ret;
	}

	/* Best-effort: panel still useful without backlight. */
	ili9488_backlight_on(dev);

	return 0;
}

static int ili9488_bind(struct udevice *dev)
{
	struct video_uc_plat *plat = dev_get_uclass_plat(dev);

	plat->size = ILI9488_FB_SIZE;
	return 0;
}

static const struct video_ops ili9488_ops = {
	.video_sync = ili9488_video_sync,
};

static const struct udevice_id ili9488_ids[] = {
	{ .compatible = "ilitek,ili9488" },
	{ .compatible = "picocalc,spilcd" },
	{ }
};

U_BOOT_DRIVER(ili9488_spi) = {
	.name		= "ili9488_spi",
	.id		= UCLASS_VIDEO,
	.of_match	= ili9488_ids,
	.ops		= &ili9488_ops,
	.bind		= ili9488_bind,
	.probe		= ili9488_probe,
	.priv_auto	= sizeof(struct ili9488_priv),
};
