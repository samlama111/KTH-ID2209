/**
* Name: Exercise3_Bonus
* Based on the internal empty template. 
* Author: samla, ph
* Tags: 
*/


model Exercise3Bonus

// Simplifications:
//  * Make all stages end at the same time.
//  * Make Person0 be the leader.
//  * Crowd mass = % of numberOfPeople at this stage.
//
// Protocol:
//  * When all agents are going to their act, the leader sends a query to ask where everyone is going.
//  * The response includes: actor ID, stage/act, utility (excl. crowd mass), crowd mass coefficient.
//  * The leader calculates the global utility by adding the crowd value to each utility and summing up all utilities.
//  * The leader sees if there is a switch that can increase the utility.
//  * IF there is a switch, the agent orders the specific agents to swap. Another round starts.
//  * ELSE, there is a maximum utility, and we can enjoy the show.


global {
    int numberOfPeople <- 3;
    int numberOfStages <- 3;
    int danceFloorRadius <- 5;

    init {
        create Person number:numberOfPeople;
        create Stage number:numberOfStages;
        Person[0].leader <- true;
    }
}

species Person skills: [fipa, moving] {
    float lightshowPreference <- rnd(0.0, 1.0);
    float speakersPreference <- rnd(0.0, 1.0);
    float bandPreference <- rnd(0.0, 1.0);
    float openingPreference <- rnd(0.0, 1.0);
    float familyPreference <- rnd(0.0, 1.0);
    float moshPreference <- rnd(0.0, 1.0);
    float crowdPreference <- rnd(-2.0, 2.0);
    float actExpiry <- -1.0; // Separate because otherwise agents are dead.
    Act chosenAct <- nil;
    float chosenUtility <- -1.0;
    int pauseCounter <- 2; // Small pause to fake thinking.
    bool leader <- false;
    string optimization <- "noop" among: ["tosend", "waiting", "sent", "noop"];
    
    // Do we still hear music?
    reflex listenMusic when: chosenAct != nil {
    	// Oh no it expired.
    	if (time = actExpiry) {
    		// Set it to null, so we can ask again.
    		chosenAct <- nil;
    		optimization <- "noop";
    		pauseCounter <- 5;
    	}
    }
    
    reflex decrementPausecoutner when: chosenAct = nil and pauseCounter > 0 {
    	pauseCounter <- pauseCounter - 1;
    }
    
    // Before the receiving of acts, so we don't get it twice.
    reflex optimize when: optimization = "tosend" {
    	// Do some optimizations!
    	if (leader) {
    		write("[" + name + "] Performing another round of optimizations");
    		list<agent> targets <- [];
    		loop i over: list(Person) {
    			if (i.name != name) {
    				add i to: targets;
    			}
    		}
	    	do start_conversation to: targets protocol: 'fipa-query' performative: 'query' contents: ['target'];
	    	// So we don't re-send until we get the response.
	    	optimization <- "waiting";
    	}
    }
    
    reflex processMovedConfirmations when: chosenAct != nil and optimization = "sent" and !empty(agrees) {
    	loop i over: agrees {
			list _ <- i.contents;
		}
    }
    
    // The agents have moved, so we need to do another cycle.
    reflex processMovedAgents when: chosenAct != nil and optimization = "sent" and !empty(informs) {
    	loop i over: informs {
    		list c <- i.contents;
    	}
    	// Someone moved, let's do another round of optimizations.
    	optimization <- "tosend";
    }
    
    // Do we need to say where we are going?
    reflex receiveQueries when: chosenAct != nil and !empty(queries) {
        loop i over: queries {
            if (i.contents[0] = 'target') {
                string _ <- i.contents;
                do agree message: i contents: ['I am going somewhere'];
                do inform message: i contents: [self, chosenAct, chosenUtility, crowdPreference];
            } else if (i.contents[0] = 'goto') {
            	chosenAct <- i.contents[1];
            	write("[" + name + "] I am swapping to " + chosenAct);
            	do agree message: i contents: ['Moving there'];
                do inform message: i contents: [chosenAct];
            }
        }
    }
    
   	// We receive all the acts, and decide which one we want to go to!
    reflex processReceivedActs when: chosenAct = nil and optimization = "noop" and !empty(informs) {
        write("[" + name + "] Received information from " + length(informs) + " stages on what the acts are");
        list<Act> options <- [];
        // Read all of the possibilities.
        loop i over: informs {
			Act foundAct <- i.contents[0];
			add foundAct to: options;
        }
        // Choose the one that will provide the highest utility to us.
        Act bestAct <- nil;
        float bestUtility <- -100.0;
    	write("[" + name + "] Utilities are:");
        loop i over: options {
            float utility <- calculateUtility(i);
            write("- Act " + i + " --> " + utility);
            if (utility > bestUtility) {
                bestUtility <- utility;
                bestAct <- i;
            }
        }
        chosenAct <- bestAct;
        chosenUtility <- bestUtility;
        actExpiry <- chosenAct.expiry;
        pauseCounter <- 0;
        write("[" + name + "] I have picked act " + bestAct + " with utility " + bestUtility);
        optimization <- "tosend";
    }
    
    action calculateUtility(Act i) type: float {
    	float utility <- 0.0;
        utility <- utility + (lightshowPreference * i.lightshow);
        utility <- utility + (speakersPreference * i.speakers);
        utility <- utility + (bandPreference * i.band);
        utility <- utility + (openingPreference * i.opening);
        utility <- utility + (familyPreference * i.family);
        utility <- utility + (moshPreference * i.mosh);
        return utility;
    }
	// Asks the stages for the acts that are currently being performed.
    reflex determineActs when: chosenAct = nil and pauseCounter <= 0 {
        do start_conversation to: list(Stage) protocol: 'fipa-query' performative: 'query' contents: ['acts']; 
    }

	// Part of the FIPA protocol, but we don't do any of this.
    reflex markAgreesAsRead when: optimization = "noop" and !empty(agrees) {
    	// Clear out the mailbox.
		loop i over: agrees {
			list _ <- i.contents;
		}
    }
    
    reflex travel when: chosenAct != nil and (location distance_to (chosenAct.location) > (2 * danceFloorRadius)) {
    	do goto target: chosenAct.location;
    }
    
    // DANSA MED OSS, KLAPPA ERA HÄNDER
    reflex dance when: chosenAct != nil and (location distance_to (chosenAct.location) <= (2 * danceFloorRadius)) {
    	do wander;
    }
    
    // Leader and needs to figure out where all of the others are going.
    reflex processReceivedGoals when: chosenAct != nil and optimization = "waiting" and !empty(informs) {
    	write("[" + name + "] Got the information from all other agents");
    	// Keep track of all the acts' participants.
    	list<Act> acts <- []; // No idea how to get keys otherwise.
    	map<Act, list<Person>> actToParticipants <- [];
    	// Read all of the information.
    	loop i over: informs {
    		Person p <- i.contents[0];
    		Act a <- i.contents[1];
    		float ut <- float(i.contents[2]);
    		float cr <- float(i.contents[3]);
    		write("- " + p.name + " with utility " + ut + " and coefficient " + cr);
    		do registerPerson(acts, actToParticipants, p, a);
    	}
    	write("- " + name + " with utility " + calculateUtility(chosenAct) + " and coefficient " + crowdPreference);
    	// Make sure to add self!!!
    	do registerPerson(acts, actToParticipants, self, chosenAct);
    	write(actToParticipants);
    	// Now we can optimize global utility.
    	float gCurrent <- calculateGlobalUtility(acts, actToParticipants);
    	write("[" + name + "] Global utility before potential swap is " + gCurrent);
    	list<Person> swap <- findSwap(acts, actToParticipants, gCurrent);
    	// Do we have a better arrangement?
    	if (not empty(swap)) {
    		Person i <- swap at 0;
    		Person j <- swap at 1;
    		Act iAct <- i.chosenAct;
    		Act jAct <- j.chosenAct;
    		// Tell them where to go.
    		do sendSwap(i, iAct, j, jAct);
    	}
		// Stop here.
		// If someone moved, then this will start another tosend chain.
		optimization <- "sent";
    }
    
    // Swap depends on who self is, sending messages to self is a bit crazy.
    action sendSwap(Person i, Act iAct, Person j, Act jAct) {
    	if (i = self) {
    		chosenAct <- jAct;
    		do start_conversation to: [j] protocol: 'fipa-query' performative: 'query' contents: ['goto', iAct];
    		write("[" + name + "] I am swapping to " + chosenAct);
    	} else if (j = self) {
    		do start_conversation to: [i] protocol: 'fipa-query' performative: 'query' contents: ['goto', jAct];
    		chosenAct <- iAct;
    		write("[" + name + "] I am swapping to " + chosenAct);
    	} else {
    		do start_conversation to: [i] protocol: 'fipa-query' performative: 'query' contents: ['goto', jAct];
    		do start_conversation to: [j] protocol: 'fipa-query' performative: 'query' contents: ['goto', iAct];
    	}
    }
	
	// Registers a person and act pair to the data structure.
	action registerPerson(list<Act> acts, map<Act, list<Person>> m, Person p, Act a) {
		if (not (acts contains a)) {
			add a to: acts;
		}
		list<Person> l <- m[a];
		if (l = nil) {
			l <- [];
		}
		add p to: l;
		m[a] <- l;
	}
	
	// Finds a swap, if it exists, that improves global global utility the most.
	action findSwap(list<Act> acts, map<Act, list<Person>> m, float curr) type: list<Person> {
		list<Person> ps <- m accumulate (each);
		float best <- curr;
		list<Person> swap <- [];
		// There will be symmetries, wontfix.
		loop i over: ps {
			loop j over: ps {
				// Don't swap with self.
				if (i = j) {
					continue;
				}
				// Where are they?
				Act iAct <- i.chosenAct;
				Act jAct <- j.chosenAct;
				// If same place, won't change anything, continue.
				if (iAct = jAct) {
					continue;
				}
				// Let's create a copy of our environment.
				map<Act, list<Person>> n <- copy(m);
				// Swap them.
				list<Person> iList <- copy(n[iAct]);
				remove i from: iList;
				add j to: iList;
				n[iAct] <- iList;
				list<Person> jList <- copy(n[jAct]);
				remove j from: jList;
				add i to: jList;
				n[jAct] <- jList;
				// Is there a change in utility?
				float newGUtility <- calculateGlobalUtility(acts, n);
				if (newGUtility > best) {
					best <- newGUtility;
					swap <- [i, j];
				}
			}
		}
		if (not empty(swap)) {
			write("[" + name + "] Global utility after potential swap is " + best);
		}
		return swap;
	}
    
    // Does what the name suggests.
    action calculateGlobalUtility(list<Act> acts, map<Act, list<Person>> m) type: float {
    	float u <- 0.0;
    	loop act over: acts {
    		list<Person> ps <- m[act];
    		if (ps = nil or empty(ps)) {
    			continue;
    		}
    		float crowd <- length(ps) / numberOfPeople;
    		loop p over: ps {
    			float pu <- p.calculateUtility(act);
    			float cu <- p.crowdPreference * crowd;
    			u <- u + pu + cu;
    		}
    	}
    	return u;
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
	float expiry <- time + 10000;
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