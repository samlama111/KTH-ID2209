/**
* Name: Exercise1
* Based on the internal empty template. 
* Author: samlama111
* Tags: 
*/


model Exercise1


global {
    int numberOfInformationCenters <- 1;
	int numberOfFestivalGuests <- 10;
	int numberOfStores <- 4;
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
		
		loop counter from: 1 to: numberOfStores {
        	Store my_agent <- Store[counter - 1];
        	my_agent <- my_agent.setName(counter);
        }
	}
}

species InformationCenter {
    string name <- "Information Center";
    point location <- [50, 50];
    
    aspect base {
        draw ellipse(2, 3) color: rgb("darkred");
    }
}

species FestivalGuest skills: [moving] {
	point targetPoint <- nil;
    string guestName <- "Undefined";
    int thirst <- rnd(100) max:100 update: thirst+1;
    int hunger <- rnd(100) max:100 update: hunger+1;
    bool isThirsty <- thirst > 80 update: thirst > 80;
    bool isHungry <- hunger > 80 update: hunger > 80;

    action setName(int num) {
		guestName <- "Guest " + num;
	}

    // Should be default but whatever
    reflex beIdle when: targetPoint = nil {
        if (isThirsty or isHungry) {
            targetPoint <- InformationCenter[0].location; 
        }
        else {
            do wander;
        }
    }

    reflex moveToTarget when: (targetPoint != nil) {
        do goto target: targetPoint;
    }

    reflex enterInformationCenter when: location distance_to(InformationCenter[0].location) < distanceThreshold {
	    list<Store> potentialStores;
	    if (isThirsty and isHungry) {
	        potentialStores <- Store where (each.hasFood and each.hasDrink);
	    } else if (isThirsty) {
	        potentialStores <- Store where (each.hasDrink);
	    } else if (isHungry) {
	        potentialStores <- Store where (each.hasFood);
	    }
	
	    if (length(potentialStores) > 0) {
	        Store closestStore <- potentialStores closest_to(self);
	        targetPoint <- closestStore.location;
	    } else {
	        write "No suitable store found.";
	    }
	}

    reflex enterStore when: (targetPoint != nil) and location distance_to(targetPoint) < distanceThreshold
    and targetPoint != InformationCenter[0].location {
    	Store ClosestStore <- Store closest_to(self);
    	
    	// TODO: should we handle cases when both can be satisifed?
        if (isHungry and ClosestStore.hasFood) {
            hunger <- 0;
            targetPoint <- nil;
        } else if (isThirsty and ClosestStore.hasDrink) {
            thirst <- 0;
            targetPoint <- nil;
        } else {
            write "Store does not have what I need.";
        }
    }

    aspect base {
		rgb agentColor <- rgb("green");
		
		if (isHungry and isThirsty) {
			agentColor <- rgb("red");
		} else if (isThirsty) {
			agentColor <- rgb("darkorange");
		} else if (isHungry) {
			agentColor <- rgb("purple");
		}
		
		draw circle(1) color: agentColor;
	}
}

species Store {
	string storeName <- "Undefined";
    point location <- [rnd(100), rnd(100)];
    int sells <- rnd(2);
    bool hasDrink <- sells = 0 or sells = 2;
    bool hasFood <- sells = 1 or sells = 2;
	
	action setName(int num) {
		storeName <- "Store " + num;
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
		
		draw square(2) color: agentColor;
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