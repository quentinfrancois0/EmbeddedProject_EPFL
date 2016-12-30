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
#include <inttypes.h>
#include <unistd.h>

#include "cmos_sensor_output_generator/cmos_sensor_output_generator.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator_regs.h"
#include "io.h"
#include "system.h"

#define ONE_KB (1024)

#define HPS_0_BRIDGES_SPAN 2*(320*240) /* address_span_expander span from system.h 320*240*2 bytes */

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
										   640,
										   480,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_FRAME_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_LINE_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_LINE_BLANK_MIN,
										   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_FRAME_BLANK_MIN);

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

	//START EVERYTHING
	cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x01);

	//WAIT FOR A WHILE
	//while(IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x09)!=0x01){};
	usleep(1000);

	//STOP EVERYTHING
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x00);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);

	//READ THE IMAGE IN THE MEMORY
	FILE* test;
	test = fopen("/mnt/host/data2.txt","w");


	for (uint32_t i = 0; i < HPS_0_BRIDGES_SPAN; i += sizeof(uint16_t))
	{
			uint32_t addr = HPS_0_BRIDGES_BASE + i;
			// Read through address span expander
			uint16_t readdata = IORD_16DIRECT(addr, 0);

			fprintf(test, "%" PRIu16 "\n", readdata);
	}

	/*
	for (int j = 0; j < 100; j++)
	{
		uint32_t addr = HPS_0_BRIDGES_BASE + j;
		uint16_t readdata = IORD_16DIRECT(addr, 0);
		fprintf(test, "%" PRIu16 "\n", readdata);
	}
	*/

	fclose(test);

	printf("FINI !!!");

	return EXIT_SUCCESS;
}
