set ns [new Simulator]

set enable_pause 1
set K 65
set RTT 0.0001

set simulationTime 1.0

assert [expr $simulationTime < 1.5]
# Sequence number wraps around otherwise

##### Transport defaults, like packet size ######
set packetSize 1460
Agent/TCP set packetSize_ $packetSize
Agent/TCP/FullTcp set segsize_ $packetSize

## Turn on DCTCP ##
set sourceAlg DropTail
source configs/dctcp-defaults.tcl


$ns color 1 Red
$ns color 2 Blue
$ns namtrace-all [open "out.nam" w]

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
#         3               2
#           \            / 
#             1 -- 7 -- 0 -- 6   
#           /      |     \ 
#         5        8      4   
#
set inputLineRate 10Gb
set N 9
for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
    $n($i) color "red"
}

# pause instrumentation and queue monitors
if {$enable_pause == 1} {
    puts "Pause enabled"
    Queue set limit_ 10000000
} else {
    puts "Pause disabled"
    Queue set limit_ 1000
}



# create links
# first the main link
$ns duplex-link $n(1) $n(7) $inputLineRate [expr $RTT/4] DropTail
$ns duplex-link-op $n(1) $n(7) queuePos -0.5
$ns duplex-link $n(7) $n(0) $inputLineRate [expr $RTT/4] DropTail
$ns duplex-link-op $n(7) $n(0) queuePos -0.5
$ns duplex-link $n(8) $n(7) $inputLineRate [expr $RTT/4] DropTail
$ns duplex-link-op $n(8) $n(7) queuePos -0.5

for {set i 2} {$i < $N-2} {incr i} {
    if {$i % 2 == 0} {
      $ns duplex-link $n(0) $n($i) $inputLineRate [expr $RTT/4] DropTail
      $ns duplex-link-op $n(0) $n($i) queuePos -0.5
      if {$enable_pause == 1} {
        attach-classifiers $ns $n(0) $n($i)
      }
    } else {
      $ns duplex-link $n(1) $n($i) $inputLineRate [expr $RTT/4] DropTail
      $ns duplex-link-op $n(1) $n($i) queuePos -0.5
      if {$enable_pause == 1} {
        attach-classifiers $ns $n(1) $n($i)
      }
    }
}
puts "Created links"
# set traceSamplingInterval 0.001
# set queue_fh [open "/dev/null" w]
# set qmon($i) [$ns monitor-queue $tor_node $n($i) $queue_fh $traceSamplingInterval]

# create a tcp connection from 3 -> 2
set tcp(3,2) [new Agent/TCP]
set sink(3,2) [new Agent/TCPSink]
$ns attach-agent $n(3) $tcp(3,2)
$ns attach-agent $n(2) $sink(3,2)
$ns connect $tcp(3,2) $sink(3,2)
$tcp(3,2) set _fid 1

# create a tcp connection from 5 -> 4
set tcp(5,4) [new Agent/TCP]
set sink(5,4) [new Agent/TCPSink]
$ns attach-agent $n(5) $tcp(5,4)
$ns attach-agent $n(4) $sink(5,4)
$ns connect $tcp(5,4) $sink(5,4)


# create a tcp connection from 6 -> 4
# TODO need to make it bursty
set tcp(8,6) [new Agent/TCP]
set sink(8,6) [new Agent/TCPSink]
$ns attach-agent $n(8) $tcp(8,6)
$ns attach-agent $n(6) $sink(8,6)
$ns connect $tcp(8,6) $sink(8,6)

puts "created TCP connections"

#### Application: long-running FTP #####
# send a flow from 3 -> 2
set ftp(3,2) [new Application/FTP]
$ftp(3,2) attach-agent $tcp(3,2)
$ns at 0.0 "$ftp(3,2) start"
$ns at [expr $simulationTime] "$ftp(3,2) stop"

# send a flow from 5 -> 4
set ftp(5,4) [new Application/FTP]
$ftp(5,4) attach-agent $tcp(5,4)
$ns at 0.0 "$ftp(5,4) start"
$ns at [expr $simulationTime] "$ftp(5,4) stop"

# send a delayed flow from 6 -> 4
set ftp(8,6) [new Application/FTP]
$ftp(8,6) attach-agent $tcp(5,4)
$ns at 0.5 "$ftp(8,6) start"
$ns at [expr $simulationTime] "$ftp(8,6) stop"
puts "sent all flows"


### Cleanup procedure ###
proc finish {} {
  # global ns queue_fh
  # $ns flush-trace
  # close $queue_fh

  puts "running nam..."
  exec nam -f dynamic-nam.conf out.nam &
  exit 0
}

$ns at $simulationTime "finish"
$ns run
