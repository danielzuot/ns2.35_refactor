# used to analyze different parts of the trace files
import numpy as np
import matplotlib.pyplot as plt

trace_data = np.loadtxt('qfile.tr')
thr_data = np.loadtxt('thrfile.tr')

################### plot window sizes of specific flow ids ##################
fig = plt.figure()
fids = [0, 1, 2]
window_col_offset = 1
for fid in fids:
    plt.plot(trace_data[:,0], trace_data[:,fid+window_col_offset], label = 'fid '+str(fid))
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,100])
plt.title('Progression of TCP window sizes')
plt.xlabel('time (s)')
plt.ylabel('window size (packets)')
plt.legend()
plt.show()  

################### plot queue length ##################
fig = plt.figure()
queue_length_col = 7
plt.plot(trace_data[:,0], trace_data[:,queue_length_col])
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,10])
plt.title('Queue length of main link')
plt.xlabel('time (s)')
plt.ylabel('queue length (packets)')
plt.legend()
plt.show()  

################### plot queue drops ##################
fig = plt.figure()
queue_drops_col = 8
plt.plot(trace_data[:,0], trace_data[:,queue_drops_col])
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,10])
plt.title('Queue drops at main link')
plt.xlabel('time (s)')
plt.ylabel('cumulative drops (packets)')
plt.legend()
plt.show()

################### plot pauses generated ##################
fig = plt.figure()
pauses_col = 9
plt.plot(trace_data[:,0], trace_data[:,queue_drops_col])
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,10])
plt.title('Pauses generated at main link')
plt.xlabel('time (s)')
plt.ylabel('cumulative pause packets')
plt.legend()
plt.show()  

################## plot instantaneous throughputs ##################
fig = plt.figure()
plt.plot(thr_data[:,0], thr_data[:,1], label='total') #plot total throughput
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,10])
fids = [0, 1, 2]
thr_col_offset = 2
for fid in fids:
    plt.plot(thr_data[:,0], thr_data[:,fid+thr_col_offset], label='fid '+str(fid))
axes = plt.gca()
plt.title('instantaneous throughputs')
plt.xlabel('time (s)')
plt.ylabel('throughput (Mbs)')
plt.legend()
plt.show()  


