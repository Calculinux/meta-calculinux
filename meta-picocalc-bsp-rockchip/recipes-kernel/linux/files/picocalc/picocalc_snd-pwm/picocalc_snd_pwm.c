/*
 * Copyright (C) 2017 starterkit.ru
 *
 * Based on simple driver for PWM (Pulse Width Modulator) controller
 * Sascha Hauer <s.hauer@pengutronix.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/io.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_gpio.h>
#include <linux/of_device.h>
#include <linux/hrtimer.h>
#include <linux/ktime.h>
#include <linux/pwm.h>
#include <sound/core.h>
#include <sound/initval.h>
#include <sound/pcm.h>
#include <sound/control.h>

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("hiro <hiro@hiro.com>");

#define MICRO_SEC 1000000
#define NANO_SEC  (MICRO_SEC*1000)
/*
#define DEFAULT_DUTY_CYCLE 0
#define DEFAULT_PERIOD (NANO_SEC / 10000) // = 125000 // 0.125ms
#define DEFAULT_DUTY_CYCLE 0
*/

#define DEFAULT_DUTY_CYCLE 0
#define DEFAULT_PERIOD (125000 / 1) //(NANO_SEC / 8000) // = 125000 // 0.125ms
#define DEFAULT_PWM_PERIOD 15625 //(NANO_SEC / 64000)

/*
#define DEFAULT_DUTY_CYCLE 1500000 //1.5ms
#define DEFAULT_PERIOD  20000000 // 20ms
*/

static const struct of_device_id picocalc_snd_pwm_dt_ids[] = {
	{ .compatible = "fsl,picocalc-snd-pwm", },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, picocalc_snd_pwm_dt_ids);

