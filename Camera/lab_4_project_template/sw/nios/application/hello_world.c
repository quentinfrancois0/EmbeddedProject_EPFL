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
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x00);
	//Reset the status register
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9, 0x00);
	//Start Address = 0x00000000
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1, 0x00);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x2, 0x00);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x3, 0x00);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x4, 0x00);
	//Length = 320*240*2 = 0x00025800
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x5, 0x00);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x6, 0x58);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x7, 0x02);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x8, 0x00);

	//READ THE REGISTERS
	printf("Start = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0));
	printf("StartAddress_1 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x1));
	printf("StartAddress_2 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x2));
	printf("StartAddress_3 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x3));
	printf("StartAddress_4 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x4));
	printf("Length_1 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x5));
	printf("Length_2 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x6));
	printf("Length_3 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x7));
	printf("Length_4 = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x8));
	printf("Status = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	//START EVERYTHING
	cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x01);

	//WAIT FOR THE ACQUISITION
	printf("Status = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	while(IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9) != 0x00000001) {}

	printf("Status = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	while(IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9) != 0x00000003) {}

	printf("Status = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	while(IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9) != 0x00000007) {}

	printf("Status = %" PRIu8 "\n", IORD_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x9));

	//STOP EVERYTHING
	IOWR_8DIRECT(CAMERA_CONTROLLER_0_BASE, 0x0, 0x00);
	cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);

	//READ THE FRAMES IN THE MEMORY
	FILE* data;
	data = fopen("/mnt/host/data.txt","w");

	uint16_t readdata = 0;
	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
		// Read through address span expander
		readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE, i);
		fprintf(data, "%" PRIu16 "\n", readdata);
		//fprintf(data, "%" PRIu32 " : %" PRIu16 "\n", i, readdata);
	}

	fclose(data);
	printf("FRAME 1 FINISHED \n");

	FILE* data2;
	data2 = fopen("/mnt/host/data2.txt","w");

	readdata = 0;
	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
		// Read through address span expander
		readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE + 0x00025800, i);
		fprintf(data2, "%" PRIu16 "\n", readdata);
		//fprintf(data, "%" PRIu32 " : %" PRIu16 "\n", i, readdata);
	}

	fclose(data2);
	printf("FRAME 2 FINISHED \n");

	FILE* data3;
	data3 = fopen("/mnt/host/data3.txt","w");

	readdata = 0;
	for (uint32_t i = 0; i < ONE_FRAME; i += sizeof(uint16_t))
	{
		// Read through address span expander
		readdata = IORD_16DIRECT(HPS_0_BRIDGES_BASE + 0x0004B000, i);
		fprintf(data3, "%" PRIu16 "\n", readdata);
		//fprintf(data, "%" PRIu32 " : %" PRIu16 "\n", i, readdata);
	}

	fclose(data3);
	printf("FRAME 3 FINISHED \n");

	printf("FRAMES COMPUTED !!!");
	return EXIT_SUCCESS;
}
