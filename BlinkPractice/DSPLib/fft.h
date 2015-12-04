//
//
//	fft.h
//	DSPLib
//
//	author: scott 
//	[sonic apps union]
//	
//	description: This is a general fft api for iOS programming using vDSP
//	
//

#ifndef DSPLIB_FFT
#define DSPLIB_FFT

#include "constants.h"
#include "util.h"
#include <assert.h>
#include <stdlib.h>

#import <Accelerate/Accelerate.h>

// FFT Manager type structure
typedef struct t_fft
{
	int             size;
	int             sizeOverTwo;
	float			normalize;
	vDSP_Length 	logTwo;
	float*			window;
	FFTSetup		fftSetup;
} FFT;

// FFT Frame type structure
typedef struct t_fftFrame
{
	FFT*			fft;			// pointer to fft manager	
	COMPLEX_SPLIT	buffer;			// buffer of the complex values
} FFT_FRAME;

//------ Function Declarations -------//

// FFT Manager memory management API functions
FFT* newFFT(int size);
void freeFFT(FFT* fft);

// FFT_FRAME memory management
FFT_FRAME* newFFTFrame(FFT* fft);
void freeFFTFrame(FFT_FRAME* frame);

// FFT computation functions
void fft(FFT_FRAME* fftFrame, float* audioBuffer);       // Out of place fft
void fftIp(FFT* fftObject, float* audioBuffer);          // In place fft (i.e. just replaces audiobuffer with fft contents
void ifft(FFT_FRAME* fftFrame, float* outputBuffer);

// Windowing
void createWindow(FFT* fft, int windowType);

// FFT Transformations (TODO: Generalize in the future) -> out of place magnitude calculation
void magnitude(COMPLEX_SPLIT* inputBuffer, float* outputBuffer, int size);



#endif

