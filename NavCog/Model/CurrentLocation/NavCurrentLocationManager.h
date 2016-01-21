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
 *  Cole Gleason (CMU) - initial API and implementation
 *  Dragan Ahmetovic (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#ifndef NavCurrentLocationManager_h
#define NavCurrentLocationManager_h

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "KDTreeLocalization.h"
#import "NavMachine.h"
#import "NavState.h"
#import "TopoMap.h"
#import "NavLogFile.h"
#import "NavigationState.h"

#define CURRENT_LOCATION_NOTIFICATION_NAME "CurrentLocationNotification"
#define CURRENT_ORIENTATION_NOTIFICATION_NAME "CurrentOrientationNotification"
#define LOCATION_UPDATED_NOTIFICATION_NAME "LocationUpdatedNotification"

@class TopoMap;
@class NavMachine;
@class NavState;
@class NavLocation;
@class NavLocalizer;

// This will be used for exploration. It will first find an edge
// you are in, then create a localization KDTree on that edge.
// It will provide notification updates, and other services may
// subscribe to those.
// How do we handle transitions to other edges?
@interface NavCurrentLocationManager : NSObject <CLLocationManagerDelegate>

@property (nonatomic) TopoMap *topoMap;
@property (nonatomic) NavMachine* currentMachine;
@property (atomic, readonly) NSValue *locationUpdated;
@property (atomic, readonly) NSValue *orientationUpdated;
@property (atomic, readonly) NavLocation *debugCurrentLocation;
@property (atomic, readonly) NavLocation *debugCurrentLocation2;
@property (atomic, readonly) NavLocalizer *currentLocalizer;
@property (atomic, readonly) float currentOrientation;


- (instancetype)initWithTopoMap:(TopoMap*)topoMap withUUID: (NSString*) uuidStr;
- (void)simulateSensorFromLogFile:(NavLogFile*) logFile;

- (void) startMotionSensor;
- (void) startAccSensor;
- (void) startBeaconSensor;
- (void) stopAllSensors;
- (void) stopSimulation;
- (void) stopMotionSensor;
- (void) stopAccSensor;
- (void) stopBeaconSensor;
- (void) reset;

- (void) initLocalizaion;
- (void) initLocalizationOnEdge:(NSString*) edgeID withOptions:(NSDictionary*) options;
- (NavLocation *)getCurrentLocationWithInit:(BOOL) init;
- (NavLocation *)getLocationOnEdge:(NSString*) edgeID;
- (NavLocation *)getLocationInEdges:(NSArray *)edges withKNNThreshold:(float)knnThreshold withInit:(BOOL) init;
- (NSString*) getLocalizerNameForEdge:(NSString*)edgeID;

@end;

#endif /* NavCurrentLocationManager_h */
