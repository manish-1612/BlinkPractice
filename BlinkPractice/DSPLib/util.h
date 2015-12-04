//
//
//	util.h
//	DSPLib
//
//	author: scott 
//	[sonic apps union]
//	
//	description: utility macros and functions for DSPLib
//	
//


#ifndef DSPLIB_UTIL
#define DSPLIB_UTIL

#define POWER_OF_TWO(x) ((x != 0) && ((x & (~x + 1)) == x))

float halfwaveRectify(float value);

#endif