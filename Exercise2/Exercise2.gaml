/**
* Name: Exercise2
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise2

global {
	int numberOfBidders <- 3;
	int distanceThreshold <- 2;
	int maximumAuctionRounds <- 10;
	
	init {
		create Bidder number: numberOfBidders;
		create Auctioneer;
	}
}

species Bidder skills: [fipa] {
	string agentName <- "undefined";
	int budget <- rnd(0, 2000);
	
	reflex receiveBiddingRound when: !empty(cfps) {
		// The current bidding process.
		loop incoming over: cfps {
			int wanted <- int(incoming.contents[1]);
			write "[" + name + "] Received a CFP initiation, they want " + wanted;
			if (budget >= wanted) {
				// If we can afford it, we accept.
				write "[" + name + "] My budget is " + budget + ", so I accept";
				do propose message: incoming contents: ["I bid"];
			} else {
				// If we can't, we reject. Perhaps this can be omitted?
				write "[" + name + "] My budget is " + budget + ", so I refuse";
				do refuse message: incoming contents: ["I reject"];
			}
		}
	}
	
	reflex bidWasAccepted when: !empty(accept_proposals) {
		// Bid was accepted here, so we need to send an inform.
		loop accepted over: accept_proposals {
			write "[" + name + "] My bid was accepted: " + accepted.contents;
			do inform message: accepted contents: ["Here is my address", "Spreeweg 1, Berlin, 10557 Germany"];
		}
	}
	
	reflex bidWasRejected when: !empty(reject_proposals) {
		// Bid was rejected, that's fine, we just mark as read.
		loop rejected over: reject_proposals {
			write "[" + name + "] My bid was rejected: " + rejected.contents;
		}
	}
	
	aspect base {
		draw square(3) color: rgb("yellow");
	}
}

species Auctioneer skills: [fipa] {
	int round <- 0;
	agent winner <- nil;
	int currentPrice;
	int minimumPrice;
	
	// Receive responses FIRST.
	reflex receivePositiveBid when: !empty(proposes) {
		loop positive over: proposes {
			if (winner = nil) {
				winner <- positive.sender;
				do accept_proposal message: positive contents: ["Let me know your shipping address"];
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
		round <- 0;
	}
	
	// NOW we can trigger the main event loop for the auctioneer.
	reflex callback {
		if (round = 0) {
			// The first round is special because we need to set the price of what we are currently selling.
			currentPrice <- rnd(1000, 3000);
			minimumPrice <- currentPrice - rnd(0, 600);
			winner <- nil;
			// Regular bidding.
			do initiateBiddingRound;
		} else if (round < maximumAuctionRounds) {
			// Checking bids.
			if (winner != nil) {
				write "[" + name + "] Winner found, it is " + winner.name;
				
			} else {
				// Decrease the price possibly, and ask people to bid.
				currentPrice <- max(minimumPrice, currentPrice - 250);
				do initiateBiddingRound;
			}
		} else {
			// Nobody could bid on this auction, so we discard it.
			write "[" + name + "] Nobody bid on the auction, donating the item to charity";
			round <- 0;
		}
	}
	
	// Sends a CFP message to all participants for a specific number.
	action initiateBiddingRound {
		write "[" + name + "] Starting new bidding for " + currentPrice + ", minimum " + minimumPrice;
		do start_conversation to: list(Bidder) protocol: 'fipa-contract-net' performative: 'cfp' contents: ['All Bidders: Send me your proposals!', currentPrice];
		round <- round + 1;
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
