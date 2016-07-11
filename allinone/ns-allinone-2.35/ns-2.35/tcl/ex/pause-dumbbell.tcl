set ns [new Simulator]

# EXPERIMENTS
# set resultsPath [file join "results" [lindex $argv 0] results.tr]
# set pauseThreshold [expr [lindex $argv 1]]

# PARAMETERS
set enable_pause 1
set enableNAM 0
set queueFile [open traces/queue.tr w]
set srcQueueFile [open traces/srcqueue.tr w]
set myTraceFile [open traces/mytrace.tr w]
set instThroughputFile [open traces/thrfile.tr w]
# set resultsFile [open $resultsPath a]
set traceSamplingInterval 0.00001  
set throughputSamplingInterval 0.001
set RTT 0.0005
set K 50
set inputLineRate 10Gbs
set simulationTime 1.5
set startMeasurementTime 0.8
set stopMeasurementTime 1.4
set classifyDelay 0.01
set throughputTraceStart 0.01
set f0Start 0.001
set f1Start 0.1
set f2Start 0.5
set burstInterval 0.005
set burstSize 1000
set pauseThreshold 20
set resumeThreshold 5
set pauseDuration 1 


assert [expr $simulationTime <= 1.5]
set ql_sum 0
set ql_n 0
set totalThroughput 0
# Sequence number wraps around otherwise

##### Transport defaults, like packet size ######
set DCTCP_g_ 0.0625
set ackRatio 1 
set packetSize 1460
Agent/TCP set packetSize_ $packetSize
Agent/TCP/FullTcp set segsize_ $packetSize

## Turn on DCTCP ##
set sourceAlg DC-TCP-Sack
source configs/dctcp-defaults.tcl
Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set packetSize_ $packetSize
Agent/TCP/FullTcp set segsize_ $packetSize
Agent/TCP set window_ 256
Agent/TCP set tcpTick_ 0.01
Agent/TCP set minrto_ 0.2 ; # minRTO = 200ms
Agent/TCP set windowOption_ 0

if {[string compare $sourceAlg "DC-TCP-Sack"] == 0} {
    Agent/TCP set dctcp_ true
    Agent/TCP set dctcp_g_ $DCTCP_g_;
}
Agent/TCP/FullTcp set segsperack_ $ackRatio; 
Agent/TCP/FullTcp set spa_thresh_ 3000;
Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $packetSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $K]
Queue/RED set maxthresh_ [expr $K]
             
DelayLink set avoidReordering_ true

# pause instrumentation and queue monitors
if {$enable_pause == 1} {
    puts "Pause enabled"
    Queue set limit_ 10000
} else {
    puts "Pause disabled"
    Queue set limit_ 1000
}

## Tracing Parameters ##
$ns color 0 Red
$ns color 1 Blue
$ns color 2 Green
if {$enableNAM != 0} {
    set namfile [open out.nam w]
    $ns namtrace-all $namfile
}


# Procedure to attach classifier to queues
# for nodes n1 and n2
proc attach-classifiers {ns n1 n2} {
    global pauseThreshold resumeThreshold pauseDuration
    set fwd_queue [[$ns link $n1 $n2] queue]
    $fwd_queue attach-classifier [$n1 entry]
    [$n1 entry] set enable_pause_ 1
    [$n1 entry] set pause_threshold_ $pauseThreshold
    [$n1 entry] set resume_threshold_ $resumeThreshold
    [$n1 entry] set pause_duration_ $pauseDuration


    set bwd_queue [[$ns link $n2 $n1] queue]
    $bwd_queue attach-classifier [$n2 entry]
    [$n2 entry] set enable_pause_ 1
    [$n2 entry] set pause_threshold_ $pauseThreshold
    [$n2 entry] set resume_threshold_ $resumeThreshold
    [$n2 entry] set pause_duration_ $pauseDuration
}

##### Topology ###########
#
#         0            1
#           \        / 
#        2 -- A -- B -- 3 
#           /        \ 
#         4            5   
#

set N 6
for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
}
set nsource [$ns node]
set nsink [$ns node]

# create links
# first the main link
$ns duplex-link $nsource $nsink $inputLineRate [expr ($RTT/ 2)] RED
$ns duplex-link-op $nsource $nsink queuePos 0.25
set qmon [$ns monitor-queue $nsource $nsink $queueFile $traceSamplingInterval]
if {$enable_pause == 1} {
  attach-classifiers $ns $nsource $nsink
}

for {set i 0} {$i < $N} {incr i} {
    if {$i % 2 == 0} {
      $ns simplex-link $nsource $n($i) $inputLineRate 0.000001 RED
      $ns simplex-link $n($i) $nsource $inputLineRate 0.000001 DropTail
      
      if {$enable_pause == 1} {
        attach-classifiers $ns $nsource $n($i)
      }
    } else {
      $ns simplex-link $nsink $n($i) $inputLineRate 0.000001 RED
      $ns simplex-link $n($i) $nsink $inputLineRate 0.000001 DropTail

      if {$enable_pause == 1} {
        attach-classifiers $ns $nsink $n($i)
      }
    }
}

# create qmons for the nicks into the network
for {set i 0} {$i < 3} {incr i} {
  set j [expr 2*$i]
  set source_qmon($i) [$ns monitor-queue $n($j) $nsource $srcQueueFile $traceSamplingInterval]
}
# create tcp connections: 0->1, 2->3, 4->5
for {set i 0} {$i < 3} {incr i} {
  set tcp($i) [new Agent/TCP/FullTcp/Sack]
  set sink($i) [new Agent/TCP/FullTcp/Sack]
  set source_num [expr 2 * $i]
  set sink_num [expr $source_num + 1]
  $ns attach-agent $n($source_num) $tcp($i)
  $ns attach-agent $n($sink_num) $sink($i)
  $sink($i) listen

  $ns connect $tcp($i) $sink($i)
  $tcp($i) set fid_ $i
}

