/**
* Name: Exercise1
* Based on the internal empty template. 
* Author: samlama111, Paul Hübner
* Tags: 
*/


model Exercise1


global {
    int numberOfInformationCenters <- 1;
	int numberOfFestivalGuests <- 10;
	int numberOfDrinkStores <- 2;
	int numberOfFoodStores <- 2;
	int numberOfBothStores <- 2;
	int numberOfStores <- numberOfDrinkStores + numberOfFoodStores + numberOfBothStores;
	int distanceThreshold <- 2;
	
	init {
        create InformationCenter number:numberOfInformationCenters;
		create FestivalGuest number:numberOfFestivalGuests;
		create Store number:numberOfStores;
				
		loop counter from: 1 to: numberOfInformationCenters {
            InformationCenter my_agent <- InformationCenter[counter - 1];
        }
        
		loop counter from: 1 to: numberOfFestivalGuests {
        	FestivalGuest my_agent <- FestivalGuest[counter - 1];
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
    point location <- [50, 50];
    
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
    and targetPoint != InformationCenter[0].location {
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

experiment myExperiment type:gui {
	output {
		display myDisplay {
			species InformationCenter aspect:base;
			species FestivalGuest aspect:base;
			species Store aspect:base;
		}
	}
}