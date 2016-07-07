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
 *
 * $Header: /cvsroot/nsnam/ns-2/classifier/classifier-hash.h,v 1.10 2010/03/08 05:54:49 tom_henderson Exp $
 */

#include <map>
#include <cstdint>
#include "connector.h"
#include "classifier.h"
//#include "queue.h"
#include "ip.h"


class Flow;

/* class defs for HashClassifier (base), SrcDest, SrcDestFid HashClassifiers */
class HashClassifier : public Classifier {
public:
	HashClassifier(int keylen) : default_(-1), keylen_(keylen) {
		// shift + mask picked up from underlying Classifier object
		bind("default_", &default_);
		Tcl_InitHashTable(&ht_, keylen);
	}		
	~HashClassifier() {
		Tcl_DeleteHashTable(&ht_);
	};
	virtual int classify(Packet *p);
	virtual long lookup(Packet* p) {
		hdr_ip* h = hdr_ip::access(p);
		return get_hash(mshift(h->saddr()), mshift(h->daddr()), 
				h->flowid());
	}
	virtual long unknown(Packet* p) {
		hdr_ip* h = hdr_ip::access(p);
		Tcl::instance().evalf("%s unknown-flow %u %u %u",
				      name(), h->saddr(), h->daddr(),
				      h->flowid()); 
		return lookup(p);
	};
	void set_default(int slot) { default_ = slot; } 
	int do_set_hash(nsaddr_t src, nsaddr_t dst, int fid, int slot) {
		return (set_hash(src,dst,fid,slot));
	}
	void set_table_size(int nn);
protected:
	union hkey {
		struct {
			int fid;
		} Fid;
		struct {
			nsaddr_t dst;
		} Dst;
		struct {
			nsaddr_t src, dst;
		} SrcDst;
		struct {
			nsaddr_t src, dst;
			int fid;
		} SrcDstFid;
	};
		
	long lookup(nsaddr_t src, nsaddr_t dst, int fid) {
		return get_hash(src, dst, fid);
	}
	int newflow(Packet* pkt) {
		hdr_ip* h = hdr_ip::access(pkt);
		Tcl::instance().evalf("%s unknown-flow %u %u %u",
				      name(), h->saddr(), h->daddr(),
				      h->flowid()); 
		return lookup(pkt);
	};
	void reset() {
		Tcl_DeleteHashTable(&ht_);
		Tcl_InitHashTable(&ht_, keylen_);
	}

	virtual const char* hashkey(nsaddr_t, nsaddr_t, int)=0; 

	int set_hash(nsaddr_t src, nsaddr_t dst, int fid, long slot) {
		int newEntry;
		Tcl_HashEntry *ep= Tcl_CreateHashEntry(&ht_,
						       hashkey(src, dst, fid),
						       &newEntry); 
		if (ep) {
			Tcl_SetHashValue(ep, slot);
			return slot;
		}
		return -1;
	}
	long get_hash(nsaddr_t src, nsaddr_t dst, int fid) {
		Tcl_HashEntry *ep= Tcl_FindHashEntry(&ht_, 
						     hashkey(src, dst, fid)); 
		if (ep)
			return (long)Tcl_GetHashValue(ep);
		return -1;
	}
	
	virtual int command(int argc, const char*const* argv);


	int default_;
	Tcl_HashTable ht_;
	hkey buf_;
	int keylen_;
};

class SrcDestFidHashClassifier : public HashClassifier {
public:
	SrcDestFidHashClassifier() : HashClassifier(3) {
	}
protected:
	const char* hashkey(nsaddr_t src, nsaddr_t dst, int fid) {
		buf_.SrcDstFid.src= mshift(src);
		buf_.SrcDstFid.dst= mshift(dst);
		buf_.SrcDstFid.fid= fid;
		return (const char*) &buf_;
	}
};

class SrcDestHashClassifier : public HashClassifier {
public:
	SrcDestHashClassifier() : HashClassifier(2) {
	int command(int argc, const char*const* argv);
	int classify(Packet *p);
	}
protected:
	const char*  hashkey(nsaddr_t src, nsaddr_t dst, int) {
		buf_.SrcDst.src= mshift(src);
		buf_.SrcDst.dst= mshift(dst);
		return (const char*) &buf_;
	}
};

class FidHashClassifier : public HashClassifier {
public:
	FidHashClassifier() : HashClassifier(TCL_ONE_WORD_KEYS) {
	}
protected:
	const char* hashkey(nsaddr_t, nsaddr_t, int fid) {
		long key = fid;
		return (const char*) key;
	}
};

class DestHashClassifier;

class DestHashHandler : public Handler {
public:
	DestHashHandler() {}
	DestHashHandler(DestHashClassifier* dhc, int32_t input_port) : dhc_(dhc), input_port_(input_port) {}
	void handle(Event*);
	Event e_;
private:
	DestHashClassifier* dhc_;
	int32_t input_port_;
};

class DestHashClassifier : public HashClassifier {
	friend class DestHashHandler;
public:
	DestHashClassifier() : HashClassifier(TCL_ONE_WORD_KEYS), enable_pause_(0), qcap_(0), pause_duration_(0), pause_threshold_(0), resume_threshold_(0), pause_count_(0)
		{ bind ("enable_pause_", &enable_pause_);
		  bind ("pause_threshold_", &pause_threshold_);
		  bind ("resume_threshold_", &resume_threshold_);
		  bind ("pause_duration_", &pause_duration_); }
	virtual int command(int argc, const char*const* argv);
	int classify(Packet *p);
	virtual void do_install(char *dst, NsObject *target);
	void recv(Packet* p, Handler* h) override;
	void deque_callback(Packet* p);
	void attach_queue_callback(int qlim);
	enum class PauseAction { PAUSE, RESUME };
protected:
	std::map<int32_t, uint64_t> input_counters_;
	std::map<int32_t, DestHashHandler> pause_renewals_;
	std::map<int32_t, bool> paused_;
	int pause_count_;
	uint64_t qcap_;
	const char* hashkey(nsaddr_t, nsaddr_t dst, int) {
		long key = mshift(dst);
		return (const char*) key;
	}
	template <class NodeType>
	NodeType* find_node_type(NsObject* node) {
		if (dynamic_cast<NodeType*>(node) != NULL) {
			/* Either this is the NodeType */
			return dynamic_cast<NodeType*>(node);
		} else if (dynamic_cast<Connector*>(node) != NULL) {
			/* Or chase pointers until you find a NodeType */
			return find_node_type<NodeType>(dynamic_cast<Connector*>(node)->target());
		} else {
			/* But without a Connector, you are out of luck */
			return NULL;
		}
	}
private:
	int pause_threshold_;
	int resume_threshold_;
	double pause_duration_;
	int enable_pause_;
	Packet* generate_pause_pkt(const int32_t port_to_pause, const PauseAction action);
	NsObject* find_dst(const int32_t dst);
	bool is_paused(const int32_t port);
	void cancelEvent(Event* e);
};