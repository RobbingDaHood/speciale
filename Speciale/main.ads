
#include "stdafx.h"
#include "FCNode.h"
#include <cassert>
#include <stack>

FCNode::~FCNode(){
	delete leftChild;
	delete rightChild;
	//delete highestX;
	//delete lowestX;
	//delete highestY;
	//delete lowestY;

	/*for(int i = 0; i < pointsSortedByY.size(); i++) {
		delete pointsSortedByY[i];
	}*/
}

FCNode::FCNode() {
	leftChild = 0;
	rightChild = 0;
	highestX = 0;
	lowestX = 0;
}

FCNode* FCNode::getLeftChild(){
	return leftChild;
}

FCNode* FCNode::getRightChild(){
	return rightChild;
}

Point* FCNode::getHighestX(){
	return highestX;
}

Point* FCNode::getLowestX(){
	return lowestX;
}

vector<int> FCNode::getDominatingPrefixSum(){
	return dominatingPrefixSum;
}

Point* FCNode::getHighestY(){
	return highestY;
}

Point* FCNode::getLowestY(){
	return lowestY;
}

vector<Point*> FCNode::getPointsSortedByY() {
	return pointsSortedByY;
}

//Lower left and topRight is only used for their X coordinates
//And as long as their Y-cordinates are not to narrow, then they do not matter.
int FCNode::skylineCountQuery(Point* lowerLeft, Point* topRight, int indexOfLowestY, int indexOfHighestY) {
	if(indexOfLowestY > indexOfHighestY)
		return 0;

	if(leftChild != 0 && rightChild != 0) {
		if(indexOfHighestY > indexOfLowestY) {
			//Find indexOfLowestMemberOfSkyline
			int indexOfLowestMemberOfSkyline;
			int indexDiffOnHighLowY = indexOfHighestY - indexOfLowestY;

			int indexDiffOnHighLowYLog = binaryLog(indexDiffOnHighLowY);

			int highIndex = rmqStructureForward[indexOfHighestY - pow((double)2, indexDiffOnHighLowYLog) + 1][indexDiffOnHighLowYLog];
			if(indexDiffOnHighLowYLog == 0)
				highIndex = rmqStructureForward[indexOfHighestY][indexDiffOnHighLowYLog];
			int lowIndex = rmqStructureForward[indexOfLowestY][indexDiffOnHighLowYLog];

			if(pointsSortedByY[highIndex]->x < pointsSortedByY[lowIndex]->x)
				indexOfLowestMemberOfSkyline = lowIndex;
			else
				indexOfLowestMemberOfSkyline = highIndex;

			return dominatingPrefixSum[indexOfHighestY] - dominatingPrefixSum[indexOfLowestMemberOfSkyline] + 1;
		} else { // if (indexOfHighestY == indexOfLowestY)
			return 1; //there is only one node in the range
		}
	} else {  //leaf case
		//the isPointInRange do check both x and y coordinates, but only the x coodinate matter

		if(indexOfLowestY < indexOfHighestY) {
			//only lowestX is in range
			if(isPointInRange(lowestX, lowerLeft, topRight) && !isPointInRange(highestX, lowerLeft, topRight)) {
				return 1;
			}
			//only HighestX is in range
			else if(isPointInRange(highestX, lowerLeft, topRight) && !isPointInRange(lowestX, lowerLeft, topRight)) {
				return 1;
			}
			//they are both in range
			else if(isPointInRange(highestX, lowerLeft, topRight) && isPointInRange(lowestX, lowerLeft, topRight)) {
				if(isDominating(highestX, lowestX))
					return 1;
				else
					return 2;
			} else {
				return 0;
			}
		}
		else { //if(indexOfLowestY == indexOfHighestY)
			//only lowestX is in range
			if(indexOfLowestY == 0) {
				if(isPointInRange(lowestY, lowerLeft, topRight))
					return 1;
				else
					return 0;
			}
			else {
				if(isPointInRange(highestY, lowerLeft, topRight))
					return 1;
				else
					return 0;
			}
		}
	}
}

