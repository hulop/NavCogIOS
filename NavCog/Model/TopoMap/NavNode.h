/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Contributors:
 *  Chengxiong Ruan (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#ifndef HELLO_NAV_NODE
#define HEELO_NAV_NODE HI_NAV_NODE
#import <Foundation/Foundation.h>
#import "NavNeighbor.h"

@class NavEdge;
@class NavLayer;

enum NodeType {NODE_TYPE_NORMAL, NODE_TYPE_DOOR_TRANSIT, NODE_TYPE_STAIR_TRANSIT, NODE_TYPE_ELEVATOR_TRANSIT, NODE_TYPE_DESTINATION};

@interface NavNode : NSObject

@property (nonatomic) enum NodeType type;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *nodeID;
@property (nonatomic) float transitKnnDistThres; // knn distance threhold to check transition
@property (nonatomic) float transitPosThres; // localization distance threshold to check transition
@property (strong, nonatomic) NSMutableDictionary *infoFromEdges;
@property (strong, nonatomic) NSDictionary *transitInfo;
@property (nonatomic) NSString *layerZIndex;
@property (nonatomic) NSString *buildingName;
@property (nonatomic) int floor;
@property (nonatomic) double lat;
@property (nonatomic) double lng;
@property (weak, nonatomic) NavLayer *parentLayer;

@property (strong, nonatomic) NSMutableArray *neighbors; // used for Dijsktra's Algorithm
@property (weak, nonatomic) NavNode *preNodeInPath; // used for Dijsktra's Algorithm for tracing back shortest path
@property (weak, nonatomic) NavEdge *preEdgeInPath; // used to easy state machine generation
@property (nonatomic) int distFromStartNode; // used for Dijsktra's Algorithm for searching shortest path
@property (nonatomic) int indexInHeap; // used for heap management in Dijsktra's Algorithm

@property (nonatomic) NSString *language;

- (Boolean)transitEnabledToNode:(NavNode *)node;
- (Boolean)hasTransition;
- (NSString *)getTransitInfoToNode:(NavNode *)node;
- (NSString *)getInfoComingFromEdgeWithID:(NSString *)edgeID;
- (NSString *)getDestInfoComingFromEdgeWithID:(NSString *)edgeID;
- (double)getXInEdgeWithID:(NSString *)edgeID;
- (double)getYInEdgeWithID:(NSString *)edgeID;
- (Boolean)isTrickyComingFromEdgeWithID:(NSString *)edgeID;
- (NSString *)getTrickyInfoComingFromEdgeWithID:(NSString *)edgeID;
- (NSArray *)getConnectingEdges;

@end

#endif
