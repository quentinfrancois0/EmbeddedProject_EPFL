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
#define ONE_FRAME (320*240*2)

int main()
{
	/*
	FILE* test;
	test = fopen("/mnt/host/test.txt","w");

	uint16_t j = 0;
	for (uint32_t i = 0; i < 100; i += 2)
	{
		uint32_t addr = HPS_0_BRIDGES_BASE + i;

		// Write through address span expander
		IOWR_16DIRECT(addr, 0, j);

		// Read through address span expander
		uint16_t readdata = IORD_16DIRECT(addr, 0);

		fprintf(test, "%" PRIu16 "\n", readdata);

		j++;
	}

	fclose(test);
	*/

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
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x00);
	//Start Address = 0x00000000
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x01, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x02, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x03, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x04, 0x00);
	//Length = 320*240 = 0x00012C00
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x05, 0x00);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x06, 0x2C);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x07, 0x01);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x08, 0x00);
	//Status
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x09, 0x00);

	//START EVERYTHING
	cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x01);

	//WAIT FOR A WHILE
	/*
	while(IORD(CAMERA_CONTROLLER_0_BASE, 0x09) != 0x01)
	{
		printf("%" PRIu8 "\n", IORD(CAMERA_CONTROLLER_0_BASE, 0x09));
	}
	*/
	//for (int i = 0; i < 100000; i++) {}
	usleep(100000);

	//STOP EVERYTHING
	IOWR(CAMERA_CONTROLLER_0_BASE, 0x00, 0x00);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);

	usleep(100000);

	//READ THE IMAGE IN THE MEMORY
	FILE* data;
	data = fopen("/mnt/host/data.txt","w");

	uint16_t readdata = 0x0000;

	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
			// Read through address span expander
			readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE, i);

			fprintf(data, "%" PRIu32 " : %" PRIu16 "\n", i, readdata);
	}

	fclose(data);


	printf("FINI !!!");

	return EXIT_SUCCESS;
}
