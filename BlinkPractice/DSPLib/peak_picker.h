//
//  peak_picker.h
//  Bubble Beat
//
//  author: jay
//  [sonic apps union]
//
//

#ifndef Bubble_Beat_peak_picker_h
#define Bubble_Beat_peak_picker_h

#include <stdlib.h>
#include <assert.h>
#include "bark.h"

#import <Accelerate/Accelerate.h>

typedef struct t_peak_picker {
    float   u_threshold, l_threshold;
    float   bark_difference;
    float   peak_value;
    int    flag;
    int     debounce_iterator, debounce_threshold;
    int     cof_threshold, cof_iterator;
    int    cof_flag;
    float   l_threshold_scale, u_threshold_scale;
    int     masking_threshold;
    float   maskingDecay;
    int    mask_flag;
    int     mask_iterator;
    int    automatic_thresholding;
    double queue[100];
    int    firstQueue;
    int     queueIterator;
    float   queueMean;
    
} PEAK_PICKER;

PEAK_PICKER* newPeakPicker();
void accumulate_bin_differences(PEAK_PICKER* pp, BARK* bark);
void applyMask(PEAK_PICKER* pp);
void filterConsecutiveOnsets(PEAK_PICKER* pp);
int pickPeaks(PEAK_PICKER* pp);
void freePP(PEAK_PICKER *pp);
void updateQueue();

#endif
