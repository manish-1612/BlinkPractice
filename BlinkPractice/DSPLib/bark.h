//
//  bark.h
//  DSPLib
//
//  author: scott
//	[sonic apps union]
//
//	description: This file defines all the functions and values associated
//  with the bark frequency bounds and filter banks
//
//
#ifndef DSPLIB_BARK
#define DSPLIB_BARK

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "constants.h"
#include "util.h"

#import <Accelerate/Accelerate.h>

#define NUM_BARKS 24
#define NUM_BARK_FILTER_BUFS 2


typedef struct t_bark_bin
{
    float*  band;
} BARK_BIN;


typedef struct t_bark
{
    BARK_BIN  filterBands[2];
    float     barkBins[NUM_BARKS];
    float     prevBarkBins[NUM_BARKS];
    float*    filteredOdd;
    float*    filteredEven;
    
    int       windowSize;
    int       halfWindowSize;
    int       sampleRate;
} BARK;


BARK* newBark(int windowSize, int sampleRate);
void freeBark(BARK* bark);

void newBarkBands(BARK* bark);
void freeBarkBands(BARK* bark);

void createBarkFilterbank(BARK* bark);
void multiplyBarkFilterbank(BARK* bark, float* analysis);

void iterateBarkBins(BARK* bark);

// Bark utility functions
void condenseAnalysis(BARK* bark, float* analysis);
void multiplyLoudness(BARK* bark);

#endif