//Requeries a sorted set of points on x-axis
void FCNode::generateStructure(vector<Point*> points){

	lowestX = points[0];
	highestX = points[points.size() - 1];

	//Generate tree
	if(points.size() > 2) {
		//Slitting into right and left childs points
		std::size_t const half_size = ceil((double) points.size() / (double) 2);
		vector<Point*> leftChildsPoints(points.begin(), points.begin() + half_size);
		vector<Point*> rightChildPoints(points.begin() + half_size, points.end());

		leftChild = new FCNode();
		rightChild = new FCNode();

		leftChild->generateStructure(leftChildsPoints);
		rightChild->generateStructure(rightChildPoints);

		//merge pointSortedByY
		pointsSortedByY = vector<Point*>(points.size());
		int rightCount = 0;
		int leftCount = 0;
		for(int i = 0; i < pointsSortedByY.size(); i++) {
			if(leftCount >= leftChild->pointsSortedByY.size() || (rightCount < rightChild->pointsSortedByY.size() && sortByYAxis(rightChild->pointsSortedByY[rightCount], leftChild->pointsSortedByY[leftCount]))) {
				pointsSortedByY[i] = rightChild->pointsSortedByY[rightCount];
				rightCount++;
			} else {
				pointsSortedByY[i] = leftChild->pointsSortedByY[leftCount];
				leftCount++;
			}
		}

		generateDominatingPrefixSum();

		leftChild->generateFractionalCascading(pointsSortedByY);
		rightChild->generateFractionalCascading(pointsSortedByY);

		leftChild->generateRMQ(leftChildsPoints);
		rightChild->generateRMQ(rightChildPoints);

	} else {
		//Generate internal structure
		sort(points.begin(), points.end(), sortByYAxis);
		pointsSortedByY = points;
	}


	lowestY = pointsSortedByY[0];
	highestY = pointsSortedByY[pointsSortedByY.size() - 1];
}

