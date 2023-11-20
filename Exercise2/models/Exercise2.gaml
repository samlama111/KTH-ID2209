/**
* Name: Exercise2
* Based on the internal empty template. 
* Author: samla
* Tags: 
*/


model Exercise2

/* Insert your model definition here */


global {
    int numberOfInformationCenters <- 2;
	int numberOfFestivalGuests <- 10;
	int numberOfDrinkStores <- 2;
	int numberOfFoodStores <- 2;
	int numberOfBothStores <- 2;
	int numberOfStores <- numberOfDrinkStores + numberOfFoodStores + numberOfBothStores;
	int numberOfAuctioneers <- 1;
	int distanceThreshold <- 2;
	
	init {
        create InformationCenter number:numberOfInformationCenters;
		create Bidder number:numberOfFestivalGuests;
		create Store number:numberOfStores;
		create Auctioneer number:numberOfAuctioneers;
				
		loop counter from: 1 to: numberOfInformationCenters {
            InformationCenter my_agent <- InformationCenter[counter - 1];
        }
        
		loop counter from: 1 to: numberOfFestivalGuests {
        	Bidder my_agent <- Bidder[counter - 1];
        	my_agent <- my_agent.setName(counter);        	
        }
        // Name all of the stores.
        loop counter from: 1 to: numberOfStores {
        	Store store <- Store[counter - 1];
        	store <- store.setName(counter);
        }
        // Keep track of indices.
        int store_ctr <- 1;
        // Create all drink stores.
        loop counter from: 1 to: numberOfDrinkStores {
        	Store drink_store <- Store[store_ctr - 1];
        	drink_store <- drink_store.setType(true, false);
        	store_ctr <- store_ctr + 1;
        }
        // Create all food stores.
        loop counter from: 1 to: numberOfFoodStores {
        	Store food_store <- Store[store_ctr - 1];
        	food_store <- food_store.setType(false, true);
        	store_ctr <- store_ctr + 1;
        }
		// Create all both stores.
		loop counter from: 1 to: numberOfBothStores {
			Store both_store <- Store[store_ctr - 1];
			both_store <- both_store.setType(true, true);
			store_ctr <- store_ctr + 1;
		}
		// Add all stores to all information centers.
		list<Store> stores <- Store;
		loop counter from: 1 to: numberOfInformationCenters {
			InformationCenter info <- InformationCenter[counter - 1];
			info <- info.setStores(stores);
		}
	}
}

species InformationCenter {
    string name <- "Information Center";
    list<Store> stores;
    point location <- [rnd(50), rnd(50)];
    
    action setStores(list<Store> known) {
    	stores <- known;
    }
    
    aspect base {
        draw triangle(5) color: rgb("yellow");
    }
}

species FestivalGuest skills: [moving] {
	point targetPoint <- nil;
    string guestName <- "Undefined";
    int thirst <- rnd(75) max:100 update: thirst + rnd(0, 1);
    int hunger <- rnd(75) max:100 update: hunger + rnd(0, 1);
    bool isThirsty <- thirst > 80 update: thirst > 80;
    bool isHungry <- hunger > 80 update: hunger > 80;

    action setName(int num) {
		guestName <- "Guest " + num;
	}

    // Should be default but whatever.
    reflex beIdle when: targetPoint = nil {
        if (isThirsty or isHungry) {
            targetPoint <- (InformationCenter closest_to location).location; 
        } else {
            do wander;
        }
    }

    reflex moveToTarget when: (targetPoint != nil) {
        do goto target: targetPoint;
    }

    reflex enterInformationCenter when: location distance_to(InformationCenter closest_to location) < distanceThreshold {
	    if (not isThirsty and not isHungry) {
	    	return;
	    }
		ask (InformationCenter closest_to location) {
			list<Store> potentialStores <- stores where (each.hasDrink = myself.isThirsty and each.hasFood = myself.isHungry);
			if (length(potentialStores) > 0) {
				myself.targetPoint <- potentialStores closest_to myself.location;
			} else {
				write "ERROR: No suitable store found, check world creation.";
	        	write "TRACE: Conditions are " + myself.isThirsty + ", " + myself.isHungry;
			}
		}
	}

    reflex enterStore when: (targetPoint != nil) and location distance_to(targetPoint) < distanceThreshold
    and InformationCenter none_matches (each.location = targetPoint) {
    	Store ClosestStore <- Store closest_to(self);
    	// Fix for both hunger and thirst.
        if (isHungry and ClosestStore.hasFood) {
            hunger <- 0;
            targetPoint <- nil;
        }
        if (isThirsty and ClosestStore.hasDrink) {
            thirst <- 0;
            targetPoint <- nil;
        }
        // If we updated at least one of them, it should be nil.
        if (targetPoint != nil) {
            write "ERROR: Store does not have what I need.";
        }
    }

    aspect base {
		rgb agentColor <- rgb("green");
		if (isHungry and isThirsty) {
			agentColor <- rgb("black");
		} else if (isThirsty) {
			agentColor <- rgb("skyblue");
		} else if (isHungry) {
			agentColor <- rgb("deeppink");
		}	
		draw circle(1) color: agentColor;
	}
}

