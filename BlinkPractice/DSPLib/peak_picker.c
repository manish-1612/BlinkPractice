//
//  peak_picker.c
//  Bubble Beat
//
//  author: jay
//  [sonic apps union]
//

#include "peak_picker.h"
#include "util.h"
#include <math.h>
#include "stdio.h"

PEAK_PICKER* newPeakPicker()
{
    PEAK_PICKER* peakPicker = (PEAK_PICKER *)malloc(sizeof(PEAK_PICKER));
    if (peakPicker == NULL)
        return NULL;
    
    peakPicker-> flag =                 0;
    peakPicker-> debounce_iterator =    0;
    peakPicker-> debounce_threshold =   5;
    
//    peakPicker-> u_threshold =          0.18;
    peakPicker->u_threshold =           0.3;
    peakPicker-> l_threshold =          0;
    peakPicker-> u_threshold_scale =    2;
    peakPicker-> l_threshold_scale =    2;
    
    peakPicker-> cof_threshold =        15;
    peakPicker-> cof_iterator =         0;
    peakPicker-> cof_flag =             0;
    peakPicker-> maskingDecay =         0.7;
    peakPicker-> masking_threshold =    10;
    peakPicker-> mask_iterator =        0;
    peakPicker-> mask_flag =            0;
    
    peakPicker-> firstQueue =           1;
    peakPicker-> queueIterator =        0;
    
    return peakPicker;
}

void freePP(PEAK_PICKER* pp)
{
    free(pp);
}

//void accumulate_bin_differences(PEAK_PICKER* pp, BARK* bark){
//    
//    float diff = 0;
//    int length = sizeof(bark->barkBins) / sizeof(float);
//    for (int i=0; i<length; i++) {
//        diff = diff + (bark->barkBins[i] - bark->prevBarkBins[i]);
//    }
////    for (int i=0; i<length; i++) {
////        diff = diff + pow(bark->barkBins[i] - bark->prevBarkBins[i], 2);
////    }
////
////    pp->bark_difference = sqrt(diff);
//    
//    pp->bark_difference = diff;
//    
//}

void accumulate_bin_differences(PEAK_PICKER* pp, BARK* bark)
{
    vDSP_vsub(bark->prevBarkBins, 1, bark->barkBins, 1, bark->prevBarkBins, 1, NUM_BARKS);
    vDSP_sve(bark->prevBarkBins, 1, &pp->bark_difference, NUM_BARKS);
}


//void accumulate_bin_differences(PEAK_PICKER* pp, BARK* bark)
//{
//    float absBinDiff[NUM_BARKS];
//    float halfWaveBin[NUM_BARKS];
//    //float scale = 0.5;
//    
//    vDSP_vsub(bark->prevBarkBins, 1, bark->barkBins, 1, bark->prevBarkBins, 1, NUM_BARKS);
//    
//    // halfwave portion ----
//    
//    // abs
//    vDSP_vabs(bark->prevBarkBins, 1, absBinDiff, 1, NUM_BARKS);
//    // sum
//    vDSP_vadd(bark->prevBarkBins, 1, absBinDiff, 1, halfWaveBin, 1, NUM_BARKS);
//    // divide by 2
//    //vDSP_vsmul(halfWaveBin, 1, &scale, halfWaveBin, 1, NUM_BARKS);
//    
//    // square
//    vDSP_vsq(halfWaveBin, 1, bark->prevBarkBins, 1, NUM_BARKS);
//    
//    
//    vDSP_sve(bark->prevBarkBins, 1, &pp->bark_difference, NUM_BARKS);
//}

