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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "NavNeighbor.h"
#import "NavSoundEffects.h"
#import "NavLocation.h"
#import "NavCurrentLocationManager.h"

@class NavLocation;
@class NavEdge;
@class NavNode;
@class NavCurrentLocationManager;

enum StateType {STATE_TYPE_WALKING, STATE_TYPE_TRANSITION};

@interface NavState : NSObject

@property (nonatomic) enum StateType type;
@property (strong, nonatomic) NavEdge *walkingEdge; // if it's a walking state, it should be assigned a edge
@property (strong, nonatomic) NavNode *startNode; // the start point of this state
@property (strong, nonatomic) NavNode *targetNode; // the destination node of this state
@property (strong, nonatomic) NavEdge *targetEdge; // used when it's a transition
                                                   // use the edge to check if the transition is finished or not
@property (strong, nonatomic) NavState *nextState; // next state
@property (strong, nonatomic) NavState *prevState; //  previous state

@property (strong, nonatomic) NSString *stateStartInfo; // announce this information when the state start
@property (strong, nonatomic) NSString *approachingInfo; // announce this when approching
@property (strong, nonatomic) NSString *arrivedInfo; // announce this when arrived
@property (strong, nonatomic) NSString *nextActionInfo; // annouce this if user clicked the button when walking, used with distances (e.g. 40 feet to turn right)
@property (strong, nonatomic) NSString *previousInstruction;
@property (strong, nonatomic) NSString *surroundInfo;
@property (strong, nonatomic) NSString *trickyInfo;
@property (nonatomic) Boolean isTricky;
@property (nonatomic) float closestDist;

@property (nonatomic) float ori; // expected orientation when walking in this state
@property (nonatomic) float sx; // x of start node
@property (nonatomic) float sy; // y of start node
@property (nonatomic) float tx; // x of target node
@property (nonatomic) float ty; // y of target node
@property (nonatomic) float floor;
@property (nonatomic) BOOL isFirst;


- (Boolean)checkStateStatusUsingLocationManager:(NavCurrentLocationManager *)man withSpeechOn:(Boolean)isSpeechEnabled withClickOn:(Boolean)isClickEnabled;
- (void)stopAudios;
- (void)repeatPreviousInstruction;
- (void)announceSurroundInfo;
- (void)announceAccessibilityInfo;
- (NSString*)getPreviousInstruction;
- (NSString*)getSurroundInfo;
- (NSString*)getAccessibilityInfo;


- (BOOL)isMeter;
- (int)toMeter:(int) feet;
- (float)getStartDistance:(NavLocation*) pos;
- (float)getTargetDistance:(NavLocation*) pos;
- (float)getStartRatio:(NavLocation*) pos;
- (float)getTargetRatio:(NavLocation*) pos;


@end
