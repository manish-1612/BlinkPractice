//
//  util.c
//  Bubble Beat
//
//  Created by Scott McCoid on 12/15/12.
//
//

#include <stdio.h>
#include <math.h>
#include "util.h"

float halfwaveRectify(float value)
{
    return (value + fabsf(value) / 2);
}