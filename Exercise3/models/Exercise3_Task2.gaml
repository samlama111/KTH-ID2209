/**
* Name: Exercise3Task2
* Based on the internal empty template. 
* Author: samla
* Tags: 
*/


model Exercise3Task2


global {
    int numberOfPeople <- 5;
    int numberOfStages <- 3;

    init {
        create Person number:numberOfPeople;
        create Stage number:numberOfStages;
    }
}

species Person skills: [fipa, moving] {
    float lightshow_preference <- rnd(0.0, 1.0);
    float speakers_preference <- rnd(0.0, 1.0);
    float band_preference <- rnd(0.0, 1.0);
    list<Act> acts <- [];
    Act chosen_act <- nil;

    reflex chooseAct when: chosen_act = nil and !(empty(acts)) {
        write acts;
        chosen_act <- utility();
    }

    reflex getActs when: time = 0 {
    	acts <- [];
        do start_conversation to: list(Stage) protocol: 'fipa-query' performative: 'query' contents: ['acts']; 
    }

    reflex read_agreed_acts when: !(empty(agrees)) {
        write name + ' receives agree';
		loop i over: agrees {
			string _ <- i.contents;
			write 'agree message with content: ' + string(i.contents);
		}
    }

    reflex read_inform when: !(empty(informs)) {
        write name + ' receives inform';
        loop i over: informs {
        	string acts_information <- i.contents;
            write 'inform message with content: ' + i.contents[0];
			Act foundAct <- i.contents[0];
			//write 'Lightshow:' + foundAct.getLightshow();
            acts <- acts + foundAct;
        }
    }

    action utility {
        Act best_act <- nil;
        float best_utility <- 0.0;
        loop i over: acts {
            float utility <- 0.0;
            utility <- utility + (lightshow_preference * i.lightshow);
            utility <- utility + (speakers_preference * i.speakers);
            utility <- utility + (band_preference * i.band);
            if (utility > best_utility or best_utility = 0.0) {
                best_utility <- utility;
                best_act <- i;
            }
        }
        write 'Chosen (highest utility of: ' + best_utility + ') act is: ' + best_act;
        return best_act;
    }

    aspect base {
		rgb agentColor <- rgb("yellow");
				
      	draw circle(1) color: agentColor border: #black;
	}
	
}

species Stage skills: [fipa] {
    Act current_act <- nil;
    int act_duration <- rnd(10, 40);

    reflex accept_query when: !(empty(queries)) {
        loop i over: queries {
            if (i.contents[0] = 'acts') {
                //write name + ' receives query';
                string _ <- i.contents;
                do agree message: i contents: ['I have acts'];
                do inform message: i contents: [current_act];
            }
        }
    }

    reflex act {
    	//write current_act;
        if (current_act = nil) {
            create Act returns: createdAct;
            current_act <- createdAct[0];
        }
        //else if (current_act != nil) {
        //    if (act_duration = 0) {
        //       ask current_act {
        //            do die;
         //       }
         //       current_act <- nil;
         //       act_duration <- rnd(10, 40);
          //  }
           // else {
            //    act_duration <- act_duration - 1;
            //}
       // }
    }

    aspect base {
    	rgb stageColor <- rgb("darkgreen");
    	
    	if (current_act != nil) {
    		stageColor <- rgb("red");
    	}
		draw square(3) color: stageColor;
	}
}

species Act {
    float lightshow <- rnd(0.0, 1.0);
    float speakers <- rnd(0.0, 1.0);
    float band <- rnd(0.0, 1.0);
    
    action getLightshow {
    	return lightshow;
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