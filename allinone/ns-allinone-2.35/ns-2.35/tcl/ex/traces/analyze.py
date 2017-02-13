# used to analyze different parts of the trace files
import numpy as np
import matplotlib.pyplot as plt
import sys

path_to_experiment = sys.argv[1]

trace_data = np.loadtxt('mytrace.tr')
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
plt.savefig(path_to_experiment+'/window_sizes.png', bbox_inches='tight')

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
plt.savefig(path_to_experiment+'/queue_length.png', bbox_inches='tight') 

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
plt.savefig(path_to_experiment+'/queue_drops.png', bbox_inches='tight')

################### plot pauses generated ##################
fig = plt.figure()
pauses_col = 9
plt.plot(trace_data[:,0], trace_data[:,pauses_col])
# axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
# axes.set_ylim([0,10])
plt.title('Pauses generated at main link')
plt.xlabel('time (s)')
plt.ylabel('cumulative pause packets')
plt.savefig(path_to_experiment+'/pauses_sent.png', bbox_inches='tight') 

################## plot instantaneous throughputs ##################
fig = plt.figure()
plt.plot(thr_data[:,0], thr_data[:,1], label='total') #plot total throughput
axes = plt.gca()
# axes.set_xlim([0.4, 0.8])
axes.set_ylim([0,20000])
fids = [0, 1, 2]
thr_col_offset = 2
for fid in fids:
    plt.plot(thr_data[:,0], thr_data[:,fid+thr_col_offset], label='fid '+str(fid))
axes = plt.gca()
plt.title('instantaneous throughputs')
plt.xlabel('time (s)')
plt.ylabel('throughput (Mbps)')
plt.legend()
plt.savefig(path_to_experiment+'/inst_throughputs.png', bbox_inches='tight')

################## plot makeup of the queue ##################
fig = plt.figure()
fids = [0, 1, 2]
input_col_offset = 10
for fid in fids:
    plt.plot(trace_data[:,0], trace_data[:,fid+input_col_offset], label='fid '+str(fid))
axes = plt.gca()
axes.set_xlim([1.3, 1.31])
plt.title('makeup of the queue')
plt.xlabel('time (s)')
plt.ylabel('packets')
plt.legend()
plt.show()

# plt.savefig(path_to_experiment+'/queue_makeup.png', bbox_inches='tight')

# ################## plot source queues lengths ##################
# fig = plt.figure()
# fids = [0, 1, 2]
# sourceq_col_offset = 13
# for fid in fids:
#     plt.plot(trace_data[:,0], trace_data[:,fid+sourceq_col_offset], label='fid '+str(fid))
# axes = plt.gca()
# axes.set_xlim([0.48, 0.6])
# plt.title('source queue lengths')
# plt.xlabel('time (s)')
# plt.ylabel('packets')
# plt.legend()
# # fig.show()
# plt.savefig(path_to_experiment+'/source_queue_len.png', bbox_inches='tight')

