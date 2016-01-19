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
 
#ifndef HELLO_NAV_EDGE
#define HEELO_NAV_EDGE HI_NAV_EDGE

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "NavNode.h"
#import "NavLayer.h"
#import "NavLocation.h"
#import "NavLocalizer.h"
#import "KDTreeLocalization.h"


@class NavNode;
@class NavLayer;
@class NavLocation;
@class NavLocalizer;

enum EdgeType {EDGE_NORMAL, EDGE_NON_NAVIGATIONAL};

@interface NavEdge : NSObject

@property (nonatomic) enum EdgeType type;
@property (nonatomic) NSString *edgeID;
@property (nonatomic) int len;
@property (nonatomic) float ori1; // edge orientation when coming from node 1
@property (nonatomic) float ori2; // edge orientation when coming from node 2
@property (nonatomic) float minKnnDist;
@property (nonatomic) float maxKnnDist;
@property (strong, nonatomic) NavNode *node1;
@property (strong, nonatomic) NavNode *node2;
@property (strong, nonatomic) NSString *nodeID1; // node id of node 1
@property (strong, nonatomic) NSString *nodeID2; // node id of node 2
@property (strong, nonatomic) NSString *info1; // information needed when coming from node 1
@property (strong, nonatomic) NSString *info2; // information needed when coming from node 2
@property (weak, nonatomic) NavLayer *parentLayer;

@property (nonatomic) NSString *language;


// moved to CurrentLocationManager
//@property (strong, nonatomic) NavLocalizer *localization;
//- (void)initLocalizationWithOptions:(NSDictionary*)options;
//- (void)setLocalizationWithInstance:(NavLocalizer *)localization;
//- (NavPoint)getCurrentPositionInEdgeUsingBeacons:(NSArray *)beacons;
//- (NavPoint)currentPositionFromBeacons:(NSArray *)beacons withOptions:(NSDictionary*) options;

- (float)getOriFromNode:(NavNode *)node;
- (NSString *)getInfoFromNode:(NavNode *)node;
- (NavNode *)checkValidEndNodeAtLocation:(NavLocation *)location;
- (NavEdge *)clone;

//- (void) inputAcceleration: (NSDictionary*) data;
//- (void) inputMotion: (NSDictionary*) data;


@end


#endif