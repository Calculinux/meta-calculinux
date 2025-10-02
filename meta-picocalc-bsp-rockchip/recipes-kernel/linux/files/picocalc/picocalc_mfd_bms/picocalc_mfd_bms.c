// SPDX-License-Identifier: GPL-2.0-only
/*
 * Power Supply Driver for PicoCalc
 */

#include <linux/power_supply.h>
#include <linux/device.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>
#include <linux/of.h>

#include "../picocalc_mfd/picocalc_reg.h"

struct picocalc_mfd_bms {
    struct regmap *regmap;
    struct power_supply *psy;
    struct module *parent_module;
};

static int picocalc_bms_get_property(struct power_supply *psy,
                                     enum power_supply_property psp,
                                     union power_supply_propval *val)
{
    struct picocalc_mfd_bms *bat = power_supply_get_drvdata(psy);
    u8 buf[2];
    int ret;

    /* Read the battery status register when needed */
    if (psp == POWER_SUPPLY_PROP_STATUS || psp == POWER_SUPPLY_PROP_CAPACITY) {
        ret = regmap_bulk_read(bat->regmap, REG_ID_BAT, buf, 2);
        if (ret < 0)
            return ret;
    }

    switch (psp) {
    case POWER_SUPPLY_PROP_STATUS:
        /* high bit indicates charging */
        if (buf[1] & MSB_MASK)
            val->intval = POWER_SUPPLY_STATUS_CHARGING;
        else if ((buf[1] & ~MSB_MASK) == 100)
            val->intval = POWER_SUPPLY_STATUS_FULL;
        else
            val->intval = POWER_SUPPLY_STATUS_DISCHARGING;
        break;
    case POWER_SUPPLY_PROP_CAPACITY:
        /* clear charging status bit */
        val->intval = buf[1] & ~(1 << 7);
        break;
    case POWER_SUPPLY_PROP_TECHNOLOGY:
        val->intval = POWER_SUPPLY_TECHNOLOGY_LION;
        break;
    case POWER_SUPPLY_PROP_HEALTH:
        val->intval = POWER_SUPPLY_HEALTH_GOOD;
        break;
    default:
        return -EINVAL;
    }

    return 0;
}

static enum power_supply_property picocalc_bms_properties[] = {
    POWER_SUPPLY_PROP_STATUS,
    POWER_SUPPLY_PROP_CAPACITY,
    POWER_SUPPLY_PROP_TECHNOLOGY,
    POWER_SUPPLY_PROP_HEALTH,
};

static const struct power_supply_desc picocalc_bms_desc = {
    .name = "picocalc",
    .type = POWER_SUPPLY_TYPE_BATTERY,
    .properties = picocalc_bms_properties,
    .num_properties = ARRAY_SIZE(picocalc_bms_properties),
    .get_property = picocalc_bms_get_property,
};

static int picocalc_mfd_bms_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct picocalc_mfd_bms *bat;
    struct power_supply_config psy_cfg = {};

    bat = devm_kzalloc(dev, sizeof(*bat), GFP_KERNEL);
    if (!bat)
        return -ENOMEM;

    bat->regmap = dev_get_regmap(dev->parent, NULL);
    if (!bat->regmap) {
        dev_err(dev, "Failed to get parent regmap\n");
        return -EINVAL;
    }

    psy_cfg.drv_data = bat;
    bat->psy = devm_power_supply_register(dev, &picocalc_bms_desc, &psy_cfg);
    if (IS_ERR(bat->psy)) {
        dev_err(dev, "Failed to register power supply\n");
        return PTR_ERR(bat->psy);
    }

    platform_set_drvdata(pdev, bat);

    return 0;
}

static const struct of_device_id picocalc_mfd_bms_of_match[] = {
    { .compatible = "picocalc_mfd_bms", },
    {}
};
MODULE_DEVICE_TABLE(of, picocalc_mfd_bms_of_match);

static struct platform_driver picocalc_mfd_bms_driver = {
    .driver = {
        .name = "picocalc_mfd_bms",
        .of_match_table = picocalc_mfd_bms_of_match,
    },
    .probe = picocalc_mfd_bms_probe,
};

module_platform_driver(picocalc_mfd_bms_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("John Laur <johnl@blurbco.com>");
MODULE_DESCRIPTION("Battery driver for PicoCalc MFD");