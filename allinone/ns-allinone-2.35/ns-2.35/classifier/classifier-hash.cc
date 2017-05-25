/* -*-	Mode:C++; c-basic-offset:8; tab-width:8; indent-tabs-mode:t -*- */
/*
 * Copyright (c) 1997 The Regents of the University of California.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 * 	This product includes software developed by the Network Research
 * 	Group at Lawrence Berkeley National Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /cvsroot/nsnam/ns-2/classifier/classifier-hash.cc,v 1.31 2010/03/08 05:54:49 tom_henderson Exp $ (LBL)";
#endif

//
// a generalized classifier for mapping (src/dest/flowid) fields
// to a bucket.  "buckets_" worth of hash table entries are created
// at init time, and other entries in the same bucket are created when
// needed
//
//

extern "C" {
#include <tcl.h>
}

#include <stdlib.h>
#include "config.h"
#include "packet.h"
#include "ip.h"
#include "classifier.h"
#include "classifier-hash.h"
#include "classifier-port.h"
#include "agent.h"
#include "pause_header.h"
#include "delay.h"
#include "queue.h"

/****************** HashClassifier Methods ************/
// void DestHashClassifier::cancelEvent(Event* e) {
// 	Scheduler::instance().cancel(e);
// }

// void DestHashHandler::handle(Event* e) {
// 	/* pause frame expired, check if need to renew and send another pause_pkt */
// 	if (dhc_->input_counters_[input_port_] > dhc_->pause_threshold_) {
// 		// printf("%f: Port needs to be re-paused, since input_counters[%d] = %d and is_paused=%d\n",
// 		// 	Scheduler::instance().clock(),
// 		// 	input_port_,
// 		// 	dhc_->input_counters_[input_port_],
// 		// 	dhc_->is_paused(input_port_));
// 		auto pause_pkt = dhc_->generate_pause_pkt(input_port_, DestHashClassifier::PauseAction::PAUSE);
// 		/* No point sending a pause to an agent */
// 		int slot = dhc_->lookup(pause_pkt);
// 		dhc_->slot_[slot]->recv(pause_pkt);
// 		dhc_->pause_count_++;
// 		/* schedule the next pause renewal check */
// 		Scheduler& s = Scheduler::instance();
// 		s.schedule(&(dhc_->pause_renewals_[input_port_]), e, hdr_pause::access(pause_pkt)->class_pause_durations_[0]);
// 	}
// }

// void DestHashClassifier::attach_queue_callback(int qlim) {
// 	// printf("node %d: attaching a new queue of size %d, qcap=%d\n", node_id_, qlim, qcap_);
// 	qcap_ += qlim;
// }

void DestHashClassifier::deque_callback(Packet* p) {
	if (p != nullptr) {
		if (hdr_cmn::access(p)->ptype() == PT_PAUSE){
			/* if this is a pause packet, don't account for it */
			assert(hdr_ip::access(p)->saddr() == node_id_);
		} else {
			const int32_t input_port = hdr_cmn::access(p)->input_port();
			printf("at %f node %d dequeing pkt from %d\n",
				Scheduler::instance().clock(),
				node_id_,
				input_port);
			if (input_port != -1) {
				input_counters_.at(input_port)--;
				/* Resume logic */
				if (resume_thresholds_.count(input_port) == 1){
					if (input_counters_.at(input_port) < resume_thresholds_.at(input_port) and
					is_paused(input_port)) {
						auto unpause_pkt = generate_pause_pkt(input_port, PauseAction::RESUME);
						printf("at %f node %d unpausing %d",
							Scheduler::instance().clock(),
							node_id_,
							input_port);
						int slot = lookup(unpause_pkt);
						slot_[slot]->recv(unpause_pkt);
						paused_.at(input_port) = false;
						
					}
				}
			}	
		}
		/* either way, change input_port() and forward onward */
		hdr_cmn::access(p)->input_port() = node_id_;
	}
}


bool DestHashClassifier::is_paused(const int32_t port) {
	if (paused_.find(port) == paused_.end()) {
		return false;
	} else {
		return paused_.at(port);
	}
}

Packet* DestHashClassifier::generate_pause_pkt(const int32_t port_to_pause, const PauseAction action) {
	Packet* pause_pkt = Packet::alloc();
	double pause = (action == PauseAction::PAUSE) ? 1 : 0;
	std::vector<double> pause_durations_vector;
	std::vector<bool> enable_vector;
	for (uint8_t i = 0; i < hdr_pause::NUM_ETH_CLASS; i++) {
		pause_durations_vector.push_back(pause);
		enable_vector.push_back(true);
	}
	hdr_pause::fill_in(pause_pkt, pause_durations_vector, enable_vector);
	hdr_ip::access(pause_pkt)->saddr() = node_id_;
	hdr_ip::access(pause_pkt)->daddr() = port_to_pause;
	hdr_ip::access(pause_pkt)->prio() = 10000000000; // dzuo: ensure pause pkts never dropped?
	assert(hdr_ip::access(pause_pkt)->saddr() != hdr_ip::access(pause_pkt)->daddr());
	hdr_ip::access(pause_pkt)->ttl() = 32;
	return pause_pkt;
}

