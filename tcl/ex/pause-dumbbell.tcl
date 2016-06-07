set ns [new Simulator]

set enable_pause 0
set K 5
set RTT 0.0005
set simulationTime 1.0
set startMeasurementTime 0.001
set stopMeasurementTime 1
set flowClassifyTime 0.001
set burstStartTime 0.4
set burstInterval 0.1
set burstSize 10000

assert [expr $simulationTime < 1.5]
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
Agent/TCP set window_ 1256
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

#Queue set limit_ 1000

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
    Queue set limit_ 10000000
} else {
    puts "Pause disabled"
    Queue set limit_ 100
}

## Tracing Parameters ##
$ns color 0 Red
$ns color 1 Orange
$ns color 2 Yellow
$ns color 3 Green
$ns color 4 Blue
$ns color 5 Violet
$ns color 6 Brown
$ns color 7 Black
set enableNAM 1
set mytracefile [open traces/mytracefile.tr w]
set throughputfile [open traces/thrfile.tr w]
set traceSamplingInterval 0.0001
set throughputSamplingInterval 0.01
if {$enableNAM != 0} {
    set namfile [open out.nam w]
    $ns namtrace-all $namfile
}


# Procedure to attach classifier to queues
# for nodes n1 and n2
proc attach-classifiers {ns n1 n2} {
    set fwd_queue [[$ns link $n1 $n2] queue]
    $fwd_queue attach-classifier [$n1 entry]
    [$n1 entry] set enable_pause_ 1

    set bwd_queue [[$ns link $n2 $n1] queue]
    $bwd_queue attach-classifier [$n2 entry]
    [$n2 entry] set enable_pause_ 1
}

##### Topology ###########
#
#         0            1
#           \        / 
#        2 -- A -- B -- 3 
#           /        \ 
#         4            5   
#
set inputLineRate 10Gb
set N 6
for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
}
set nsource [$ns node]
set nsink [$ns node]

# create links
# first the main link
$ns duplex-link $nsource $nsink $inputLineRate [expr $RTT/8] RED
$ns duplex-link-op $nsource $nsink queuePos 0.25
set qfile [$ns monitor-queue $nsource $nsink [open traces/queue.tr w] $traceSamplingInterval]
$ns duplex-link-op $nsource $nsink color "green"

for {set i 0} {$i < $N} {incr i} {
    if {$i % 2 == 0} {
      $ns simplex-link $nsource $n($i) $inputLineRate [expr $RTT/8] RED
      $ns simplex-link $n($i) $nsource $inputLineRate [expr $RTT/8] DropTail
      
      if {$enable_pause == 1} {
        attach-classifiers $ns $nsource $n($i)
      }
    } else {
      $ns simplex-link $nsink $n($i) $inputLineRate [expr $RTT/8] RED
      $ns simplex-link $n($i) $nsink $inputLineRate [expr $RTT/8] DropTail

      if {$enable_pause == 1} {
        attach-classifiers $ns $nsink $n($i)
      }
    }
}

 set traceSamplingInterval 0.001
# set queue_fh [open "/dev/null" w]
# set qmon($i) [$ns monitor-queue $tor_node $n($i) $queue_fh $traceSamplingInterval]

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
  $tcp($i) set _fid $i
  $sink($i) set _fid $i
}

#### Application: long-running FTP #####
for {set i 0} {$i < 3} {incr i} {
  set ftp($i) [new Application/FTP]
  $ftp($i) attach-agent $tcp($i)
}

# send a flow from 0 -> 1
$ns at 0.0 "$ftp(0) start"
$ns at [expr $simulationTime] "$ftp(0) stop"

# send a flow from 2 -> 3
$ns at 0.1 "$ftp(1) start"
$ns at [expr $simulationTime] "$ftp(1) stop"

# send a delayed, bursty flow from 4 -> 5
$ns at $burstStartTime "$ftp(2) produce $burstSize"
$ns at $burstStartTime "sendBursts"
$ns at [expr $simulationTime] "$ftp(2) stop"

set flowmon [$ns makeflowmon Fid]
set MainLink [$ns link $nsource $nsink]

$ns attach-fmon $MainLink $flowmon

set fcl [$flowmon classifier]

# $ns at $flowClassifyTime "classifyFlows"

$ns at $traceSamplingInterval "myTrace $mytracefile"
# $ns at $throughputSamplingInterval "throughputTrace $throughputfile"

### procedures ###
proc sendBursts {} {
  global ns burstSize burstInterval ftp
  set now [$ns now]
  puts "sending burst"
  $ftp(2) producemore $burstSize
  $ns at [expr $now + $burstInterval] "sendBursts"
}

proc finish {} {
  global ns enableNAM namfile mytracefile throughputfile
  $ns flush-trace
  close $mytracefile
  close $throughputfile
  if {$enableNAM != 0} {
    close $namfile
    exec nam out.nam &
  }
  exit 0
}

proc myTrace {file} {
    global ns N traceSamplingInterval tcp qfile
    
    set now [$ns now]
    
    for {set i 0} {$i < 3} {incr i} {
    set cwnd($i) [$tcp($i) set cwnd_]
    set dctcp_alpha($i) [$tcp($i) set dctcp_alpha_]
    }
    
    $qfile instvar parrivals_ pdepartures_ pdrops_ bdepartures_
  
    puts -nonewline $file "$now $cwnd(0)"
    for {set i 1} {$i < 3} {incr i} {
    puts -nonewline $file " $cwnd($i)"
    }
    for {set i 0} {$i < 3} {incr i} {
    puts -nonewline $file " $dctcp_alpha($i)"
    }
 
    puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"    
    puts $file " $pdrops_"
     
    $ns at [expr $now+$traceSamplingInterval] "myTrace $file"
}

proc classifyFlows {} {
    global N fcl flowstats
    puts "NOW CLASSIFYING FLOWS"
    for {set i 0} {$i < 3} {incr i} {
    set flowstats($i) [$fcl lookup autp 0 0 $i]
    }
}

proc throughputTrace {file} {
    global ns throughputSamplingInterval qfile flowstats flowClassifyTime
    
    set now [$ns now]
    
    $qfile instvar bdepartures_
    
    puts -nonewline $file "$now [expr $bdepartures_*8/$throughputSamplingInterval/1000000]"
    set bdepartures_ 0
    if {$now <= $flowClassifyTime} {
    for {set i 0} {$i < [expr $N-1]} {incr i} {
        puts -nonewline $file " 0"
    }
    puts $file " 0"
    }

    if {$now > $flowClassifyTime} { 
      for {set i 0} {$i < 2} {incr i} {
          $flowstats($i) instvar barrivals_
          puts -nonewline $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
          set barrivals_ 0
      }
      $flowstats(2) instvar barrivals_
      puts $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
      set barrivals_ 0
    }
    $ns at [expr $now+$throughputSamplingInterval] "throughputTrace $file"
}

set startPacketCount 0
set stopPacketCount 0

proc startMeasurement {} {
global qfile startPacketCount
$qfile instvar pdepartures_   
set startPacketCount $pdepartures_
}

proc stopMeasurement {} {
global qfile startPacketCount stopPacketCount packetSize startMeasurementTime stopMeasurementTime simulationTime
$qfile instvar pdepartures_   
set stopPacketCount $pdepartures_
puts "Throughput = [expr ($stopPacketCount-$startPacketCount)/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*$packetSize*8] Mbps"
}

#set the random seed for consistent results
ns-random 0
$ns at $startMeasurementTime "startMeasurement"
$ns at $stopMeasurementTime "stopMeasurement"
$ns at $simulationTime "finish"

$ns run