#define dbg(fmt, arg...) \
	printk("picocalc-snd-pwm: %s: " fmt, __func__, ## arg);

struct picocalc_snd_dev {
	struct platform_device *pdev;
	struct snd_card *snd_card;
	struct snd_pcm_substream *ss;
	spinlock_t lock;

	unsigned int data_ptr;
	unsigned int period_ptr;

	unsigned int is_on;
	struct pwm_device *pwm_left;
	struct pwm_device *pwm_right;

    struct hrtimer tm1;
    ktime_t t1;
    unsigned long duty_cycle_left_ns;
	unsigned long duty_cycle_right_ns;
    unsigned long period_ns;
};

enum hrtimer_restart cb1(struct hrtimer *t) {
    struct picocalc_snd_dev *picocalc = container_of(t, struct picocalc_snd_dev, tm1);
    ktime_t now;
    int ovr;

    if (!picocalc->is_on)
    {
        return HRTIMER_NORESTART;
    }

    now = hrtimer_cb_get_time(t);
    ovr = hrtimer_forward(t, now, picocalc->t1);

    {
	unsigned char *data;
	unsigned int buffer_size;
	unsigned int period_size;
	unsigned int period_elapsed = 0;

    	data = picocalc->ss->runtime->dma_area;
    	buffer_size = picocalc->ss->runtime->buffer_size;
    	period_size = picocalc->ss->runtime->period_size;

		// Check if we are at the end of the buffer
    	if (++picocalc->data_ptr >= buffer_size)
        {
            picocalc->data_ptr = 0;
        }

		if (picocalc->ss->runtime->channels == 2) {
			// Stereo: interleaved left/right samples        
			picocalc->duty_cycle_left_ns  = (uint32_t)data[picocalc->data_ptr * 2]     * (uint32_t)DEFAULT_PWM_PERIOD / 255;
			picocalc->duty_cycle_right_ns = (uint32_t)data[picocalc->data_ptr * 2 + 1] * (uint32_t)DEFAULT_PWM_PERIOD / 255;
			
			pwm_config(picocalc->pwm_left,  picocalc->duty_cycle_left_ns,  DEFAULT_PWM_PERIOD);
			pwm_config(picocalc->pwm_right, picocalc->duty_cycle_right_ns, DEFAULT_PWM_PERIOD);
		} else {
			// Mono: same sample to both channels
			picocalc->duty_cycle_left_ns = (uint32_t)data[picocalc->data_ptr] * (uint32_t)DEFAULT_PWM_PERIOD / 255;
			picocalc->duty_cycle_right_ns = picocalc->duty_cycle_left_ns;
			
			pwm_config(picocalc->pwm_left,  picocalc->duty_cycle_left_ns,  DEFAULT_PWM_PERIOD);
			pwm_config(picocalc->pwm_right, picocalc->duty_cycle_right_ns, DEFAULT_PWM_PERIOD);
		}

        if (++picocalc->period_ptr >= period_size) {
            picocalc->period_ptr = 0;
            period_elapsed = 1;
        }

	if (period_elapsed)
		snd_pcm_period_elapsed(picocalc->ss);
    }

    return HRTIMER_RESTART;
}

static int picocalc_pwm_enable(struct picocalc_snd_dev *picocalc)
{
    pwm_config(picocalc->pwm_left,  picocalc->duty_cycle_left_ns,  DEFAULT_PWM_PERIOD);
    pwm_enable(picocalc->pwm_left);
	pwm_config(picocalc->pwm_right, picocalc->duty_cycle_right_ns, DEFAULT_PWM_PERIOD);
    pwm_enable(picocalc->pwm_right);

    hrtimer_init(&picocalc->tm1, CLOCK_MONOTONIC, HRTIMER_MODE_REL);

    picocalc->t1 = ktime_set(0, picocalc->period_ns);
    picocalc->tm1.function = &cb1;

    hrtimer_start(&picocalc->tm1, picocalc->t1, HRTIMER_MODE_REL);

    return 0;
}

static void picocalc_pwm_disable(struct picocalc_snd_dev *picocalc)
{
    hrtimer_cancel(&picocalc->tm1);
    pwm_config(picocalc->pwm_left,  DEFAULT_DUTY_CYCLE, DEFAULT_PWM_PERIOD);
    pwm_disable(picocalc->pwm_left);
    pwm_config(picocalc->pwm_right, DEFAULT_DUTY_CYCLE, DEFAULT_PWM_PERIOD);
    pwm_disable(picocalc->pwm_right);
}

/*
static irqreturn_t picocalc_irq_handler(int irq, void *dev_id)
{
	struct picocalc_snd_dev *picocalc = dev_id;
	unsigned int period_elapsed = 0;
	unsigned long flags;

	spin_lock_irqsave(&picocalc->lock, flags);
	if (picocalc->is_on) {
		unsigned char *data = picocalc->ss->runtime->dma_area;
		unsigned int buffer_size = picocalc->ss->runtime->buffer_size;
		unsigned int period_size = picocalc->ss->runtime->period_size;
		int i = 0;

		for (i = 0; i < 3; i++) {
			if (++picocalc->data_ptr >= buffer_size)
				picocalc->data_ptr = 0;
			writel(data[picocalc->data_ptr], picocalc->mmio_base + MX3_PWMSAR);

			if (++picocalc->period_ptr >= period_size) {
				picocalc->period_ptr = 0;
				period_elapsed = 1;
			}
		}
		writel(readl(picocalc->mmio_base + MX3_PWMSR),
			picocalc->mmio_base + MX3_PWMSR);
	}
	spin_unlock_irqrestore(&picocalc->lock, flags);

	if (period_elapsed)
		snd_pcm_period_elapsed(picocalc->ss);

	return IRQ_HANDLED;
}
*/

/**
 * PCM Interface
 */
static int picocalc_pcm_hw_params(struct snd_pcm_substream *ss,
		struct snd_pcm_hw_params *hw_params)
{
	return snd_pcm_lib_malloc_pages(ss, params_buffer_bytes(hw_params));
}

static int picocalc_pcm_hw_free(struct snd_pcm_substream *ss)
{
	return snd_pcm_lib_free_pages(ss);
}

static const struct snd_pcm_hardware picocalc_playback_hw = {
	.info			= (SNDRV_PCM_INFO_MMAP |
				   SNDRV_PCM_INFO_MMAP_VALID |
				   SNDRV_PCM_INFO_INTERLEAVED |
				   SNDRV_PCM_INFO_HALF_DUPLEX),
	.formats		= SNDRV_PCM_FMTBIT_U8,
	.rates			= SNDRV_PCM_RATE_8000,
	.rate_min		= 8000,
	.rate_max		= 8000,
	.channels_min		= 1,
	.channels_max		= 2,
	.buffer_bytes_max	= 8 * 1024,
	.period_bytes_min	= 4,
	.period_bytes_max	= 4 * 1024,
	.periods_min		= 4,
	.periods_max		= 1024, 
};

static int picocalc_pcm_open(struct snd_pcm_substream *ss)
{
	struct picocalc_snd_dev *picocalc = snd_pcm_substream_chip(ss);

	ss->runtime->hw = picocalc_playback_hw;
	picocalc->ss = ss;
	return 0;
}

static int picocalc_pcm_close(struct snd_pcm_substream *ss)
{
	return 0;
}

static int picocalc_pcm_prepare(struct snd_pcm_substream *ss)
{
	return 0;
}

static int picocalc_pcm_trigger(struct snd_pcm_substream *ss, int cmd)
{
	struct picocalc_snd_dev *picocalc = snd_pcm_substream_chip(ss);
	int ret = 0;
	unsigned long flags;

	spin_lock_irqsave(&picocalc->lock, flags);
	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
		{
		    unsigned char *data = picocalc->ss->runtime->dma_area;
		    if (picocalc->ss->runtime->channels == 2) {
		        // Stereo: initialize with first left/right samples
		        picocalc->duty_cycle_left_ns  = (uint32_t)data[0] * (uint32_t)DEFAULT_PWM_PERIOD / 255;
		        picocalc->duty_cycle_right_ns = (uint32_t)data[1] * (uint32_t)DEFAULT_PWM_PERIOD / 255;
		    } else {
		        // Mono: same sample to both channels
		        picocalc->duty_cycle_left_ns  = (uint32_t)data[0] * (uint32_t)DEFAULT_PWM_PERIOD / 255;
		        picocalc->duty_cycle_right_ns = picocalc->duty_cycle_left_ns;
		    }
		    picocalc->data_ptr = 0; 
		    picocalc->period_ptr = 0; 
		}
		if (picocalc_pwm_enable(picocalc) == 0)
			picocalc->is_on = 1;
		else
			ret = -EIO;
		break;
	case SNDRV_PCM_TRIGGER_STOP:
		if (!picocalc->is_on)
			break;
		picocalc->is_on = 0;
		picocalc->duty_cycle_left_ns  = 0;
		picocalc->duty_cycle_right_ns = 0;
		break;
	default:
		ret = -EINVAL;
	}
	spin_unlock_irqrestore(&picocalc->lock, flags);

	return ret;
}