NsObject* DestHashClassifier::find_dst(const int32_t dst) {
	/* Create a fake packet to lookup destination */
	Packet* fake_pkt = Packet::alloc();
	hdr_ip::access(fake_pkt)->saddr() = node_id_;
	hdr_ip::access(fake_pkt)->daddr() = dst;
	auto ret = find(fake_pkt);
	Packet::free(fake_pkt);
	return ret;
}

void DestHashClassifier::recv(Packet* p, Handler* h) {
	if (enable_pause_ == 0) {
		return HashClassifier::recv(p, h); /* one level up the hierarchy */
	}
	NsObject* node = find(p);
	assert(node != NULL);

	if (hdr_cmn::access(p)->ptype() == PT_PAUSE) {
		if (hdr_pause::access(p)->class_pause_durations_[0] == 0) {
			/* if you are receiving a resume */
			const auto src_addr = hdr_ip::access(p)->saddr();
			assert(src_addr != node_id_);

			printf("%f: %d: Received a resume frame from %d\n",
				Scheduler::instance().clock(),
				node_id_,
				src_addr);

			/* unblock queue */
			auto queue_to_unblock = find_node_type<Queue>(find_dst(src_addr));
			assert(queue_to_unblock->blocked() == 1);
			queue_to_unblock->unblock();

			/* the pause packet's work is done, free it */
			Packet::free(p);
			return;
		}

		else {
			/* if you are receiving a pause */
			const auto src_addr = hdr_ip::access(p)->saddr();
			assert(src_addr != node_id_);
			printf("%f: %d: Received a pause frame from %d\n",
				Scheduler::instance().clock(),
				node_id_,
				src_addr);

			/* find the LinkDelay class */
			/* Cancel timer that fires after existing packet delivery event */
			auto link_to_pause = find_node_type<LinkDelay>(find_dst(src_addr));
			Scheduler::instance().cancel(&link_to_pause->intr());

			/* set queue to blocked */
			auto queue_to_block = find_node_type<Queue>(find_dst(src_addr));
			queue_to_block->block();

			/* the pause packet's work is done, free it */
			Packet::free(p);
			return;
		}
	}

	if (dynamic_cast<PortClassifier*>(node) != nullptr) {
		/* if "node" points to an agent, do nothing, we have reached destination */
		auto agent_target = dynamic_cast<Agent*>(dynamic_cast<PortClassifier*>(node)->find(p));
		assert(agent_target != nullptr);
	} else {
		/* Input accounting for pause */
		const int32_t input_port = hdr_cmn::access(p)->input_port();
		if (input_port != -1){
			input_counters_[input_port]++;
			printf("at %f node %d received pkt from %d, input_counters_[input_port]=%d\n",
						Scheduler::instance().clock(),
						node_id_,
						input_port,
						input_counters_[input_port]);
			if (pause_thresholds_.count(input_port) == 1) {
				if (input_counters_.at(input_port) > pause_thresholds_.at(input_port) and
				(not is_paused(input_port))) {
					auto pause_pkt = generate_pause_pkt(input_port, PauseAction::PAUSE);
					/* No point sending a pause to an agent */
					printf("at %f node %d sending pause to %d because input_counters_[input_port]=%d and pause_threshold_=%d\n",
						Scheduler::instance().clock(),
						node_id_,
						input_port,
						input_counters_[input_port],
						pause_thresholds_.at(input_port));
					int slot = lookup(pause_pkt);
					slot_[slot]->recv(pause_pkt);
					paused_[input_port] = true;
					// pause_count_++;
				}
			}
		}
	}

	/* Either way send it to node */
	node->recv(p,h);
}

int HashClassifier::classify(Packet * p) {
	int slot= lookup(p);
	if (slot >= 0 && slot <=maxslot_)
		return (slot);
	else if (default_ >= 0)
		return (default_);
	return (unknown(p));
} // HashClassifier::classify

