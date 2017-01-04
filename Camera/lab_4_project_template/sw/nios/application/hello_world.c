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
	//FILE* test;
	//test = fopen("/mnt/host/test.txt","w");

	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
		// Write through address span expander
		IOWR_16DIRECT(HPS_0_BRIDGES_BASE, i, i);

		// Read through address span expander
		//uint16_t readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE, i);

		//fprintf(test, "%" PRIu16 "\n", readdata);
	}

	//fclose(test);

	//CAMERA INITIALISATION
	cmos_sensor_output_generator_dev cmos_sensor_output_generator = cmos_sensor_output_generator_inst(CMOS_SENSOR_OUTPUT_GENERATOR_0_BASE,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_PIX_DEPTH,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_WIDTH,
																									  CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_HEIGHT);
	cmos_sensor_output_generator_init(&cmos_sensor_output_generator);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);
	int config_success = cmos_sensor_output_generator_configure(&cmos_sensor_output_generator,
										   	   	   	   	   	   640,
										   	   	   	   	   	   480,
										   	   	   	   	   	   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_FRAME_BLANK_MIN,
										   	   	   	   	   	   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_LINE_BLANK_MIN,
										   	   	   	   	   	   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_LINE_BLANK_MIN,
										   	   	   	   	   	   CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_FRAME_BLANK_MIN);

	printf("CMOS Config = %d \n", config_success);

	//CAMERA CONTROLLER INITIALISATION
	//Stop the camera controller
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x00000000);
	//Reset the status register
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1, 0x00000000);
	//Start Address = 0x00000000
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x2, 0x00000000);
	//Length = 320*240*2 = 0x00025800
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x3, 0x00025800);

	//READ THE REGISTERS
	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0));
	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));
	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x2));
	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x3));

	//START EVERYTHING
	cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x00000001);

	//WAIT FOR A WHILE
	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));

	while(IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1) != 0x00000001) {}

	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));

	while(IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1) != 0x00000003) {}

	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));

	while(IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1) != 0x00000007) {}

	printf("%" PRIu32 "\n", IORD_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));

	//STOP EVERYTHING
	IOWR_32DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x00000000);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);

	//printf("%" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	//READ THE IMAGE IN THE MEMORY
	FILE* data;
	data = fopen("/mnt/host/data.txt","w");

	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
		// Read through address span expander
		uint16_t readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE, i);

		fprintf(data, "%" PRIu16 "\n", readdata);
		//fprintf(data, "%" PRIu32 " : %" PRIu16 "\n", i, readdata);
	}

	fclose(data);

	printf("FINI !!!");

	return EXIT_SUCCESS;
}
