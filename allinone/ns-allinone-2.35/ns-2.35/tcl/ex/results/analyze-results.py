# used to analyze the results of a simulation
# command line arguments:
#   1: experiment number, to match to the correct directory
#   2: dependent variable axis label
import numpy as np
import matplotlib.pyplot as plt
import sys

expnum = sys.argv[1]
varaxis = sys.argv[2]

results = np.loadtxt('exp'+str(expnum)+'/results.tr')

################### plot total throughput against dependent variable ##################
fig = plt.figure()
plt.plot(results[:,0], results[:,1])
plt.title('Total throughput over the main link')
plt.xlabel(varaxis)
plt.ylabel('Megabits/sec')
plt.savefig('exp'+str(expnum)+'/totalThroughput.png', bbox_inches='tight')

################### plot average queue length against dependent variable ##################
fig = plt.figure()
plt.plot(results[:,0], results[:,2])
plt.title('Average queue length from source to sink')
plt.xlabel(varaxis)
plt.ylabel('packets')
plt.savefig('exp'+str(expnum)+'/avgQueueLen.png', bbox_inches='tight')