void FCNode::generateFractionalCascading(vector<Point*> parentPointsSortedByY) {
	//generate Frational cascading
	fcPredesessorY = vector<int>(parentPointsSortedByY.size());
	fcSucessorY = vector<int>(parentPointsSortedByY.size());
	fcPredesessorYWithEqual = vector<int>(parentPointsSortedByY.size());
	fcSucessorYWithEqual = vector<int>(parentPointsSortedByY.size());
	indexMappingToParent = vector<int>(pointsSortedByY.size());
	indexMappingYtoX = vector<int>(pointsSortedByY.size());

	int indexOfCurrentMin = 0;
	int indexOfCurrentMax = pointsSortedByY.size() - 1;
	int indexOfCurrentMinWithEqual = 0;
	int indexOfCurrentMaxWithEqual = pointsSortedByY.size() - 1;
	int indexOfMapping = 0;
	for(int i = 0; i < parentPointsSortedByY.size(); i++) {

		//fcSucessorY
		if(indexOfCurrentMin == -1) { //this is the endcase
			fcSucessorY[i] = indexOfCurrentMin;
		}
		else if(pointsSortedByY[indexOfCurrentMin]->y > parentPointsSortedByY[i]->y)
			fcSucessorY[i] = indexOfCurrentMin;
		else {
			while(!(pointsSortedByY[indexOfCurrentMin]->y > parentPointsSortedByY[i]->y)) {
				if(indexOfCurrentMin < pointsSortedByY.size() - 1)
					indexOfCurrentMin++;
				else {
					indexOfCurrentMin = -1;
					break;
				}
			}
			fcSucessorY[i] = indexOfCurrentMin;
		}

		//fcSucessorYWithEqual
		if(indexOfCurrentMinWithEqual == -1) { //this is the endcase
			fcSucessorYWithEqual[i] = indexOfCurrentMinWithEqual;
		}
		else if(pointsSortedByY[indexOfCurrentMinWithEqual]->y >= parentPointsSortedByY[i]->y)
			fcSucessorYWithEqual[i] = indexOfCurrentMinWithEqual;
		else {
			while(!(pointsSortedByY[indexOfCurrentMinWithEqual]->y >= parentPointsSortedByY[i]->y)) {
				if(indexOfCurrentMinWithEqual < pointsSortedByY.size() - 1)
					indexOfCurrentMinWithEqual++;
				else {
					indexOfCurrentMinWithEqual = -1;
					break;
				}
			}
			fcSucessorYWithEqual[i] = indexOfCurrentMinWithEqual;
		}

		//fcPredesessorY
		if(indexOfCurrentMax == -1) { //this is the endcase
			fcPredesessorY[parentPointsSortedByY.size() - 1 - i] = indexOfCurrentMax;
		}
		else if(pointsSortedByY[indexOfCurrentMax]->y < parentPointsSortedByY[parentPointsSortedByY.size() - 1 - i]->y)
			fcPredesessorY[parentPointsSortedByY.size() - 1 - i]  = indexOfCurrentMax;
		else {
			while(!(pointsSortedByY[indexOfCurrentMax]->y < parentPointsSortedByY[parentPointsSortedByY.size() - 1 - i]->y)) {
				if(indexOfCurrentMax > 0)
					indexOfCurrentMax--;
				else {
					indexOfCurrentMax = -1;
					break;
				}
			}
			fcPredesessorY[parentPointsSortedByY.size() - 1 - i]  = indexOfCurrentMax;
		}

		//fcPredesessorYWithEqual
		if(indexOfCurrentMaxWithEqual == -1) { //this is the endcase
			fcPredesessorYWithEqual[parentPointsSortedByY.size() - 1 - i] = indexOfCurrentMaxWithEqual;
		}
		else if(pointsSortedByY[indexOfCurrentMaxWithEqual]->y <= parentPointsSortedByY[parentPointsSortedByY.size() - 1 - i]->y)
			fcPredesessorYWithEqual[parentPointsSortedByY.size() - 1 - i]  = indexOfCurrentMaxWithEqual;
		else {
			while(!(pointsSortedByY[indexOfCurrentMaxWithEqual]->y <= parentPointsSortedByY[parentPointsSortedByY.size() - 1 - i]->y)) {
				if(indexOfCurrentMaxWithEqual > 0)
					indexOfCurrentMaxWithEqual--;
				else {
					indexOfCurrentMaxWithEqual = -1;
					break;
				}
			}
			fcPredesessorYWithEqual[parentPointsSortedByY.size() - 1 - i]  = indexOfCurrentMaxWithEqual;
		}

		//indexMappingToParent
		if(indexOfMapping < pointsSortedByY.size() &&
			parentPointsSortedByY[i]->x == pointsSortedByY[indexOfMapping]->x &&
			parentPointsSortedByY[i]->y == pointsSortedByY[indexOfMapping]->y ) {

			for(int k = 0; k + i < parentPointsSortedByY.size(); k++) {
				indexMappingToParent[indexOfMapping] = i + k;

				if(i + k + 1 < parentPointsSortedByY.size() && parentPointsSortedByY[i + k + 1]->y != pointsSortedByY[indexOfMapping]->y )
					break;
			}

			indexOfMapping++;
		}
	}
}

//At this point the points are sorted by y
void FCNode::generateRMQ(vector<Point*> points) {
		//Som math helpers
		int logOfN = ceil(binaryLog(pointsSortedByY.size()));

		rmqStructureForward = vector<vector<int>>(pointsSortedByY.size());
		for(int i = 0; i < pointsSortedByY.size(); i++) {
			rmqStructureForward[i] = vector<int>(logOfN + 1, -1);
		}

		for(int i = 0; i < pointsSortedByY.size(); i++) {
			rmqStructureForward[i][0] = i;
		}
		for(int k = 1; k <= logOfN; k++) {
			for(int i = 0; i < pointsSortedByY.size(); i++) {
				int indexLeft = rmqStructureForward[i][k-1];
				int indexRight;
				int stepSizeRight = i+ pow((double)2, k-1);
				if(stepSizeRight > pointsSortedByY.size() - 1) {
					indexRight = rmqStructureForward[pointsSortedByY.size() - 1][k-1];
				} else
					indexRight = rmqStructureForward[stepSizeRight][k-1];

				if(pointsSortedByY[indexLeft]->x > pointsSortedByY[indexRight]->x)
					rmqStructureForward[i][k] = indexLeft;
				else
					rmqStructureForward[i][k] = indexRight;
			}
		}
}

