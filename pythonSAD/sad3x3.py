#!/usr/bin/python3

from PIL import Image
import array
import time
import sys
import argparse
from ctypes import *
import numpy

# constant variables
window = 3 # Window size, i.e. "3" -> 3x3 window
win = 1 # win is the number of pixels above, below, right, & left of center pixel

ncol_c = 19 # Number of columns in the search image
nrow_c = 4  # Number of rows in the search image

PIXEL_CNT  = 57 # Number of pixels sent to the Template and Search Arrays, each.
DISP_RANGE = 16 # Disparity range 0-15
DISP_ROW   = 2  # Number of disparity values for an entire row, to be sent back to comp.

# template array
templateBuff = bytearray([0x02, 0x05, 0x05, 0x03, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                          0x04, 0x00, 0x07, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                          0x07, 0x05, 0x09, 0x06, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                          0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01])

# search array
searchBuff = bytearray([0x02, 0x07, 0x05, 0x08, 0x06, 0x00, 0x02, 0x07, 0x05, 0x08, 0x06, 0x00, 0x02, 0x07, 0x05, 0x08, 0x06, 0x00, 0x00,
                        0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x00,
                        0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x00,
                        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01])

# sad array
sadArray = numpy.zeros((DISP_ROW, DISP_RANGE))

# SAD Algorithm
for i in range(DISP_ROW):
    for j in range(DISP_RANGE):
        sadArray[i][j] = \
               abs(templateBuff[0+i]           - searchBuff[0+i+j]) + \
               abs(templateBuff[1+i]           - searchBuff[1+i+j]) + \
               abs(templateBuff[2+i]           - searchBuff[2+i+j]) + \
               abs(templateBuff[0+ncol_c+i]      - searchBuff[0+ncol_c+i+j]) + \
               abs(templateBuff[1+ncol_c+i]      - searchBuff[1+ncol_c+i+j]) + \
               abs(templateBuff[2+ncol_c+i]      - searchBuff[2+ncol_c+i+j]) + \
               abs(templateBuff[0+ncol_c+ncol_c+i] - searchBuff[0+ncol_c+ncol_c+i+j]) + \
               abs(templateBuff[1+ncol_c+ncol_c+i] - searchBuff[1+ncol_c+ncol_c+i+j]) + \
               abs(templateBuff[2+ncol_c+ncol_c+i] - searchBuff[2+ncol_c+ncol_c+i+j])

# Print template array
print("begin template read")            
ndx = 0
for i in range(3):
    for j in range(19):
        print(templateBuff[ndx], end=" ")
        ndx += 1
    print("")

# Print search array
print("begin search read")            
ndx = 0
for i in range(3):
    for j in range(19):
        print(searchBuff[ndx], end=" ")
        ndx += 1
    print("")

# Print SAD array
print("reading from sad array 0")            
for ndx in range(16):
    print(int(sadArray[0][ndx]), end=" ")
print("")

print("reading from sad array 1")            
for ndx in range(16):
    print(int(sadArray[1][ndx]), end=" ")
print("")

# mins of each row
print(sadArray.min(axis=1))

# indices of each min per row
disparityArray = sadArray.argmin(axis=1)
print(disparityArray)



# NEXT ROW
# template array
templateBuff = bytearray([0x04, 0x00, 0x07, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                          0x07, 0x05, 0x09, 0x06, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                          0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01])

# search array
searchBuff = bytearray([0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x01, 0x07, 0x04, 0x02, 0x07, 0x09, 0x00,
                        0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x08, 0x04, 0x06, 0x08, 0x05, 0x03, 0x00,
                        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01])

# sad array
sadArray = numpy.zeros((DISP_ROW, DISP_RANGE))

# SAD Algorithm
for i in range(DISP_ROW):
    for j in range(DISP_RANGE):
        sadArray[i][j] = \
               abs(templateBuff[0+i]           - searchBuff[0+i+j]) + \
               abs(templateBuff[1+i]           - searchBuff[1+i+j]) + \
               abs(templateBuff[2+i]           - searchBuff[2+i+j]) + \
               abs(templateBuff[0+ncol_c+i]      - searchBuff[0+ncol_c+i+j]) + \
               abs(templateBuff[1+ncol_c+i]      - searchBuff[1+ncol_c+i+j]) + \
               abs(templateBuff[2+ncol_c+i]      - searchBuff[2+ncol_c+i+j]) + \
               abs(templateBuff[0+ncol_c+ncol_c+i] - searchBuff[0+ncol_c+ncol_c+i+j]) + \
               abs(templateBuff[1+ncol_c+ncol_c+i] - searchBuff[1+ncol_c+ncol_c+i+j]) + \
               abs(templateBuff[2+ncol_c+ncol_c+i] - searchBuff[2+ncol_c+ncol_c+i+j])

# Print template array
print("begin template read")            
ndx = 0
for i in range(3):
    for j in range(19):
        print(templateBuff[ndx], end=" ")
        ndx += 1
    print("")

# Print search array
print("begin search read")            
ndx = 0
for i in range(3):
    for j in range(19):
        print(searchBuff[ndx], end=" ")
        ndx += 1
    print("")

# Print SAD array
print("reading from sad array 0")            
for ndx in range(16):
    print(int(sadArray[0][ndx]), end=" ")
print("")

print("reading from sad array 1")            
for ndx in range(16):
    print(int(sadArray[1][ndx]), end=" ")
print("")

# mins of each row
print(sadArray.min(axis=1))

# indices of each min per row
disparityArray = sadArray.argmin(axis=1)
print(disparityArray)








