/**
* Name: Exercise3NQueens
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise3NQueens


global {
	
	int numberOfQueens <- 14 min: 4 max: 20;

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
	list<ChessBoard> memory <- [];
	
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
		add pos to: memory;
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
		list<ChessBoard> locations <- [];
		// Go through every possible cell on its own row.
		// We only let them go on its own row to allow backtracking.
		// This should prefer a staircase pattern.
		loop y from: 1 to: numberOfQueens {
			ChessBoard cell <- ChessBoard[id, y - 1];
			// If we've already been here, we skip.
			if (memory contains cell) {
				continue;
			}
			// If this conflicts with other queens (only last one).
			if (not utilIsMovePossible(cell, others)) {
				continue;
			}
			add cell to: locations;
		}
		return locations;
	}
	
//	action utilGetPossibleLocations type: list<ChessBoard> {
//		list<ChessBoard> potential <- [];
//		// We divide into cases.
//		// This is to optimize.
//		// 1) First and last queen -- these ones can go ANYWHERE on the board.
//		// 2) All the other queens -- these ones can only take 2-1 (knight move) or 3-1 (???) positions from existing queens.
//		if (pred = nil or succ = nil) {
//			// Go through every possible cell on the board.
//			loop i from: 1 to: numberOfQueens {
//				loop j from: 1 to: numberOfQueens {
//					ChessBoard cell <- ChessBoard[i - 1, j - 1];
//					// If we've already been here, we skip.
//					if (memory contains cell) {
//						continue;
//					}
//					// If this conflicts with other queens (only last one).
//					if (succ = nil and not utilIsMovePossible(cell, others)) {
//						continue;
//					}
//					add cell to: potential;
//				}
//			}
//		} else {
//			// For every queen, add the location that are a knight away.
//			loop other over: others {
//				do utilAddHopLocationsForQueen(2, potential, other, others);
//				do utilAddHopLocationsForQueen(3, potential, other, others);
//			}
//		}
//		return potential;
//	}
	
	// https://www.geeksforgeeks.org/possible-moves-knight/
	action utilAddHopLocationsForQueen(int n, list<ChessBoard> potential, ChessBoard queen, list<ChessBoard> queens) {
		list<int> dX <- [n, 1, -1, -n, -n, -1, 1, n];
		list<int> dY <- [1, n, n, 1, -1, -n, -n, -1];
		loop i from: 1 to: 8 {
			int x <- queen.grid_x + (dX at (i - 1));
			// Is the x coordinate in range?
			if (x < 0 or x >= numberOfQueens) {
				continue;
			}
			// Is the y coordinate in range, and has this move not been taken?
			int y <- queen.grid_y + (dY at (i - 1));
			if (y < 0 or y >= numberOfQueens) {
				continue;
			}
			ChessBoard cell <- ChessBoard[x, y];
			// Is there a queen and/or is this move going to get us killed?
			if (not utilIsMovePossible(cell, queens)) {
				continue;
			}
			// If we've visited here before.
			if (memory contains cell) {
				continue;
			}
			// Yeah, this is fine.
			add cell to: potential;
		}
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