#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <vector_types.h>
#include <vector_functions.h>

#define IMAGE_DIM 2048
#define BOX_SIZE 1
#define ITERATIONS 100
#define NUMBER_OF_SAMPLES (((BOX_SIZE*2)+1)*((BOX_SIZE*2)+1))

void output_image_file(uchar4* image);
void input_image_file(char* filename, uchar4* image);
void checkCUDAError(const char *msg);

typedef enum { STARTING_CODE, EXERCISE_01, EXERCISE_02, EXERCISE_03, EXERCISE_04 } EXERCISE;

//The exercise mode can be set via pre-processor or by setting the `exercise` variable 
#ifdef EXERCISE_MODE
EXERCISE exercise = EXERCISE_MODE;
#elif
EXERCISE exercise = STARTING_CODE;
#endif

__global__ void image_blur_columns(uchar4 *image, uchar4 *image_output) {

	// map from threadIdx/BlockIdx to pixel row position
	int y = threadIdx.x + blockIdx.x * blockDim.x;

	//loop over columns
	for (int x = 0; x < IMAGE_DIM; x++){

		//calculate the input/output location
		int output_offset = x + y * IMAGE_DIM;
		uchar4 pixel;
		float4 average = make_float4(0, 0, 0, 0);

		for (int i = -BOX_SIZE; i <= BOX_SIZE; i++){
			for (int j = -BOX_SIZE; j <= BOX_SIZE; j++){
				int x_offset = x + i;
				int y_offset = y + j;
				//bounds check
				if ((x_offset < 0) || (x_offset >= IMAGE_DIM) || (y_offset < 0) || (y_offset >= IMAGE_DIM)){
					pixel = make_uchar4(0, 0, 0, 0);
				}
				else{
					//load pixel neighbour
					int offset = x_offset + y_offset * IMAGE_DIM;
					pixel = image[offset];
				}

				//sum values
				average.x += pixel.x;
				average.y += pixel.y;
				average.z += pixel.z;
			}
		}
		//calculate average
		average.x /= (float)NUMBER_OF_SAMPLES;
		average.y /= (float)NUMBER_OF_SAMPLES;
		average.z /= (float)NUMBER_OF_SAMPLES;

		image_output[output_offset].x = (unsigned char)average.x;
		image_output[output_offset].y = (unsigned char)average.y;
		image_output[output_offset].z = (unsigned char)average.z;
		image_output[output_offset].w = 255;
	}
}

/* Host code */