//At this point the points are sorted by y
void FCNode::generateDominatingPrefixSum() {
	dominatingPrefixSum.resize(pointsSortedByY.size());
	stack<Point*> nonDomintedPoints;

	for(int i = 0; i < pointsSortedByY.size(); i++) {
		while(	nonDomintedPoints.size() > 0 &&
				nonDomintedPoints.top()->x <= pointsSortedByY[i]->x) {
			nonDomintedPoints.pop();
		}
		nonDomintedPoints.push(pointsSortedByY[i]);
		dominatingPrefixSum[i] = nonDomintedPoints.size();
	}
}

//Returns the path from root to the Node that contains the predesessor
//There is 2 values in the a node and one of them will be the predessesor
void FCNode::predesessorSearch(int xValue, vector<FCNode*>* path) {
	path->push_back(this);

	//It handles cases with same x-value

	if(leftChild != 0 && rightChild != 0) {
		if(leftChild->getHighestX() != 0 && leftChild->getHighestX()->x > xValue) {
			leftChild->predesessorSearch(xValue, path);
		}
		else if(rightChild->getLowestX()->x < xValue) {
			rightChild->predesessorSearch(xValue, path);
		}
		else { //If rightChild->getLowestX()->x == xValue || leftChild->getHighestX()->x == xValue => go to left child
			leftChild->predesessorSearch(xValue, path);
		}
	}
}

void FCNode::successorSearch(int xValue, vector<FCNode*>* path) {
	path->push_back(this);

	//It handles cases with same x-value

	if(leftChild != 0 && rightChild != 0) {
		if(leftChild->getHighestX() != 0 && leftChild->getHighestX()->x > xValue) {
			leftChild->successorSearch(xValue, path);
		}
		else if(rightChild->getHighestX() != 0 && rightChild->getLowestX()->x < xValue) {
			rightChild->successorSearch(xValue, path);
		}
		else { //If rightChild->getLowestX()->x == xValue || leftChild->getHighestX()->x == xValue => go to right child
			rightChild->successorSearch(xValue, path);
		}
	}
}

double FCNode::binaryLog(int x) {
	return log((double) x) / log(2.0);
}

int FCNode::getSuccIndex(int parentIndex) {
	return fcSucessorY[parentIndex];
}
int FCNode::getPredIndex(int parentIndex) {
	return fcPredesessorY[parentIndex];
}

int FCNode::getSuccIndexWithEqual(int parentIndex) {
	return fcSucessorYWithEqual[parentIndex];
}
int FCNode::getPredIndexWithEqual(int parentIndex) {
	return fcPredesessorYWithEqual[parentIndex];
}

//The problem is that i dont know if the y's are the same.
int FCNode::getSuccIndexIfNotEqual(int parentIndex, int y) {
	if(fcSucessorYWithEqual[parentIndex] == -1 || pointsSortedByY[fcSucessorYWithEqual[parentIndex]]->y == y)
		return fcSucessorY[parentIndex];

	return fcSucessorYWithEqual[parentIndex];
}
int FCNode::getPredIndexIfNotEqual(int parentIndex, int y) {
	if(fcPredesessorYWithEqual[parentIndex] == -1 || pointsSortedByY[fcPredesessorYWithEqual[parentIndex]]->y == y)
		return fcPredesessorY[parentIndex];

	return fcPredesessorYWithEqual[parentIndex];
}

int FCNode::getParentIndex(int childIndex) {
	return indexMappingToParent[childIndex];
}

int FCNode::sizeOfStructure() {
	int result = 0;

	if(pointsSortedByY.size() > 2) {
		result += leftChild->sizeOfStructure();
		result += rightChild->sizeOfStructure();
	}

	result += sizeof(highestX);
	result += sizeof(lowestX);
	result += sizeof(highestY);
	result += sizeof(lowestY);

	result += pointsSortedByY.size() * sizeof(Point);
	result += dominatingPrefixSum.size() * sizeof(int);
	result += rmqStructureForward.size() * sizeof(int);
	result += fcPredesessorY.size() * sizeof(int);
	result += fcSucessorY.size() * sizeof(int);
	result += fcPredesessorYWithEqual.size() * sizeof(int);
	result += fcSucessorYWithEqual.size() * sizeof(int);
	result += indexMappingToParent.size() * sizeof(int);
	result += indexMappingYtoX.size() * sizeof(int);

	return result;
}
