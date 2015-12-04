//
//
//	fft.c
//	DSPLib
//
//	author: scott 
//	[sonic apps union]
//	
//	description: This is a general fft api for iOS programming using vDSP
//	
//

#include "fft.h"


#pragma mark - New FFT -

FFT* newFFT(int size)
{
    FFT* fft = (FFT*)malloc(sizeof(FFT));
    if (fft == NULL)
        return NULL;
    
    // Check if the size is a power of two
    assert(POWER_OF_TWO(size));
    fft->size = size;
    fft->sizeOverTwo = fft->size / 2;
    fft->normalize = 1.0 / (2.0 * fft->size);
    
    // create fft setup
    fft->logTwo = log2f(fft->size);
    fft->fftSetup = vDSP_create_fftsetup(fft->logTwo, FFT_RADIX2);
    
    if (fft->fftSetup == 0)
    {
        freeFFT(fft);
        return NULL;
    }

    fft->window = NULL;
    
    return fft;
}

void freeFFT(FFT* fft)
{
	// destroy the fft setup object
	vDSP_destroy_fftsetup(fft->fftSetup);
	// if the window exists, destroy it
	if (fft->window != NULL)
		free(fft->window);
	// actually free the fft
	free(fft);
}

#pragma mark - New FFT Frame -

FFT_FRAME* newFFTFrame(FFT* fft)
{
	FFT_FRAME* frame = (FFT_FRAME*)malloc(sizeof(FFT_FRAME));
    if (frame == NULL)
        return NULL;

    // Lastly, allocate memory for complex buffer
    frame->buffer.realp = (float *)malloc(fft->sizeOverTwo * sizeof(float));
    frame->buffer.imagp = (float *)malloc(fft->sizeOverTwo * sizeof(float));
    if (frame->buffer.realp == NULL || frame->buffer.imagp == NULL)
        return NULL;
    
    // setting frame fft pointer to fft
    frame->fft = fft;
    
    return frame;
}

void freeFFTFrame(FFT_FRAME* frame)
{
	frame->fft = NULL;
	free(frame->buffer.realp);
	free(frame->buffer.imagp);
	free(frame);
}

#pragma mark - Perform Foward / Reverse FFT -

void fft(FFT_FRAME* frame, float* audioBuffer)
{
	FFT* fft = frame->fft;
    
    // Do some data packing stuff
    vDSP_ctoz((COMPLEX*)audioBuffer, 2, &frame->buffer, 1, fft->sizeOverTwo);
    
    // This applies the windowing
    if (fft->window != NULL)
    	vDSP_vmul(audioBuffer, 1, fft->window, 1, audioBuffer, 1, fft->size);
    
    // Actually perform the fft
    vDSP_fft_zrip(fft->fftSetup, &frame->buffer, 1, fft->logTwo, FFT_FORWARD);
    
    // Do some scaling
    vDSP_vsmul(frame->buffer.realp, 1, &fft->normalize, frame->buffer.realp, 1, fft->sizeOverTwo);
    vDSP_vsmul(frame->buffer.imagp, 1, &fft->normalize, frame->buffer.imagp, 1, fft->sizeOverTwo);
    
    // Zero out DC offset
    frame->buffer.imagp[0] = 0.0;
}

void fftIp(FFT* fftObject, float* audioBuffer)
{
    // Creating pointer of COMPLEX_SPLIT to use in calculations (points to same data as audioBuffer)
    COMPLEX_SPLIT* fftBuffer = (COMPLEX_SPLIT *)&audioBuffer[0];
    
    // Apply windowing
    if (fftObject->window != NULL)
        vDSP_vmul(audioBuffer, 1, fftObject->window, 1, audioBuffer, 1, fftObject->size);
    
    // This seems correct-ish TODO: check casting
    vDSP_ctoz((COMPLEX*)audioBuffer, 2, fftBuffer, 1, fftObject->sizeOverTwo);
    
    // Perform fft
    vDSP_fft_zrip(fftObject->fftSetup, fftBuffer, 1, fftObject->logTwo, FFT_FORWARD);
    
    // Do scaling
    vDSP_vsmul(fftBuffer->realp, 1, &fftObject->normalize, fftBuffer->realp, 1, fftObject->sizeOverTwo);
    vDSP_vsmul(fftBuffer->imagp, 1, &fftObject->normalize, fftBuffer->imagp, 1, fftObject->sizeOverTwo);
    
    // zero out DC offset
    fftBuffer->imagp[0] = 0.0;
}

void ifft(FFT_FRAME* frame, float* outputBuffer)
{
    // get pointer to fft object
    FFT* fft = frame->fft;

    // perform in-place fft inverse
    vDSP_fft_zrip(fft->fftSetup, &frame->buffer, 1, fft->logTwo, FFT_INVERSE);
    
    // The output signal is now in a split real form.  Use the  function vDSP_ztoc to get a split real vector. 
    vDSP_ztoc(&frame->buffer, 1, (COMPLEX *)outputBuffer, 2, fft->sizeOverTwo);
    
    // This applies the windowing
    if (fft->window != NULL)
    	vDSP_vmul(outputBuffer, 1, fft->window, 1, outputBuffer, 1, fft->size);
}

#pragma mark - Windowing -

void createWindow(FFT* fft, int windowType)
{
	// allocate memory for a window
	if (fft->window == NULL)
    	fft->window = (float *)malloc(fft->size * sizeof(float));

    switch (windowType)
    {
    	case HANN:
    		vDSP_hann_window(fft->window, fft->size, vDSP_HANN_NORM);
    		break;

    	case HAMM:
    		vDSP_hamm_window(fft->window, fft->size, 0);        // 0 is the full window
    		break;

    	default:
    		break;
    }
}


void magnitude(COMPLEX_SPLIT* inputBuffer, float* outputBuffer, int size)
{
    vDSP_vdist(inputBuffer->realp, 1, inputBuffer->imagp, 1, outputBuffer, 1, size);
}