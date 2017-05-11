import numpy as np
import matplotlib.pyplot as plt
import sys
import os
import math

log_home = os.path.join(os.path.expanduser('~'), 'MIT/urop/alizadeh/ns2.35_refactor/allinone/logs')

pfabric_logs = '331-search-pfabric'
tcp_logs = '419-search-tcp'
dctcp_logs = '421-search-dctcp'

## normalized fct for flows with size in [lower, upper] bytes
def normalize_fcts(log_file, lower, upper):
    ### compute normalized FCTs ###
    flows = np.loadtxt(log_file)
    nflows = 0
    normed_sum = 0
    for flow in flows:
        fsize = flow[0] * 1460
        if fsize >= lower and fsize <= upper:
            nflows += 1
            server1 = flow[3]
            server2 = flow[4]
            pod1 = math.floor(server1/16)
            pod2 = math.floor(server2/16)
            prate = 1
            if pod1 == pod2:
                prate = 13.264e-6 + (flow[0]-1) *1500* 8/1e10
            else:
                prate = 14.68e-6 + (flow[0]-1) * 1500*8/1e10
            normed = flow[1] / prate
            normed_sum += normed
    return normed_sum / nflows



### first pfabric
pfabric_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_pfabric-s16-x1-q24-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-DropTail10000-minrto4.5e-05-droptrue-prio2-dqtrue-prob5-kotrue'.format(i, load)
    pfabric_log_file = '{}/{}/{}/{}'.format(log_home, pfabric_logs, exp, 'flow.tr')
    pfabric_fcts[i-1] = normalize_fcts(pfabric_log_file, 0, float("inf"))
    
### then dctcp
dctcp_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_dctcp-s16-x1-q150-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-RED15-minrto0.0002-dropfalse-prio2-dqfalse-prob0-kofalse'.format(i, load)
    dctcp_log_file = '{}/{}/{}/{}'.format(log_home, dctcp_logs, exp, 'flow.tr')
    dctcp_fcts[i-1] = normalize_fcts(dctcp_log_file, 0, float("inf"))

### then tcp
tcp_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_dctcp-s16-x1-q150-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-RED10000-minrto0.0002-dropfalse-prio2-dqfalse-prob0-kofalse'.format(i, load)
    tcp_log_file = '{}/{}/{}/{}'.format(log_home, tcp_logs, exp, 'flow.tr')
    tcp_fcts[i-1] = normalize_fcts(tcp_log_file, 0, float("inf"))

loads = np.linspace(0.1, 0.8, 8)
fig = plt.figure()
plt.plot(loads, pfabric_fcts, label='pFabric')
plt.plot(loads, dctcp_fcts, label='DCTCP')
plt.plot(loads, tcp_fcts, label='TCP-DropTail')
plt.title('Web search workload')
plt.xlabel('Load')
plt.ylabel('Normalized FCT')
plt.legend(loc='upper center')
plt.show()




### first pfabric
pfabric_large_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_pfabric-s16-x1-q24-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-DropTail10000-minrto4.5e-05-droptrue-prio2-dqtrue-prob5-kotrue'.format(i, load)
    pfabric_log_file = '{}/{}/{}/{}'.format(log_home, pfabric_logs, exp, 'flow.tr')
    pfabric_large_fcts[i-1] = normalize_fcts(pfabric_log_file, 10000000, float("inf"))
    
### then dctcp
dctcp_large_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_dctcp-s16-x1-q150-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-RED15-minrto0.0002-dropfalse-prio2-dqfalse-prob0-kofalse'.format(i, load)
    dctcp_log_file = '{}/{}/{}/{}'.format(log_home, dctcp_logs, exp, 'flow.tr')
    dctcp_large_fcts[i-1] = normalize_fcts(dctcp_log_file, 10000000, float("inf"))

### then tcp
tcp_large_fcts = [None] * 8
for i in range(1,9):
    load = 0.1 * i
    exp = '00{}-empirical_search_dctcp-s16-x1-q150-load{}-avesize1661480-mp0-DCTCP-Sack-ar1-SSRtrue-RED10000-minrto0.0002-dropfalse-prio2-dqfalse-prob0-kofalse'.format(i, load)
    tcp_log_file = '{}/{}/{}/{}'.format(log_home, tcp_logs, exp, 'flow.tr')
    tcp_large_fcts[i-1] = normalize_fcts(tcp_log_file, 10000000, float("inf"))

loads = np.linspace(0.1, 0.8, 8)
fig = plt.figure()
plt.plot(loads, pfabric_large_fcts, label='pFabric')
plt.plot(loads, dctcp_large_fcts, label='DCTCP')
plt.plot(loads, tcp_large_fcts, label='TCP-DropTail')
plt.title('Web search workload [10MB, infty]: Avg')
plt.xlabel('Load')
plt.ylabel('Normalized FCT')
plt.legend(loc='upper center')
plt.show()