int HashClassifier::command(int argc, const char*const* argv)
{
	Tcl& tcl = Tcl::instance();
	/*
	 * $classifier set-hash $hashbucket src dst fid $slot
	 */

	if (argc == 7) {
		if (strcmp(argv[1], "set-hash") == 0) {
			//xxx: argv[2] is ignored for now
			nsaddr_t src = atoi(argv[3]);
			nsaddr_t dst = atoi(argv[4]);
			int fid = atoi(argv[5]);
			int slot = atoi(argv[6]);
			if (0 > set_hash(src, dst, fid, slot))
				return TCL_ERROR;
			return TCL_OK;
		}
	} else if (argc == 6) {
		/* $classifier lookup $hashbuck $src $dst $fid */
		if (strcmp(argv[1], "lookup") == 0) {
			nsaddr_t src = atoi(argv[3]);
			nsaddr_t dst = atoi(argv[4]);
			int fid = atoi(argv[5]);
			int slot= get_hash(src, dst, fid);
			if (slot>=0 && slot <=maxslot_) {
				tcl.resultf("%s", slot_[slot]->name());
				return (TCL_OK);
			}
			tcl.resultf("");
			return (TCL_OK);
		}
                // Added by Yun Wang to set rate for TBFlow or TSWFlow
                if (strcmp(argv[1], "set-flowrate") == 0) {
                        int fid = atoi(argv[2]);
                        nsaddr_t src = 0;  // only use fid
                        nsaddr_t dst = 0;  // to classify flows
                        int slot = get_hash( src, dst, fid );
                        if ( slot >= 0 && slot <= maxslot_ ) {
                                Flow* f = (Flow*)slot_[slot];
                                tcl.evalf("%u set target_rate_ %s",
                                        f, argv[3]);
                                tcl.evalf("%u set bucket_depth_ %s",
                                        f, argv[4]);
                                tcl.evalf("%u set tbucket_ %s",
                                        f, argv[5]);
                                return (TCL_OK);
                        }
                        else {
                          tcl.evalf("%s set-rate %u %u %u %u %s %s %s",
                          name(), src, dst, fid, slot, argv[3], argv[4],argv[5])
;
                          return (TCL_OK);
                        }
                }  
	} else if (argc == 5) {
		/* $classifier del-hash src dst fid */
		if (strcmp(argv[1], "del-hash") == 0) {
			nsaddr_t src = atoi(argv[2]);
			nsaddr_t dst = atoi(argv[3]);
			int fid = atoi(argv[4]);
			
			Tcl_HashEntry *ep= Tcl_FindHashEntry(&ht_, 
							     hashkey(src, dst,
								     fid)); 
			if (ep) {
				long slot = (long)Tcl_GetHashValue(ep);
				Tcl_DeleteHashEntry(ep);
				tcl.resultf("%lu", slot);
				return (TCL_OK);
			}
			return (TCL_ERROR);
		}
	}
	return (Classifier::command(argc, argv));
}

/**************  TCL linkage ****************/
static class SrcDestHashClassifierClass : public TclClass {
public:
	SrcDestHashClassifierClass() : TclClass("Classifier/Hash/SrcDest") {}
	TclObject* create(int, const char*const*) {
		return new SrcDestHashClassifier;
	}
} class_hash_srcdest_classifier;

static class FidHashClassifierClass : public TclClass {
public:
	FidHashClassifierClass() : TclClass("Classifier/Hash/Fid") {}
	TclObject* create(int, const char*const*) {
		return new FidHashClassifier;
	}
} class_hash_fid_classifier;

static class DestHashClassifierClass : public TclClass {
public:
	DestHashClassifierClass() : TclClass("Classifier/Hash/Dest") {}
	TclObject* create(int, const char*const*) {
		return new DestHashClassifier;
	}
} class_hash_dest_classifier;

static class SrcDestFidHashClassifierClass : public TclClass {
public:
	SrcDestFidHashClassifierClass() : TclClass("Classifier/Hash/SrcDestFid") {}
	TclObject* create(int, const char*const*) {
		return new SrcDestFidHashClassifier;
	}
} class_hash_srcdestfid_classifier;


// DestHashClassifier methods
int DestHashClassifier::classify(Packet *p)
{
	int slot= lookup(p);
	if (slot >= 0 && slot <=maxslot_)
		return (slot);
	else if (default_ >= 0)
		return (default_);
	return -1;
} // HashClassifier::classify

void DestHashClassifier::do_install(char* dst, NsObject *target) {
	nsaddr_t d = atoi(dst);
	int slot = getnxt(target);
	install(slot, target); 
	if (set_hash(0, d, 0, slot) < 0)
		fprintf(stderr, "DestHashClassifier::set_hash from within DestHashClassifier::do_install returned value < 0");
}

int DestHashClassifier::command(int argc, const char*const* argv)
{
	if (argc == 4) {
		// $classifier install $dst $node
		if (strcmp(argv[1], "install") == 0) {
			char dst[SMALL_LEN];
			strcpy(dst, argv[2]);
			NsObject *node = (NsObject*)TclObject::lookup(argv[3]);
			//nsaddr_t dst = atoi(argv[2]);
			do_install(dst, node); 
			return TCL_OK;
			//int slot = getnxt(node);
			//install(slot, node);
			//if (set_hash(0, dst, 0, slot) >= 0)
			//return TCL_OK;
			//else
			//return TCL_ERROR;
		} // if
	}
	return(HashClassifier::command(argc, argv));
} // command

void HashClassifier::set_table_size(int)
{}
