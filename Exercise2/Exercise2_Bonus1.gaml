/**
* Name: Exercise2_Bonus1
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise2_Bonus1

global {
	int numberOfBidders <- 3;
	int numberOfConcurrentAuctions <- 2;
	list<string> themes <- ["clothes", "cars", "horses"];
	
	init {
		create Bidder number: numberOfBidders;
		create Auctioneer number: numberOfConcurrentAuctions;
	}
}

species Bidder skills: [fipa] {
	string agentName <- "undefined";
	int budget <- rnd(0, 2000);
	list<string> interests;
	
	init {
		// Determine what the agent is interested in.
		interests <-rnd(1, length(themes)) among themes;
		write "[" + name + "] My interests are: " + interests;
	}
	
	reflex receiveMessage when: !empty(cfps) {
		// The current bidding process.
		loop incoming over: cfps {
			// Is it an auction start notification or is it an offer to bid?
			list msg <- incoming.contents;
			if (msg[0] = "notify") {
				string auctioneer <- agent(incoming.sender).name;
				// New auction is starting, do we want to join?
				if (interests contains msg[1]) {
					// Yes, we are interested.
					write "[" + name + "] I would like to join the " + auctioneer + " " + msg[1] + " auction";
					do propose message: incoming contents: ["I would like to join"];
				} else {
					// Not interested
					write "[" + name + "] I am not interested in the " + auctioneer + " " + msg[1] + " auction";
					do refuse message: incoming contents: ["Sorry, not interested"];
				}
			} else if (msg[0] = "offer") {
				// Auction we are part of is doing some bidding.
				int wanted <- int(incoming.contents[2]);
				write "[" + name + "] Received a bid offer for " + msg[1] + ", they want " + wanted;
				if (budget >= wanted) {
					// If we can afford it, we accept.
					write "[" + name + "] My budget is " + budget + ", so I accept";
					do propose message: incoming contents: ["I bid", wanted];
				} else {
					// If we can't, we reject. Perhaps this can be omitted?
					write "[" + name + "] My budget is " + budget + ", so I refuse";
					do refuse message: incoming contents: ["I reject"];
				}
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

species Auctioneer skills: [fipa] {
	string state <- "init" among: ["init", "start", "bidding"];
	list<agent> participants <- [];
	agent winner <- nil;
	string theme <- nil;
	int currentPrice;
	int minimumPrice;
	
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
		loop positive over: proposes {
			if (winner = nil) {
				winner <- positive.sender;
				// We still need to check if the bid is serious.
				if (int(positive.contents[1]) >= currentPrice) {
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
			theme <- (1 among themes) at 0;
			// Send out a join request to all of the bidders.
			write "[" + name + "] Starting new auction selling " + theme;
			do start_conversation to: list(Bidder) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["notify", theme];
		} else if (state = "start") {
			// Here we actually start the auction.
			currentPrice <- rnd(1000, 2250);
			minimumPrice <- currentPrice - rnd(0, 600);
			// Set the state to bidding.
			state <- "bidding";
			// Regular bidding.
			do initiateBiddingRound;
		} else if (winner = nil) {
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
	}
	
	// Sends a CFP message to all participants for a specific number.
	action initiateBiddingRound {
		write "[" + name + "] " + theme + " going for " + currentPrice + " (minimum " + minimumPrice + ")";
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: ["offer", theme, currentPrice];
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
