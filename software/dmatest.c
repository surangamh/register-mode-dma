#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "ps7_init.h"
#include <xil_io.h>
#include "xscugic.h"
#include "xparameters.h"
#include "addressparams.h"

#define NUM_OF_WORDS 64
#define FRAME_COUNT_MAX 5

XScuGic InterruptController;
static XScuGic_Config *GicConfig;
unsigned int frame_count = 0;

void InterruptHandler(void)
{
	//xil_printf("Interrupt triggered\n\r");
	// Clear the interrupt
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MM_DMASR, Xil_In32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MM_DMASR) | 0x1000);
	if (++frame_count>FRAME_COUNT_MAX) return;

	//Reprogram DMA transfer parameters
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MMDA, OFFSET_MEM_WRITE+4*NUM_OF_WORDS*frame_count);
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MM_LENGTH, 4*NUM_OF_WORDS);
}

int SetupInterruptSystem(XScuGic *xScuGicInstancePtr)
{
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, xScuGicInstancePtr);
	Xil_ExceptionEnable();
	return XST_SUCCESS;
}

int main()
{
    	init_platform();
    	ps7_post_config();

    	//Enable traffic generator
    	Xil_Out32(XPAR_TRAFFICGEN_0_S00_AXI_BASEADDR, 1);
    	Xil_Out32(XPAR_TRAFFICGEN_0_S00_AXI_BASEADDR+0x4, NUM_OF_WORDS);

    	// Initialize DMA (Set bits 0 and 12 of the DMA control register)
    	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR + OFFSET_S2MM_DMACR, Xil_In32(XPAR_AXI_DMA_0_BASEADDR + OFFSET_S2MM_DMACR) | 0x1001);

    	//Interrupt system and interrupt handling
    	GicConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
    	if (NULL == GicConfig)
    	{
    		return XST_FAILURE;
    	}
    	int status = XScuGic_CfgInitialize(&InterruptController, GicConfig, GicConfig -> CpuBaseAddress);
    	if (status != XST_SUCCESS)
    	{
    		return XST_FAILURE;
    	}
    	status = SetupInterruptSystem(&InterruptController);
    	if (status != XST_SUCCESS)
    	{
    		return XST_FAILURE;
    	}
    	status = XScuGic_Connect(&InterruptController, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, (Xil_ExceptionHandler)InterruptHandler, NULL);
    	if (status != XST_SUCCESS)
    	{
    		return XST_FAILURE;
    	}
    	XScuGic_Enable(&InterruptController, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

    	//Program DMA transfer parameters (i) destination address (ii) length
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MMDA, OFFSET_MEM_WRITE);
	Xil_Out32(XPAR_AXI_DMA_0_BASEADDR+OFFSET_S2MM_LENGTH, 4*NUM_OF_WORDS);

    	cleanup_platform();
    	for (int i=0; i<512; i++){
    		xil_printf("DDR Value : %d\n\r", Xil_In32(OFFSET_MEM_WRITE +4*i));
    	}
    	return 0;
}

