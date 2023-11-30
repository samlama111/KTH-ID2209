/**
* Name: Exercise3NQueens
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise3NQueens


global {
	
	int numberOfQueens <- 20 min: 4 max: 20;

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
	list<ChessBoard> others <- [];
	list<int> memory <- [];
	
	//
	// PASSIVE (NOT THE ONE BEING PLACED) FUNCTIONALITY.
	//
	
	reflex passiveIncoming when: !active and !empty(informs) {
		loop msg over: informs {
			string act <- msg.contents[0];
			// Activate and backtrack do the same thing, mostly.
			if (act = "activate") {
				list<ChessBoard> queens <- msg.contents[1];
				do passiveActivate(queens);
			} else if (act = "backtrack") {
				write("[" + id + "] Received backtrack signal");
				// Our previous knowledge is still correct, apply it to ourselves.
				do passiveActivate(others);
			} else {
				error "Unknown action: " + act;
			}
		}
	}
	
	action passiveActivate(list<ChessBoard> queens) {
		myCell <- nil;
		active <- true;
		others <- queens;
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
			//write("[" + id + "] I have no options, backtrack");
			// Wipe our memory so next time we are activated we can go wherever.
			memory <- [];
			others <- [];
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
		add pos.grid_y to: memory;
		write("[" + id + "] Going to: " + utilStr(pos));
		// Let the next one be placed.
		active <- false;
		do activeSendActivateSuccessor;
	}
	
	action activeSendActivateSuccessor {
		if (succ != nil) {
			list<ChessBoard> queens <- others + [myCell];
			do start_conversation to: [succ] protocol: "fipa-propose" performative: "inform" contents: ["activate", queens];
		} else {
			write("We are done after " + (int(time) + 1) + " cycles");
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
		list<int> ys <- [];
		// Go through every possible cell on its own row.
		// We only let them go on its own row to allow backtracking.
		loop y1 from: 1 to: numberOfQueens {
			// If we've already been here, we skip.
			int y <- y1 - 1;
			if (memory contains y) {
				continue;
			}
			// If this conflicts with other queens (only last one).
			if (not utilIsMovePossible(id, y, others)) {
				continue;
			}
			add y to: ys;
		}
		// Optimization: prefer 2-3 away from predecessor.
		int nextOpen;
		if (pred != nil) {
			nextOpen <- (last(others)).grid_y + 2;
		} else {
			nextOpen <- 0;
		}
		// Get the priorities.
		list<int> preferrable <- ys where (each >= nextOpen);
		list<int> suboptimal <- ys where (not (each in preferrable));
		// Make the final list!
		list<ChessBoard> potential <- (preferrable + suboptimal) accumulate (ChessBoard[id, each]);
		return potential;
	}
	
	action utilIsMovePossible(int x1, int y1, list<ChessBoard> queens) type: bool {
		loop queen over: queens {
			bool killedHere <- utilsWillQueenBeKilled(x1, y1, queen);
			if (killedHere) {
				//write("" + candidate + " is incomp with " + queen);
				return false;
			}
		}
		return true;
	}
	
	// https://stackoverflow.com/questions/41432956/checking-for-horizontal-vertical-and-diagonal-pairs-given-coordinates
	action utilsWillQueenBeKilled(int x1, int y1, ChessBoard queen) type: bool {
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