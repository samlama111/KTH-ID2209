/**
* Name: Exercise2_Bonus2
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise2_Bonus2

global {
	int numberOfBidders <- 3;
	list<agent> globalBidders;
	
	init {
		do vickrey;
	}
	
	action dutch {
		create DutchAuctioneer;
		create DutchBidder number: numberOfBidders returns: bidders;
		globalBidders <- bidders;
	}
	
	action sealed {
		create SealedAuctioneer;
		create SealedBidder number: numberOfBidders returns: bidders;
		globalBidders <- bidders;
	}
	
	action vickrey {
		create VickreyAuctioneer;
		create SealedBidder number: numberOfBidders returns: bidders;
		globalBidders <- bidders;
	}
}

species DutchBidder parent: Bidder {
	action bidding(message bid) {
		// Auction we are part of is doing some bidding.
		int wanted <- int(bid.contents[1]);
		write "[" + name + "] Received a bid offer, they want " + wanted;
		if (budget >= wanted) {
			// If we can afford it, we accept.
			write "[" + name + "] My budget is " + budget + ", so I accept";
			do propose message: bid contents: ["I bid", wanted];
		} else {
			// If we can't, we reject. Perhaps this can be omitted?
			write "[" + name + "] My budget is " + budget + ", so I refuse";
			do refuse message: bid contents: ["I reject"];
		}
	}
}

species SealedBidder parent: Bidder {
	action bidding(message bid) {
		write "[" + name + "] I will bid my budget of " + budget;
		do propose message: bid contents: ["I bid", budget];
	}
}

species Bidder skills: [fipa] {
	string agentName <- "undefined";
	int budget <- rnd(0, 2000);
	
	action bidding(message bid) virtual: true;
	
	reflex receiveMessage when: !empty(cfps) {
		// The current bidding process.
		loop incoming over: cfps {
			// Is it an auction start notification or is it an offer to bid?
			list msg <- incoming.contents;
			if (msg[0] = "notify") {
				// New auction is starting, do we want to join?
				write "[" + name + "] Received word of a new auction, I would like to join!";
				do propose message: incoming contents: ["I would like to join"];
				//do refuse message: incoming contents: ["Sorry, not interested"];
			} else if (msg[0] = "offer") {
				do bidding(incoming);
			} else {
				write "[" + name + "] Unknown CFP: " + msg;
			}
		}
	}
	
	reflex bidWasAccepted when: !empty(accept_proposals) {
		// Bid was accepted here, so we need to send an inform.
		loop accepted over: accept_proposals {
			write "[" + name + "] My bid was accepted: " + accepted.contents[0];
			do inform message: accepted contents: ["Here is my address", "Spreeweg 1, Berlin, 10557 Germany"];
		}
	}
	
	reflex bidWasRejected when: !empty(reject_proposals) {
		// Bid was rejected, that's fine, we just mark as read.
		loop rejected over: reject_proposals {
			write "[" + name + "] My bid was rejected: " + rejected.contents[0];
		}
	}
	
	aspect base {
		draw square(3) color: rgb("yellow");
	}
}

species DutchAuctioneer parent: Auctioneer {
	int currentPrice;
	int minimumPrice;
	
	action determineWinner {
		// Do we have anything?
		loop positive over: proposes {
			if (winner = nil) {
				// We still need to check if the bid is serious.
				if (int(positive.contents[1]) >= currentPrice) {
					winner <- positive.sender;
					write "[" + name + "] Winner found, it is " + winner.name;
					do accept_proposal message: positive contents: ["Let me know your shipping address"];
				} else {
					do reject_proposal message: positive contents: ["You think you can try and cheat me?"];
				}
			} else {
				do reject_proposal message: positive contents: ["Sorry, someone else was faster"];
			}
			string _ <- positive.contents;
		}
	}
	
	action firstRound {
		// Here we actually start the auction.
		currentPrice <- rnd(1000, 2250);
		minimumPrice <- currentPrice - rnd(0, 600);
		// Set the state to bidding.
		state <- "bidding";
		// Regular bidding.
		do initiateBiddingRound;
	}
	
	action otherRounds {
		// Decrease the price by the set amount.
		currentPrice <- currentPrice - 250;
		// Would we, by decreasing, stay above the minimum?
		if (currentPrice >= minimumPrice) {
			// Decrease is legal, let us perform another bidding round.
			do initiateBiddingRound;
		} else {
			// Nobody could bid on this auction, so we discard it.
			write "[" + name + "] I could not sell this item";
			state <- "init";
		}
	}
	
	// Sends a CFP message to all participants for a specific number.
	action initiateBiddingRound {
		write "[" + name + "] Going for " + currentPrice + " (minimum " + minimumPrice + ")";
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: ["offer", currentPrice];
	}
}

species SealedAuctioneer parent: Auctioneer {
	action determineWinner {
		// Variables to keep track.
		agent bestBidder <- nil;
		int bestBid <- -1;
		list<message> local <- [];
		// Do we have anything?
		loop positive over: proposes {
			add positive to: local;
			int bid <- int(positive.contents[1]);
			if (bid > bestBid) {
				bestBidder <- agent(positive.sender);
				bestBid <- bid;
			}
		}
		// Now we let everyone know the outcome.
		loop msg over: local {
			if (msg.sender = bestBidder) {
				winner <- msg.sender;
				write "[" + name + "] Winner found, it is " + winner.name;
				do accept_proposal message: msg contents: ["Let me know your shipping address"];
			} else {
				do reject_proposal message: msg contents: ["Sorry, someone else bid more"];
			}
			string _ <- msg.contents;
		}
		winner <- bestBidder;
	}
	
	action firstRound {
		// A singular bidding round.
		state <- "bidding";
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: ["offer"];
	}
	
	action otherRounds {
		error message: "Can't go into more rounds in a sealed auction";
	}
}

species VickreyAuctioneer parent: Auctioneer {
	action determineWinner {
		// Variables to keep track.
		list<list> agentsBidsMessages <- [];
		// Do we have anything?
		loop positive over: proposes {
			add [agent(positive.sender), int(positive.contents[1]), positive] to: agentsBidsMessages;
		}
		int lastIndex <- length(agentsBidsMessages) - 1;
		int secondLastIndex <- max(0, lastIndex - 1); // Special case for singleton list.
		list<list> sortedBids <- agentsBidsMessages sort_by (int(each at 1));
		agent bestBidder <- agent((sortedBids at lastIndex) at 0);
		int secondBestPrice <- int((sortedBids at secondLastIndex) at 1);
		// Now we let everyone know the outcome.
		loop msg over: agentsBidsMessages accumulate (message(each at 2)) {
			if (msg.sender = bestBidder) {
				winner <- msg.sender;
				write "[" + name + "] Winner found, it is " + winner.name + " who has to pay " + secondBestPrice;
				do accept_proposal message: msg contents: ["Let me know your shipping address"];
			} else {
				do reject_proposal message: msg contents: ["Sorry, someone else bid more"];
			}
			string _ <- msg.contents;
		}
		winner <- bestBidder;
	}
	
	action firstRound {
		// A singular bidding round.
		state <- "bidding";
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: ["offer"];
	}
	
	action otherRounds {
		error message: "Can't go into more rounds in a sealed auction";
	}
}

species Auctioneer skills: [fipa] {
	string state <- "init" among: ["init", "start", "bidding"];
	list<agent> participants <- [];
	agent winner <- nil;
	
	action determineWinner virtual: true;
	action firstRound virtual: true;
	action otherRounds virtual: true;
	
	reflex receiveJoin when: state = "init" and (!empty(proposes) or !empty(refuses)) {
		loop join over: proposes {
			// This agent wants to join our auction.
			string _ <- join.contents;
			add agent(join.sender) to: participants;
		}
		loop refusal over: refuses {
			// This agent will not join, we just flush the message.
			string _ <- refusal.contents;
		}
		// We can only start the auction if there are actually participants.
		if (!empty(participants)) {
			// At this point, we can start the auction.
			state <- "start";
		} else {
			// Nobody wanted to join, new auction.
			write "[" + name + "] Nobody was interested, new auction time";
			state <- "init";
		}
	}
	
	// Receive responses FIRST.
	reflex receivePositiveBid when: !empty(proposes) {
		do determineWinner;
	}
	
	// Again, we also want to exhaust negative bids.
	reflex receiveNegativeBid when: !empty(refuses) {
		loop negative over: refuses {
			string _ <- negative.contents;
		}
	}
	
	// Should also do winner things in order.
	reflex receiveWinnerInformation when: !empty(informs) {
		// Get the shipping address.
		loop inform over: informs {
			write "[" + name + "] Sending the item to " + agent(inform.sender).name + "'s address: " + inform.contents[1];
		}
		// Reset everything, we can start a new auction.
		state <- "init";
	}
	
	// NOW we can trigger the main event loop for the auctioneer.
	reflex callback {
		if (state = "init") {
			// Reset some of the variables.
			participants <- [];
			winner <- nil;
			// Send out a join request to all of the bidders.
			do start_conversation to: globalBidders protocol: 'fipa-contract-net' performative: 'cfp' contents: ["notify", "There is a new auction starting"];
		} else if (state = "start") {
			do firstRound;
		} else if (winner = nil) {
			do otherRounds;
		}
	}
	
	aspect base {
		draw hexagon(3) color: rgb("grey");
	}
}

experiment myExperiment type:gui {
	output {
		display myDisplay {
			species Bidder aspect: base;
			species Auctioneer aspect: base;
		}
	}
}
