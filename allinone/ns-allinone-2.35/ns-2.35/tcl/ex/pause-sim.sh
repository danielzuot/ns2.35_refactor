#!/bin/sh

# Run simulations to show the impact of a decreasing DCTCP marking threshold

expNum=$1
#now=$(date +%Y%m%d%H%M%S)
for K in $(seq 15 -1 5); do
    ns pause-dumbbell.tcl $expNum $K
done
# for K in $(seq 9 -1 5); do
#     ns pause-dumbbell.tcl $expNum $K
# done

