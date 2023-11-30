/**
* Name: Exercise3Task2
* Based on the internal empty template. 
* Author: samla
* Tags: 
*/


model Exercise3Task2


global {
    int numberOfPeople <- 1;
    int numberOfStages <- 3;
    int danceFloorRadius <- 5;

    init {
        create Person number:numberOfPeople;
        create Stage number:numberOfStages;
    }
}

species Person skills: [fipa, moving] {
    float lightshowPreference <- rnd(0.0, 1.0);
    float speakersPreference <- rnd(0.0, 1.0);
    float bandPreference <- rnd(0.0, 1.0);
    float openingPreference <- rnd(0.0, 1.0);
    float familyPreference <- rnd(0.0, 1.0);
    float moshPreference <- rnd(0.0, 1.0);
    float actExpiry <- -1.0; // Separate because otherwise agents are dead.
    Act chosenAct <- nil;
    int pauseCounter <- 2; // Small pause to fake thinking.
    
    // Do we still hear music?
    reflex listenMusic when: chosenAct != nil {
    	// Oh no it expired.
    	if (time = actExpiry) {
    		// Set it to null, so we can ask again.
    		chosenAct <- nil;
    		pauseCounter <- 5;
    	}
    }
    
    reflex decrementPausecoutner when: chosenAct = nil and pauseCounter > 0 {
    	pauseCounter <- pauseCounter - 1;
    }
    
   	// We receive all the acts, and decide which one we want to go to!
    reflex processReceivedActs when: chosenAct = nil and !empty(informs) {
        write("[" + name + "] Received information from " + length(informs) + " stages on what the acts are");
        list<Act> options <- [];
        // Read all of the possibilities.
        loop i over: informs {
			Act foundAct <- i.contents[0];
			add foundAct to: options;
        }
        // Choose the one that will provide the highest utility to us.
        Act bestAct <- nil;
        float bestUtility <- -1.0;
    	write("[" + name + "] Utilities are:");
        loop i over: options {
            float utility <- 0.0;
            utility <- utility + (lightshowPreference * i.lightshow);
            utility <- utility + (speakersPreference * i.speakers);
            utility <- utility + (bandPreference * i.band);
            utility <- utility + (openingPreference * i.opening);
            utility <- utility + (familyPreference * i.family);
            utility <- utility + (moshPreference * i.mosh);
            write("- Act " + i + " --> " + utility);
            if (utility > bestUtility) {
                bestUtility <- utility;
                bestAct <- i;
            }
        }
        chosenAct <- bestAct;
        actExpiry <- chosenAct.expiry;
        pauseCounter <- 0;
        write("[" + name + "] I have picked act " + bestAct + " with utility " + bestUtility);
    }

	// Asks the stages for the acts that are currently being performed.
    reflex determineActs when: chosenAct = nil and pauseCounter <= 0 {
        do start_conversation to: list(Stage) protocol: 'fipa-query' performative: 'query' contents: ['acts']; 
    }

	// Part of the FIPA protocol, but we don't do any of this.
    reflex markAgreesAsRead when: chosenAct = nil and !empty(agrees) {
    	// Clear out the mailbox.
		loop i over: agrees {
			string _ <- i.contents;
		}
    }
    
    reflex travel when: chosenAct != nil and (location distance_to (chosenAct.location) > (2 * danceFloorRadius)) {
    	do goto target: chosenAct.location;
    }
    
    // DANSA MED OSS, KLAPPA ERA HÄNDER
    reflex dance when: chosenAct != nil and (location distance_to (chosenAct.location) <= (2 * danceFloorRadius)) {
    	do wander;
    }
    
    aspect base {
		rgb agentColor <- rgb("yellow");
      	draw circle(1) color: agentColor border: #black;
	}
	
}

species Stage skills: [fipa] {
    Act currentAct <- nil;
    int actDuration <- rnd(10, 40);

    reflex acceptQuery when: !(empty(queries)) {
        loop i over: queries {
            if (i.contents[0] = 'acts') {
                string _ <- i.contents;
                do agree message: i contents: ['I have acts'];
                do inform message: i contents: [currentAct];
            }
        }
    }

    reflex stageLoop {
    	// If there is no act, we must give one.
        if (currentAct = nil) {
	    	do newAct;
        }
        // If there is an existing act that expired, make a new one.
        // This must be EXPLICITLY greater so the listeners have a chance to switch.
        if (currentAct != nil and time >= currentAct.expiry) {
        	// Kill existing one.
        	ask currentAct {
        		do die;
        	}
        	currentAct <- nil;
        }
    }
    
    action newAct {
    	create Act returns: createdAct;
    	currentAct <- createdAct[0];
     	currentAct <- currentAct.setLocation(self);
    }

    aspect base {
    	rgb stageColor <- #black;
    	if (currentAct != nil) {
    		// RGB is a must.
    		int n <- int(time);
    		if (n mod 3 = 0) {
    			stageColor <- #red;
    		} else if (n mod 3 = 1) {
    			stageColor <- #green;
    		} else if (n mod 3 = 2) {
    			stageColor <- #blue;
    		}
    	}
    	// Size is twice the radius.
		draw hexagon(danceFloorRadius * 2) at: location color: stageColor depth: -1.0;
	}
}

species Act {
	float expiry <- time + rnd(100, 200);
    float lightshow <- rnd(0.0, 1.0);
    float speakers <- rnd(0.0, 1.0);
    float band <- rnd(0.0, 1.0);
    float opening <- rnd(0.0, 1.0);
    float family <- rnd(0.0, 1.0);
    float mosh <- rnd(0.0, 1.0);
    Stage stage <- nil;
    
    action setLocation(Stage s) type: Act {
    	stage <- s;
    	location <- s.location;
    	return self;
    }

    aspect base {
        draw circle(1) color: rgb("red");
    }
}

experiment myExperiment type:gui {
	output {
		display myDisplay {
			species Person aspect:base;
			species Stage aspect:base;
		}
	}
}