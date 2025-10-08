// SPDX-License-Identifier: GPL-2.0-only
/*
 * Keyboard Backlight LED Driver for PicoCalc MFD
 */

#include <linux/leds.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>
#include <linux/of.h>

#include "../picocalc_mfd/picocalc_reg.h"

struct picocalc_mfd_led {
    struct regmap *regmap;
    struct led_classdev led_dev;
};

static void picocalc_led_brightness_set(struct led_classdev *led_cdev,
                                     enum led_brightness brightness)
{
    struct picocalc_mfd_led *led = container_of(led_cdev,
                                                struct picocalc_mfd_led,
                                                led_dev);

    regmap_write(led->regmap, (REG_ID_BK2 | MSB_MASK), brightness);
}

static int picocalc_mfd_led_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct picocalc_mfd_led *led;

    led = devm_kzalloc(dev, sizeof(*led), GFP_KERNEL);
    if (!led)
        return -ENOMEM;

    led->regmap = dev_get_regmap(dev->parent, NULL);
    if (!led->regmap) {
        dev_err(dev, "Failed to get parent regmap\n");
        return -EINVAL;
    }

    led->led_dev.name = "picocalc::kbd_backlight";
    led->led_dev.max_brightness = 255;
    led->led_dev.brightness_set = picocalc_led_brightness_set;

    platform_set_drvdata(pdev, led);

    return devm_led_classdev_register(dev, &led->led_dev);
}

static const struct of_device_id picocalc_mfd_led_of_match[] = {
    { .compatible = "picocalc_mfd_led", },
    {}
};
MODULE_DEVICE_TABLE(of, picocalc_mfd_led_of_match);

static struct platform_driver picocalc_mfd_led_driver = {
    .driver = {
        .name = "picocalc_mfd_led",
        .of_match_table = picocalc_mfd_led_of_match,
    },
    .probe = picocalc_mfd_led_probe,
};

module_platform_driver(picocalc_mfd_led_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("John Laur <johnl@blurbco.com>");
MODULE_DESCRIPTION("Keyboard Backlight LED driver for PicoCalc MFD");