void applyMask(PEAK_PICKER* pp){
    
    // check if flag is raised
    if (pp->mask_flag == 1) {
        
        //if so, but we've reached the masking threshold, lower flag
        if (pp->mask_iterator == pp->masking_threshold) {
            pp->mask_flag = 0;
            pp->mask_iterator = 0;
        }
        else{
            //otherwise, we'll multiply our feature by the decay a buncha times.
            //(this allows for a lot of decay initially and then not so much later)
            for (int i = 0; i < pp-> masking_threshold - pp-> mask_iterator; i++) {
                pp->bark_difference = pp->bark_difference * pp->maskingDecay;
            }
        }
        //iterate
        pp->mask_iterator++;
    }

}


void filterConsecutiveOnsets(PEAK_PICKER* pp){
    
    //check if flag is rasied
    if (pp->cof_flag == 1) {
        
        //if we've passed the threshold, lower it.
        if (pp->cof_iterator > pp-> cof_threshold) {
            pp-> cof_flag = 0;
            pp-> cof_iterator = 0;
        }
        
    //iterate
    else pp->cof_iterator++;
    }
}

void updateQueue(PEAK_PICKER* pp){
    
    if (pp->bark_difference >0) {
        
        pp->queue[pp->queueIterator] = pp->bark_difference;
        
        float sum = 0;
        for (int i =0; i< (pp->firstQueue ? pp->queueIterator : 100); i++) {
            sum += pp->queue[i];
        }
        
        pp->queueMean = sum / (float)(pp->firstQueue ? pp->queueIterator : 100.0);
        
        pp->u_threshold = pp->queueMean * pp->u_threshold_scale;
        pp->l_threshold = pp->queueMean * pp->l_threshold_scale;
        
        pp->queueIterator++;
        if (pp->queueIterator >= 100) {
            pp->queueIterator = 0;
            pp->firstQueue = 0;
        }
        
    }
 
}


int pickPeaks(PEAK_PICKER* pp){

    int onset = 0;
    
    switch (pp->flag) {
        case 0:
            //flag is down
            
            //if we're above the upper threshold...
            if (pp->bark_difference > pp->u_threshold) {
                
                //and we're not filtering consecutive onsets,
                if (pp->cof_flag == 0) {

                    //Let's flag this spot for a potential onset and hang on to that peak value if it ends up being one.
                    pp->flag = 1;
                    pp->debounce_iterator = 0;
                    pp->peak_value = pp->bark_difference;
                    
                }
            }
            
            //otherwise, we'll keep waiting for an onset
            
            break;
            
        case 1:
            //flag is up
            
            
            //did we go higher above the threshold?
            if (pp->bark_difference > pp->peak_value) {
                
                if (pp->cof_flag == 0) {
                    
                    //flag this as a better estimate for the onset
                    
                    pp->flag = 1;
                    pp->debounce_iterator = 0;
                    pp->peak_value = pp->bark_difference;
                    
                }
            }
            
            //if not...
            else{
                
                //Have we gone beyond our debouncing window?
                if (pp->debounce_iterator > pp->debounce_threshold) {
                    
                    if (pp->cof_flag ==0) {
                        
                        //onset verified!
                        
                        // TODO: communicate with view controller
                        onset = 1;
                        //printf("onset!");
                        
                        pp->debounce_iterator = 0;
                        pp->flag = 0;
                        pp->cof_flag = 1;
                        pp->mask_flag = 1;
                        
                    }
                }
                
                else{
                    
                    //are we below our lower threshold?
                    if(pp->bark_difference < pp->l_threshold) {
                        
                        if (pp->cof_flag == 0) {
                            
                            //onset verified!
                            
                            //TODO: communicate with view controller
                            onset = 1;
                            //printf("onset!");
                            
                            pp->debounce_iterator=0;
                            pp->flag = 0;
                            pp->cof_flag = 1;
                            pp->mask_flag = 1;
                        }
                    }
                    
                    //we have a peak flagged, but we haven't increased or crossed the lower threshold yet.
                    //Lets wait a bit longer to make sure our tagged peak is an onset
                    
                    else pp->debounce_iterator++;
                    
                }
                
            }
            break;
    }
    
    //updateQueue(pp);
    return onset;
}










