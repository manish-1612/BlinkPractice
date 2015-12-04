//
//  bark.c
//  Bubble Beat
//
//  Created by Scott McCoid on 12/15/12.
//
//

#include "bark.h"

int barkCenterFreq[26] = {0, 50, 150, 250, 350, 450, 570, 700, 840, 1000, 1170, 1370, 1600, 1850, 2150, 2500, 2900, 3400, 4000, 4800, 5800, 7000, 8500, 10500, 13500, 15500};

float bandWeightings[24] = { 0.7762, 0.6854, 0.6647, 0.6373, 0.6255, 0.6170, 0.6139, 0.6107, 0.6127, 0.6329, 0.6380, 0.6430, 0.6151, 0.6033, 0.5914, 0.5843, 0.5895, 0.5947, 0.6237, 0.6703, 0.6920, 0.7137, 0.7217, 0.7217 };

#pragma mark - Bark Memory Management - 

BARK* newBark(int windowSize, int sampleRate)
{
    BARK* bark = (BARK *)malloc(sizeof(BARK));
    if (bark == NULL)
        return NULL;
    
    assert(POWER_OF_TWO(windowSize));
    bark->windowSize = windowSize;
    bark->sampleRate = sampleRate;
    bark->halfWindowSize = windowSize / 2;
    
    newBarkBands(bark);
    
    bark->filteredOdd = (float *)calloc(bark->halfWindowSize, sizeof(float));
    bark->filteredEven = (float *)calloc(bark->halfWindowSize, sizeof(float));
    
    return bark;
}

void freeBark(BARK* bark)
{
    freeBarkBands(bark);
    free(bark->filteredOdd);
    free(bark->filteredEven);
    free(bark);
}

#pragma mark - Bark Band Memory Management -

void newBarkBands(BARK* bark)
{
    for (int i = 0; i < NUM_BARK_FILTER_BUFS; i++)
    {
        float halfWave = bark->halfWindowSize;
        bark->filterBands[i].band = (float *)malloc(halfWave * sizeof(float));
        
        for (int j = 0; j < bark->halfWindowSize; j++)
            bark->filterBands[i].band[j] = 0.0;
    }
    
}

void freeBarkBands(BARK* bark)
{
    for (int i = 0; i < NUM_BARK_FILTER_BUFS; i++)
        free(bark->filterBands[i].band);
}

#pragma mark - Filterbank Functions - 

void createBarkFilterbank(BARK* bark)
{
    float period = bark->sampleRate / bark->windowSize;
    int direction = 0;                     // direction is either +1 for increasing or -1 for decreasing
    
    float length, slope, point;
    
    // NUM_BARKS is still 24, but we have an array of length 26, so we've added lower and upper limits
    for (int i = 0; i < NUM_BARKS; i++)
    {
        for (int j = 0; j < bark->halfWindowSize; j++)
        {
            float frequency = period * j;
            
            if (frequency >= barkCenterFreq[i] && frequency < barkCenterFreq[i + 1])
            {
                direction = 1;
                length = barkCenterFreq[i + 1] - barkCenterFreq[i];
            }
            else if (frequency >= barkCenterFreq[i + 1] && frequency < barkCenterFreq[i + 2])
            {
                direction = -1;
                length = barkCenterFreq[i + 2] - barkCenterFreq[i + 1];
            }
            else
                direction = 0;  // this means we're over the bounds and don't want to deal with it
            
            if (direction != 0)
            {
                slope = direction / length;
                point = 1 - slope * barkCenterFreq[i + 1];
                
                bark->filterBands[i % 2].band[j] = slope * frequency + point;         // y = mx + b
            }
        }
    }
}

// TODO: fix this function, the analysis buffer will be in COMPLEX_SPLIT form
void multiplyBarkFilterbank(BARK* bark, float* analysis)
{
    vDSP_vmul(bark->filterBands[0].band, 1, analysis, 1, bark->filteredOdd, 1, bark->halfWindowSize);       // non overlapping bands starting at 0
    vDSP_vmul(bark->filterBands[1].band, 1, analysis, 1, bark->filteredEven, 1, bark->halfWindowSize);      // non overlapping bands starting at 50 (first bark center)
    vDSP_vadd(bark->filteredOdd, 1, bark->filteredEven, 1, analysis, 1, bark->halfWindowSize);
}

void iterateBarkBins(BARK* bark)
{    
    memcpy(bark->prevBarkBins, bark->barkBins, NUM_BARKS * sizeof(float));
}

# pragma mark - Bark Utility Functions -

// TODO: This is still a big bottle-neck in the processing chain
void condenseAnalysis(BARK* bark, float* analysis)
{
    float period = bark->sampleRate / bark->windowSize;
    
    for (int i = 0; i < NUM_BARKS; i++)
    {
        for (int j = 0; j < bark->halfWindowSize; j++)
        {
            float frequency = period * j;
            
            if (frequency >= barkCenterFreq[i] && frequency < barkCenterFreq[i + 2])
            {
                bark->barkBins[i] += analysis[j];
            }
            else if (frequency > barkCenterFreq[i + 2])
            {
                // If we're passed the upper threshold, then we can break out of this loop sooner
                break;
            }
        }
    }
}

void multiplyLoudness(BARK* bark)
{
    vDSP_vmul(bark->barkBins, 1, bandWeightings, 1, bark->barkBins, 1, NUM_BARKS);
}