#### Application: long-running FTP #####
for {set i 0} {$i < 3} {incr i} {
  set ftp($i) [new Application/FTP]
  $ftp($i) attach-agent $tcp($i)
}

# send a flow from 0 -> 1
$ns at $f0Start "$ftp(0) start"
$ns at [expr $f0Start+$classifyDelay] "classifyFlow 0"
$ns at [expr $simulationTime] "$ftp(0) stop"

# send a flow from 2 -> 3
$ns at $f1Start "$ftp(1) start"
$ns at [expr $f1Start+$classifyDelay] "classifyFlow 1"
$ns at [expr $simulationTime] "$ftp(1) stop"

# send a delayed, bursty flow from 4 -> 5
$ns at $f2Start "$ftp(2) produce $burstSize"
$ns at [expr $f2Start+$classifyDelay] "classifyFlow 2"
$ns at [expr $f2Start+$burstInterval] "sendBursts"
$ns at [expr $simulationTime] "$ftp(2) stop"

set flowmon [$ns makeflowmon Fid]
set MainLink [$ns link $nsource $nsink]
$ns attach-fmon $MainLink $flowmon
set fcl [$flowmon classifier]

### procedures ###
proc sendBursts {} {
  global ns burstSize burstInterval ftp
  set now [$ns now]
  puts "sending burst"
  $ftp(2) producemore $burstSize
  $ns at [expr $now + $burstInterval] "sendBursts"
}

proc finish {} {
  global ns enableNAM namfile queueFile instThroughputFile resultsFile myTraceFile srcQueueFile
  # writeResults
  $ns flush-trace
  close $queueFile
  close $instThroughputFile
  close $myTraceFile
  close $srcQueueFile
  # close $resultsFile
  if {$enableNAM != 0} {
    close $namfile
    exec nam out.nam &
  }
  exit 0
}

proc writeResults {} {
  global resultsFile totalThroughput ql_sum ql_n pauseThreshold
  set averageQueueLength [expr 1.0 * $ql_sum / $ql_n]
  puts -nonewline $resultsFile "$pauseThreshold $totalThroughput $averageQueueLength"
  puts $resultsFile ""
}

proc myTrace {file} {
    global ns traceSamplingInterval tcp qmon ql_sum ql_n nsource source_qmon
    
    set now [$ns now]
    
    for {set i 0} {$i < 3} {incr i} {
      set cwnd($i) [$tcp($i) set cwnd_]
      set dctcp_alpha($i) [$tcp($i) set dctcp_alpha_]
    }
    
    $qmon instvar parrivals_ pdepartures_ pdrops_
  
    puts -nonewline $file "$now"
    for {set i 0} {$i < 3} {incr i} {
      puts -nonewline $file " $cwnd($i)"
    }
    for {set i 0} {$i < 3} {incr i} {
      puts -nonewline $file " $dctcp_alpha($i)"
    }

    puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"    
    puts -nonewline $file " $pdrops_"

    set len [$qmon set pkts_]
    set ql_sum [expr $ql_sum + $len]
    set ql_n [expr $ql_n + 1]

    [$nsource entry] instvar pause_count_ q_makeup_zero_ q_makeup_one_ q_makeup_two_
    puts -nonewline $file " $pause_count_"
    puts -nonewline $file " $q_makeup_zero_ $q_makeup_one_ $q_makeup_two_"

    for {set i 0} {$i < 3} {incr i} {
      $source_qmon($i) instvar parrivals_ pdepartures_ pdrops_
      puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"
    }
    puts $file ""

    $ns at [expr $now+$traceSamplingInterval] "myTrace $file"
}

proc classifyFlow {fid} {
    global fcl flowstats classifyInterval
    set flowstats($fid) [$fcl lookup auto 0 0 $fid]
    puts "$fid $flowstats($fid)"
}

proc throughputTrace {file} {
    global ns throughputSamplingInterval qmon flowstats flowClassifyTime
    
    set now [$ns now]
    
    $qmon instvar bdepartures_
    
    puts -nonewline $file "$now [expr ($bdepartures_*8/$throughputSamplingInterval)/1000000]"
    set bdepartures_ 0
    for {set i 0} {$i < 3} {incr i} {
      if {[info exists flowstats($i)] == 0} {
        puts -nonewline $file " 0"
      } else {
        $flowstats($i) instvar barrivals_
        puts -nonewline $file " [expr ($barrivals_*8/$throughputSamplingInterval)/1000000]"
        set barrivals_ 0
      }
    }
    puts $file ""

    $ns at [expr $now+$throughputSamplingInterval] "throughputTrace $file"
}

set startPacketCount 0
set stopPacketCount 0

proc startMeasurement {} {
  global qmon startPacketCount
  $qmon instvar pdepartures_   
  set startPacketCount $pdepartures_
}

proc stopMeasurement {} {
  global qmon startPacketCount stopPacketCount startMeasurementTime packetSize stopMeasurementTime simulationTime totalThroughput
  $qmon instvar pdepartures_   
  set stopPacketCount $pdepartures_
  set totalThroughput [expr (($stopPacketCount-$startPacketCount) *$packetSize *8) / (($stopMeasurementTime-$startMeasurementTime) *1000000) ]
}

#set the random seed for consistent results
ns-random 0
$ns at $startMeasurementTime "startMeasurement"
$ns at $stopMeasurementTime "stopMeasurement"
$ns at $traceSamplingInterval "myTrace $myTraceFile"
$ns at $throughputTraceStart "throughputTrace $instThroughputFile"
$ns at $simulationTime "finish"

$ns run