species Store {
	string storeName <- "Undefined";
    point location <- [rnd(100), rnd(100)];
    bool hasDrink <- false;
    bool hasFood <- false;
	
	action setName(int num) {
		storeName <- "Store " + num;
	}
	
	action setType(bool drink, bool food) {
		hasDrink <- drink;
		hasFood <- food;
	}
	
	aspect base {
		rgb agentColor <- rgb("lightgray");
		if (hasFood and hasDrink) {
			agentColor <- rgb("black");
		} else if (hasFood) {
			agentColor <- rgb("deeppink");
		} else if (hasDrink) {
			agentColor <- rgb("skyblue");
		}
		draw square(3) color: agentColor;
	}
}

species Bidder parent:FestivalGuest skills:[fipa] {
	// Determine for each auction a max price, 
	int max_price <- rnd(7000);
	//Increase by say 500 each time this increment is smaller than max-price, otherwise it's max-price
	int current_bid <- rnd(2000); 
	bool canBid <- true;

	action reset {
		max_price <- rnd(7000);
		current_bid <- rnd(2000);
	}

	
	reflex receiveCalls when: !empty(cfps) {
		loop cfpMsg over: cfps {
			write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(cfpMsg.sender).name + ' with content: ' + cfpMsg.contents;
			
			// TODO: add in bonus
			//if (interested in genre/auction) {
			//	do refuse message: cfpMsg contents:["Not interested in this auction. " + name];
			//} else {
				//do propose message: cfpMsg contents:["Proposal from " + name, current_bid];
			//}
			if (canBid) {
				do propose message: cfpMsg contents:["Proposal from " + name, current_bid];
			}
		}
	}
	
	reflex receiveRejectProposals when: !empty(reject_proposals) {
		loop rejectMsg over: reject_proposals {
			write '(Time ' + time + '): ' + name + ' is rejected.';
			
			// Read content to remove the message from reject_proposals variable.
			bool canBidFurther <- rejectMsg.contents[1];
			canBid <- canBidFurther;
			// Read content to remove the message from accept_proposals variable.
			string dummy <- rejectMsg.contents;
		}
		reject_proposals <- [];
	}
	
	reflex receiveAcceptProposals when: !empty(accept_proposals) {		
		write('accept_proposals');		
		loop acceptMsg over: accept_proposals {
			write '(Time ' + time + '): ' + name + ' is accepted.';
			do inform message: acceptMsg contents:["Inform from " + name];
			
			bool canBidFurther <- acceptMsg.contents[1];
			canBid <- canBidFurther;
			// Read content to remove the message from accept_proposals variable.
			string dummy <- acceptMsg.contents;
		}
		accept_proposals <- [];
	}
}

species Auctioneer skills: [fipa] {
	int price;
	bool auction_started <- false;
	bool waiting_for_winner <- false;
	int rounds <- 0;
	int max_rounds <- 10;
	int price_reduction_step <- 500;
	
	reflex manageAuction {
		write auction_started;
		write waiting_for_winner;
		if (auction_started = false) {
			do startNewAuction;
		} else {
			if (waiting_for_winner = true) {
				write 'Waiting for winner to inform me.';
				return;
			}
			if (rounds < max_rounds) {
				rounds <- rounds + 1;
				price <- price - price_reduction_step;
				do start_conversation to: list(Bidder) protocol: 'fipa-contract-net' performative: 'cfp' contents: ['All Bidders: Send me your proposals!', price];
			} else {
				write 'Auction finished.';
				auction_started <- false;
				rounds <- 0;
			}
		}
	}
	
	reflex receiveRefuseMessages when: !empty(refuses) {
		loop refuseMsg over: refuses {
			write '(Time ' + time + '): ' + agent(refuseMsg.sender).name + ' refused.';
			
			// Read content to remove the message from refuses variable.
			string dummy <- refuseMsg.contents;
		}
	}
	
	reflex receiveProposals when: !empty(proposes) {
		bool proposal_accepted <- false;
		loop proposeMsg over: proposes {	
			write '(Time ' + time + '): ' + agent(proposeMsg.sender).name + ' proposed ' + proposeMsg.contents[1] + ' for the auction.';
			int proposedPrice <- proposeMsg.contents[1];
			if (proposedPrice <= price or proposal_accepted = true) {
				do reject_proposal message: proposeMsg contents: ['Sorry!', true];
			} else {
				proposal_accepted <- true;
				waiting_for_winner <- true;
				do accept_proposal message: proposeMsg contents: ['Great! Inform me.', false];
			}
			proposes <- [];
			// Read content to remove the message from proposes variable.
			string dummy <- proposeMsg.contents;
		}
	}

	reflex receiveInformMessages when: !empty(informs) {
		loop informMsg over: informs {
			write '(Time ' + time + '): ' + agent(informMsg.sender).name + ' informed.';
			write '(Time ' + time + '): ' + agent(informMsg.sender).name + ' is the winner of the auction.';
			
			waiting_for_winner <- false;
			// auction_started <- false;
			rounds <- 0;

			// Read content to remove the message from informs variable.
			string dummy <- informMsg.contents;
		}
	}

	action startNewAuction {
		// Init auction information
		auction_started <- true;
		rounds <- 0;
		price <- rnd(4000);
	}
	
	aspect base {
		draw hexagon(3) color: rgb("grey");
	}
}

experiment myExperiment type:gui {
	output {
		display myDisplay {
			species InformationCenter aspect:base;
			species Bidder aspect:base;
			species Store aspect:base;
			species Auctioneer aspect:base;
		}
	}
}