int main(void) {
	unsigned int image_size, i;
	uchar4 *d_image, *d_image_output, *d_image_temp;
	uchar4 *h_image;
	cudaEvent_t start, stop;
	float3 ms; //[0]=normal,[1]=tex1d,[2]=tex2d

	image_size = IMAGE_DIM*IMAGE_DIM*sizeof(uchar4);

	// create timers
	cudaEventCreate(&start);
	cudaEventCreate(&stop);

	// allocate memory on the GPU for the output image
	cudaMalloc((void**)&d_image, image_size);
	cudaMalloc((void**)&d_image_output, image_size);
	checkCUDAError("CUDA malloc");

	// allocate and load host image
	h_image = (uchar4*)malloc(image_size);
	input_image_file("input.ppm", h_image);

	switch (exercise){
	case(STARTING_CODE) : {
							  printf("Exercise Mode: Starting Code.\n");
                              // 1d by row
							  cudaEventRecord(start, 0);
							  dim3    blocksPerGrid(IMAGE_DIM / 16, 1);
							  dim3    threadsPerBlock(16, 1);
							  // loop for number of iterations
							  for (i = 0; i < ITERATIONS; i++){
								  // copy image to device memory
								  cudaMemcpy(d_image, h_image, image_size, cudaMemcpyHostToDevice);
								  checkCUDAError("CUDA memcpy to device");

								  image_blur_columns << <blocksPerGrid, threadsPerBlock >> >(d_image, d_image_output);
								  checkCUDAError("kernel starting code implementation");

								  //copy results back to host
								  cudaMemcpy(h_image, d_image_output, image_size, cudaMemcpyDeviceToHost);
								  checkCUDAError("CUDA memcpy to host");

							  }
							  cudaEventRecord(stop, 0);
							  cudaEventSynchronize(stop);
							  cudaEventElapsedTime(&ms.x, start, stop);
							  break;
	}
	case(EXERCISE_01) : {
                            printf("Exercise Mode: Exercise 01.\n");
							cudaEventRecord(start, 0);
							dim3    blocksPerGrid(IMAGE_DIM / 16, 1);
							dim3    threadsPerBlock(16, 1);

							//TODO: Complete exercise 01

							cudaEventRecord(stop, 0);
							cudaEventSynchronize(stop);
							cudaEventElapsedTime(&ms.x, start, stop);
							break;
	}
	case(EXERCISE_02) : {
							printf("Exercise Mode: Exercise 02.\n");
                            cudaEventRecord(start, 0);
							dim3    blocksPerGrid(IMAGE_DIM / 16, 1);
							dim3    threadsPerBlock(16, 1);

							//TODO: Complete exercise 02

							cudaEventRecord(stop, 0);
							cudaEventSynchronize(stop);
							cudaEventElapsedTime(&ms.x, start, stop);
							break;
	}
	case(EXERCISE_03) : {
							printf("Exercise Mode: Exercise 03.\n");
                            cudaEventRecord(start, 0);
							dim3    blocksPerGrid(IMAGE_DIM / 16, IMAGE_DIM / 16);
							dim3    threadsPerBlock(16, 16);

							//TODO: Complete exercise 03

							cudaEventRecord(stop, 0);
							cudaEventSynchronize(stop);
							cudaEventElapsedTime(&ms.x, start, stop);
							break;
	}
	}

	//output timings
	printf("Execution times:\n");
	printf("\tNormal version: %f\n", ms.x);

	// output image
	output_image_file(h_image);

	//cleanup
	cudaEventDestroy(start);
	cudaEventDestroy(stop);
	cudaFree(d_image);
	cudaFree(d_image_output);
	free(h_image);

	return 0;
}

void output_image_file(uchar4* image)
{
	FILE *f; //output file handle

	//open the output file and write header info for PPM filetype
	f = fopen("output.ppm", "wb");
	if (f == NULL){
		fprintf(stderr, "Error opening 'output.ppm' output file\n");
		exit(1);
	}
	fprintf(f, "P6\n");
	fprintf(f, "# COM4521 Lab 05 Exercise02\n");
	fprintf(f, "%d %d\n%d\n", IMAGE_DIM, IMAGE_DIM, 255);
	for (int x = 0; x < IMAGE_DIM; x++){
		for (int y = 0; y < IMAGE_DIM; y++){
			int i = x + y*IMAGE_DIM;
			fwrite(&image[i], sizeof(unsigned char), 3, f); //only write rgb (ignoring a)
		}
	}

	fclose(f);
}

void input_image_file(char* filename, uchar4* image)
{
	FILE *f; //input file handle
	char temp[256];
	unsigned int x, y, s;

	//open the input file and write header info for PPM filetype
	f = fopen("input.ppm", "rb");
	if (f == NULL){
		fprintf(stderr, "Error opening 'input.ppm' input file\n");
		exit(1);
	}
	fscanf(f, "%s\n", &temp);
	fscanf(f, "%d %d\n", &x, &y);
	fscanf(f, "%d\n", &s);
	if ((x != y) && (x != IMAGE_DIM)){
		fprintf(stderr, "Error: Input image file has wrong fixed dimensions\n");
		exit(1);
	}

	for (int x = 0; x < IMAGE_DIM; x++){
		for (int y = 0; y < IMAGE_DIM; y++){
			int i = x + y*IMAGE_DIM;
			fread(&image[i], sizeof(unsigned char), 3, f); //only read rgb
			//image[i].w = 255;
		}
	}

	fclose(f);
}

void checkCUDAError(const char *msg)
{
	cudaError_t err = cudaGetLastError();
	if (cudaSuccess != err)
	{
		fprintf(stderr, "CUDA ERROR: %s: %s.\n", msg, cudaGetErrorString(err));
		exit(EXIT_FAILURE);
	}
}
