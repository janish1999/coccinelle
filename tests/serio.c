#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/serio.h>

static void serio_init_port(struct serio *serio)
{
	init_MUTEX(&serio->drv_sem);
}
