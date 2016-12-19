// ONLY SOME CODE    NOT RUNNABLE

// NOTE TO RUN THIS CODE THERE IS A SMALL THING TO DO AS EXPLAINED IN LAB4 PDF 
// MOREOVER IT ONLY RUN IN DEBUG MODE (??? WHY ???)


#include <stdio.h>
#include <stdlib.h>


//THIS IS IN THE MAIN FUNCTION
  char* filename = "/mnt/host/crazy_wall.bin" ;
  RAM_Init_Pic(0,filename);  // CAN TAKE UP TO 1 MINUTE | 0 IS HERE EQUAL TO HPS_0_BRIDGES_BASE
  char* filename2 = "/mnt/host/belgium.bin" ;
  RAM_Init_Pic(5*4*160*240,filename2);
  char* filename3 = "/mnt/host/lakeside.bin" ;
  RAM_Init_Pic(10*4*160*240,filename3);
  
  
//THIS A FUNCTION THAT WRITE A PIC IN MEMORY 

void RAM_Init_Pic(uint32_t start, char* filename ){


	FILE *foutput = NULL;
	foutput = fopen(filename, "rb");
	if (!foutput){
		printf("Error: could not open \"%s\" for reading\n", filename);
	}

	printf("in ram file open\n");
	for (uint32_t i = start; i < 160*240*sizeof(uint32_t)+start; i += sizeof(uint32_t)) {

			unsigned char buffer[4];

			fread(buffer,sizeof(buffer),1,foutput);

	        uint32_t addr = HPS_0_BRIDGES_BASE + i;

	        
	        uint32_t writedata = (buffer[0]<<24) + (buffer[1]<<16) + (buffer[2]<<8) + buffer[3];
	        IOWR_32DIRECT(addr, 0, writedata);

	        // Read through address span expander
	        uint32_t readdata = IORD_32DIRECT(addr, 0);

	        // Check if read data is equal to written data
	        assert(writedata == readdata);
	}

}