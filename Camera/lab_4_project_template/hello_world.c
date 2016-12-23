/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "cmos_sensor_output_generator/cmos_sensor_output_generator.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator_regs.h"
#include "io.h"
#include "system.h"

#define HPS_0_BRIDGES_SPAN (256 * 1024 * 1024) /* address_span_expander span from system.h (ADAPT TO YOUR DESIGN) */

#define ONE_MB (1024*1024)

#define CMOS_SENSOR_OUTPUT_GENERATOR_0_BASE       (0x10000820) /* cmos_sensor_output_generator base address from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_PIX_DEPTH  (12)     /* cmos_sensor_output_generator pix depth from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_WIDTH  (640)    /* cmos_sensor_output_generator max width from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_HEIGHT (480)    /* cmos_sensor_output_generator max height from system.h (ADAPT TO YOUR DESIGN) */

int main()
{
	//CAMERA INITIALISATION
	cmos_sensor_output_generator_dev cmos_sensor_output_generator = cmos_sensor_output_generator_inst(CMOS_SENSOR_OUTPUT_GENERATOR_0_BASE,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_PIX_DEPTH,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_WIDTH,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_HEIGHT);
	cmos_sensor_output_generator_init(&cmos_sensor_output_generator);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);
	cmos_sensor_output_generator_configure(&cmos_sensor_output_generator,
										   480,
										   640,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_FRAME_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_LINE_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_LINE_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_FRAME_BLANK_MIN);
	cmos_sensor_output_generator_start(&cmos_sensor_output_generator);

	//CAMERA CONTROLLER INITIALISATION
	//Start Address
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x01, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x02, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x03, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x04, 0x00);
	//Length = 320*240*16 = 0x0012C000
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x05, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x06, 0xC0);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x07, 0x12);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x08, 0x00);
	//Status
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x09, 0x00);
	//Start
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x01);

	while(IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x09)!=0x01){};

	//READ THE IMAGE IN THE MEMORY
	uint32_t megabyte_count = 0;
	FILE* test;
	test = fopen("test.txt","w");

	    for (uint32_t i = 0; i < HPS_0_BRIDGES_SPAN; i += sizeof(uint32_t)) {

	        // Print progress through 256 MB memory available through address span expander
	        if ((i % ONE_MB) == 0) {
	            printf("megabyte_count = %i \n", megabyte_count);
	            megabyte_count++;
	        }

	        uint32_t addr = HPS_0_BRIDGES_BASE + i;

	        // Read through address span expander
	        uint32_t readdata = IORD_32DIRECT(addr, 0);

	        fprintf(test, "%d\n", readdata);

	    }
	    fclose(test);

	return EXIT_SUCCESS;
}