static snd_pcm_uframes_t picocalc_pcm_pointer(struct snd_pcm_substream *ss)
{
	struct picocalc_snd_dev *picocalc = snd_pcm_substream_chip(ss);

	return picocalc->data_ptr;
}

static struct snd_pcm_ops picocalc_pcm_ops = {
	.open = picocalc_pcm_open,
	.close = picocalc_pcm_close,
	.ioctl = snd_pcm_lib_ioctl,
	.hw_params = picocalc_pcm_hw_params,
	.hw_free = picocalc_pcm_hw_free,
	.prepare = picocalc_pcm_prepare,
	.trigger = picocalc_pcm_trigger,
	.pointer = picocalc_pcm_pointer,
};

static int picocalc_snd_register(struct picocalc_snd_dev *picocalc)
{
	static struct snd_device_ops ops = { NULL };
	struct snd_card *card;
	struct snd_pcm *pcm;
	int ret;

	ret = snd_card_new(&picocalc->pdev->dev, SNDRV_DEFAULT_IDX1,
		SNDRV_DEFAULT_STR1,
		THIS_MODULE, 0, &card);
	if (ret < 0)
		return ret;

	picocalc->snd_card = card;
	strlcpy(card->driver, KBUILD_MODNAME, sizeof(card->driver));
	strlcpy(card->shortname, "picocalc-snd-pwm", sizeof(card->shortname));
	strlcpy(card->longname, "picocalc PWM audio", sizeof(card->longname));

	ret = snd_device_new(card, SNDRV_DEV_LOWLEVEL, picocalc, &ops);
	if (ret < 0)
		goto snd_error;

	ret = snd_pcm_new(card, card->driver, 0, 1, 0, &pcm);
	if (ret < 0)
		goto snd_error;

	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &picocalc_pcm_ops);
	snd_pcm_chip(pcm) = picocalc;
	pcm->info_flags = 0;
	snprintf(pcm->name, sizeof(pcm->name), "%s DAC", card->shortname);

	snd_pcm_lib_preallocate_pages_for_all(pcm,
				SNDRV_DMA_TYPE_CONTINUOUS,
				&picocalc->pdev->dev,
				8 * 1024, 8 * 1024);
	/*
	if (ret < 0)
		goto snd_error;
	*/

	ret = snd_card_register(card);
	if (ret == 0)
		return 0;

