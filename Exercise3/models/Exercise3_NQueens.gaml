/**
* Name: Exercise3NQueens
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise3NQueens


global {
	
	int numberOfQueens <- 7 min: 4 max: 20;

	init {
		int index <- 0;
		create Queen number: numberOfQueens;
		// Create all queens and set them up as a doubly linked list.
		loop counter from: 1 to: numberOfQueens {
			Queen queen <- Queen[counter - 1];
			Queen pred <- nil;
			if (counter - 2 >= 0) {
				pred <- Queen[counter - 2];
				pred <- pred.init2(queen);
			}
			queen <- queen.init1(index, pred);
			index <- index + 1;
		}
		// Activate the first queen.
		Queen[0].active <- true;
	}
}


species Queen skills: [fipa] {
	ChessBoard myCell <- nil; 
	int id; 
	bool active <- false;
	Queen pred;
	Queen succ;
	list<ChessBoard> memory <- [];
	
	//
	// PASSIVE (NOT THE ONE BEING PLACED) FUNCTIONALITY.
	//
	
	reflex passiveIncoming when: !active and !empty(informs) {
		loop msg over: informs {
			string act <- msg.contents[0];
			// Activate and backtrack do the same thing.
			// If statement here in case needed in the future.
			if (act = "activate") {
				do passiveActivate;
			} else if (act = "backtrack") {
				write("[" + id + "] Received backtrack signal");
				do passiveActivate;
			} else {
				error "Unknown action: " + act;
			}
		}
	}
	
	action passiveActivate {
		myCell <- nil;
		active <- true;
	}
	
	
	//
	// ACTIVE (THE ONE BEING PLACED) FUNCTIONALITY.
	//
	
	reflex activePlace when: active and myCell = nil {
		// See where we can go.
		list<ChessBoard> locs <- utilGetPossibleLocations();
		write("[" + id + "] Need to determine my location");
		write("[" + id + "] Possible: ");
		loop loc over: locs {
			write("- " + utilStr(loc));
		}
		// If there are NO possible locations, we need to backtrack.
		if (empty(locs)) {
			write("[" + id + "] I have no options, backtrack");
			// Wipe our memory so next time we are activated we can go wherever.
			memory <- [];
			// Deactivate and send backtrack.
			active <- false;
			myCell <- nil;
			do activeSendBacktrack;
			return;
		}
		// Otherwise, we just pick the first one!
		do activeMakeMove(first(locs));
	}
	
	action activeMakeMove(ChessBoard pos) {
		// Perform the move!
		myCell <- pos;
		add pos to: memory;
		write("[" + id + "] Going to: " + utilStr(pos));
		// Let the next one be placed.
		active <- false;
		do activeSendActivateSuccessor;
	}
	
	action activeSendActivateSuccessor {
		if (succ != nil) {
			do start_conversation to: [succ] protocol: "fipa-propose" performative: "inform" contents: ["activate"];
		}
	}
	
	action activeSendBacktrack {
		if (pred != nil) {
			do start_conversation to: [pred] protocol: "fipa-propose" performative: "inform" contents: ["backtrack"];
		} else {
			error "Unsolveable problem";
		}
	}
	
	//
	// UTILITY ACTIONS.
	//
	
	action utilGetPossibleLocations type: list<ChessBoard> {
		list<ChessBoard> queens <- [];
		loop queen over: Queen {
			if (queen.myCell != nil) {
				add queen.myCell to: queens;
			}
		}
		write("[" + id + "] Checking against " + length(queens) + " queens");
		list<ChessBoard> possible <- [];
		loop x from: 1 to: numberOfQueens {
			loop y from: 1 to: numberOfQueens {
				ChessBoard cell <- ChessBoard[x - 1, y - 1];
				// Ignore positions we have visited before.
				if (memory contains cell) {
					continue;
				}
				// Possible if there is no queen.
				if (utilIsMovePossible(cell, queens)) {
					add cell to: possible;
				}
			}
		}
		return possible;
	}
	
	action utilIsMovePossible(ChessBoard candidate, list<ChessBoard> queens) type: bool {
		loop queen over: queens {
			bool killedHere <- utilsWillQueenBeKilled(candidate, queen);
			if (killedHere) {
				//write("" + candidate + " is incomp with " + queen);
				return false;
			}
		}
		return true;
	}
	
	// https://stackoverflow.com/questions/41432956/checking-for-horizontal-vertical-and-diagonal-pairs-given-coordinates
	action utilsWillQueenBeKilled(ChessBoard candidate, ChessBoard queen) type: bool {
		int x1 <- candidate.grid_x;
		int y1 <- candidate.grid_y;
		int x2 <- queen.grid_x;
		int y2 <- queen.grid_y;
		int dy <- y2 - y1;
		int dx <- x2 - x1;
		bool clause1 <- dx = 0;
		bool clause2 <- dy = 0;
		bool clause3 <- dx = dy;
		bool clause4 <- dx = -dy;
		bool res <- clause1 or clause2 or clause3 or clause4;
		//write("Debug: " + clause1 + clause2 + clause3 + clause4);
		return res;
	}
	
	action utilStr(ChessBoard pos) type: string {
		return "X=" + pos.grid_x + ", Y=" + pos.grid_y;
	}
	
	// 
	// CONSTRUCTION ACTIONS.
	//
	
	action init1(int queenId, Queen predecessor) type: Queen {
		id <- queenId;
		pred <- predecessor;
		return self;
	}
	
	action init2(Queen successor) type: Queen {
		succ <- successor;	
		return self;
	}
	
	aspect base {
		if (myCell != nil) {
			location <- myCell.location;
			float size <- 30 / numberOfQueens;
			draw circle(size) color: #magenta;
		}
	}
}
	
	
grid ChessBoard width: numberOfQueens height: numberOfQueens neighbors: 8 { 
	init{
		if (even(grid_x) and even(grid_y) or !even(grid_x) and !even(grid_y)){
			color <- #black;
		} else {
			color <- #white;
		}
	}
}

experiment NQueensProblem type: gui {
	output {
		display ChessBoard {
			grid ChessBoard border: #black;
			species Queen aspect: base;
		}
	}
}