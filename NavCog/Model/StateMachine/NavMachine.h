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
 *  Dragan Ahmetovic (CMU) - initial API and implementation
 *  Cole Gleason (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import "NavState.h"
#import "TopoMap.h"
#import "TTTOrdinalNumberFormatter.h"
#import "NavCurrentLocationManager.h"
#import "NavLogFile.h"


@class TopoMap;
@class NavState;

@protocol NavMachineDelegate;

@interface NavMachine : NSObject

- (instancetype) initWithTopoMap:(TopoMap*) topoMap withUUID:(NSString *)uuidStr;

- (void)startNavigationOnTopoMap:(TopoMap *)topoMap fromNodeWithName:(NSString *)fromNodeName toNodeWithName:(NSString *)toNodeName usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled;
- (void)simulateNavigationOnTopoMap:(TopoMap *)topoMap usingLogFile:(NavLogFile *)logFile withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled;
- (void)initializeOrientation;
- (void)stopNavigation;
- (void)repeatInstruction;
- (void)announceSurroundInfo;
- (void)announceAccessibilityInfo;
- (NSArray *)getPathNodes;
- (NavState*)getWalkingState;
- (NavState*)getTransitionState;
- (NavCurrentLocationManager*) getCurrentLocationManager;

@property (strong, nonatomic) id <NavMachineDelegate> delegate;

@end


@protocol NavMachineDelegate <NSObject>

- (void)navigationFinished;
- (void)navigationReadyToGo;

@end