snd_error:
	snd_card_free(card);
	picocalc->snd_card = NULL;
	return ret;
}

static int picocalc_probe(struct platform_device *pdev)
{
	struct picocalc_snd_dev *picocalc;
	int ret;
    //int i;

	printk("picocalc_probe snd\n");
	picocalc = devm_kzalloc(&pdev->dev, sizeof(*picocalc), GFP_KERNEL);
	if (picocalc == NULL)
		return -ENOMEM;

	picocalc->pdev = pdev;
	spin_lock_init(&picocalc->lock);
          

    picocalc->duty_cycle_left_ns  = DEFAULT_DUTY_CYCLE;
    picocalc->duty_cycle_right_ns = DEFAULT_DUTY_CYCLE;
    picocalc->period_ns = DEFAULT_PERIOD;

    picocalc->pwm_left = devm_pwm_get(&pdev->dev, "pwm-snd-left");
    if (IS_ERR(picocalc->pwm_left))
    {
         printk(KERN_ERR" pwm_left, get pwm error!!\n");
         return -1;
    }

	picocalc->pwm_right = devm_pwm_get(&pdev->dev, "pwm-snd-right");
	if (IS_ERR(picocalc->pwm_right))
	{
		 printk(KERN_ERR" pwm_right, get pwm error!!\n");
		 return -1;
	}

/*
    pwm_config(picocalc->pwm_left, 1000000 / 2, 1000000); //1khz
    pwm_enable(picocalc->pwm_left);
    mdelay(2000);
    pwm_config(picocalc->pwm_left, 0, DEFAULT_PWM_PERIOD);
    pwm_disable(picocalc->pwm_left);
*/

    if (0 != picocalc_pwm_enable(picocalc))
    {
	ret = -EIO;
        dev_err(&picocalc->pdev->dev, "picocalc_pwm_enable failed!\n");

    }
    
	platform_set_drvdata(pdev, picocalc);
	//return 0;

	ret = picocalc_snd_register(picocalc);
	if (ret)
	{
        dev_err(&picocalc->pdev->dev, "picocalc_snd_register failed!\n");
		return ret;
	}

	platform_set_drvdata(pdev, picocalc);
	return 0;
}

static int picocalc_remove(struct platform_device *pdev)
{
	struct picocalc_snd_dev *picocalc = platform_get_drvdata(pdev);

    	picocalc_pwm_disable(picocalc);

	snd_card_free(picocalc->snd_card);
	picocalc->snd_card = NULL;
	return 0;
}

static struct platform_driver picocalc_snd_pwm_driver = {
	.driver		= {
		.name	= "picocalc_snd",
		.of_match_table = picocalc_snd_pwm_dt_ids,
	},
	.probe		= picocalc_probe,
	.remove		= picocalc_remove,
};

module_platform_driver(picocalc_snd_pwm_driver);