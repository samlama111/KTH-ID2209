/**
* Name: Exercise3NQueens
* Based on the internal empty template. 
* Author: ph
* Tags: 
*/


model Exercise3NQueens

/* Insert your model definition here */
// communication:
//
// checking locations:
//   propose: position [<location>] <sender>
//   --> pass it down the chain
//   --> recursively go down the chain
//   --> accept/reject
//
// enumerate all possible locations
// if stuck, change active and move that
//   

global {
	
	int numberOfQueens <- 4 min: 4 max: 20;

	init {
		int index <- 0;
		create Queen number: numberOfQueens;
		
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
		Queen[numberOfQueens - 1].active <- true;
	}
}


species Queen skills: [fipa] {
	ChessBoard myCell; 
	int id; 
	int index <- 0;
	bool active <- false;
	list<list<int>> knownToBeBad <- [];
	Queen pred;
	Queen succ;
	   
//	reflex updateCell {
//		write('id' + id);
//		write('X: ' + myCell.grid_x + ' - Y: ' + myCell.grid_y);
//		myCell <- ChessBoard[myCell.grid_x,  mod(index, numberOfQueens)];
//		location <- myCell.location;
//		index <- index + 1;
//	}

	reflex writeBack when: index = 0 {
		write("ID: " + id);
		if (pred != nil) {
			write("  Predecessor: " + pred.id);
		}
		if (succ != nil) {
			write("  Successor: " + succ.id);
		}
	}

	reflex negativePositions {
		
	}

	reflex queryNearbyPositions {
		
	}
	
	action init1(int queenId, Queen predecessor) type: Queen {
		id <- queenId;
		myCell <- ChessBoard[id, id];
		pred <- predecessor;
		return self;
	}
	
	action init2(Queen successor) type: Queen {
		succ <- successor;	
		return self;
	}
	
	aspect base {
		float size <- 30 / numberOfQueens;
		if (active) {
			draw circle(size) color: #magenta;
		} else {
			draw circle(size) color: #pink;
		}
		location <- myCell.location ;
	}
}
	
	
grid ChessBoard width: numberOfQueens height: numberOfQueens { 
	init{
		if(even(grid_x) and even(grid_y) or !even(grid_x) and !even(grid_y)){
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