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

#import "NavCurrentLocationManager.h"
#import "NavUtil.h"
#import "NavLocalizerFactory.h"
#import "NavEdgeLocalizer.h"
#import "NavLocalizeResult.h"

#define clipAngle(angle) [NavUtil clipAngle:(angle)]
#define clipAngle2(angle) [NavUtil clipAngle2:(angle)]
#define MIN_KNNDIST_THRESHOLD 1.0

@interface NavCurrentLocationManager ()

@property (atomic, readonly) NavLocation *currentLocation;
@property (atomic, readonly) NavEdge* currentEdge;
@property (atomic, readonly) NavNode* currentNode;
@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CMMotionManager *motionManager;

@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) Boolean logReplay;

@property (nonatomic) float curOri;
@property (nonatomic) float gyroDrift;

@property BOOL locationSearching;

@end

@implementation NavCurrentLocationManager;

static const float GyroDriftMultiplier = 1000;
static const float GyroDriftLimit = 3;


- (instancetype)initWithTopoMap:(TopoMap*)topoMap withUUID: (NSString*) uuidStr
{
    self = [super init];
    if (self) {
        [self reset];
        
        _topoMap = topoMap;
        
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 0.1;
        _motionManager.accelerometerUpdateInterval = 0.01;
        
        // set up beacon manager
        _beaconManager = [[CLLocationManager alloc] init];
        if([_beaconManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [_beaconManager requestAlwaysAuthorization];
        }
        _beaconManager.delegate = self;
        _beaconManager.pausesLocationUpdatesAutomatically = NO;
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
        _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"navcog"];

        //[self startMotionSensor];
        //[self startAccSensor];
        //[self startBeaconSensor];
        
        
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
        [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EDT"]];
        
    }
    return self;
}

- (void) reset
{
    _locationSearching = NO;
    _currentLocation = nil;
    _currentEdge = nil;
    _currentNode = nil;
    _currentOrientation = 0;
}

- (void) startBeaconSensor
{
    [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
}

- (void) startMotionSensor
{
    [_motionManager stopDeviceMotionUpdates];
    _gyroDrift = 0;
    [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *dm, NSError *error){
        NSMutableDictionary* motionData = [[NSMutableDictionary alloc] init];
        
        [motionData setObject: [[NSNumber alloc] initWithDouble: dm.timestamp] forKey:@"timestamp"];
        [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.pitch] forKey:@"pitch"];
        [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.roll] forKey:@"roll"];
        [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.yaw] forKey:@"yaw"];
        
        [self triggerMotionWithData:motionData];
    }];
}

- (void) startAccSensor
{
    [_motionManager stopAccelerometerUpdates];
    [_motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *acc, NSError *error) {
        NSMutableDictionary* accData = [@{} mutableCopy];
        
        accData[@"timestamp"] = @(acc.timestamp);
        accData[@"x"] = @(acc.acceleration.x);
        accData[@"y"] = @(acc.acceleration.y);
        accData[@"z"] = @(acc.acceleration.z);
        
        [self triggerAccelerationWithData: accData];
    }];
}


- (void)stopAllSensors
{
    [self stopBeaconSensor];
    [self stopAccSensor];
    [self stopMotionSensor];
}

- (void)stopMotionSensor
{
    [_motionManager stopDeviceMotionUpdates];
}

- (void) stopAccSensor
{
    [_motionManager stopAccelerometerUpdates];
}

- (void)stopBeaconSensor
{
    [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
}

- (void) setCurrentState: (NavState*) currentState
{
//    _currentState = currentState;
    /*
    if (_currentState.type == STATE_TYPE_WALKING) {
        _currentEdge = currentState.walkingEdge;
    } else {
        _currentEdge = currentState.targetEdge;
    }
    _currentNode = currentState.targetNode;
    _currentLocalizer = _currentEdge.localization;
     */
}

- (void) setNavState:(enum NavigationState)navState
{
//    _navState = navState;
}

// callback for beacon manager when beacons have been found
// if no location has been set yet, this will search the entire
// map for the most probable location. After that it will only
// search the current edge, except if near an edge end node. If
// near a node, then it will try all connecting edges.
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    [self receivedBeaconsArray:beacons];
}

- (void) receivedBeaconsArray:(NSArray *) beacons
{
    [NavLog logBeacons:beacons];
    for(NavLocalizer *localizer in [NavLocalizerFactory allCoreLocalizers]) {
        [localizer inputBeacons:beacons];
    }

    // trigger locationUpdate
    [self setLocationUpdated:@(YES)];
//    [[NSNotificationCenter defaultCenter]
//     postNotificationName:@LOCATION_UPDATED_NOTIFICATION_NAME
//     object:self userInfo:nil];
    

    NavLocation *location = [[NavLocation alloc] initWithMap:_topoMap];
    if (_currentLocation == nil) {
        NSLog(@"No Current Location, searching.");
        // Need an initial location, so search entire map.
        location = [self getCurrentLocationWithInit:!_locationSearching];
        _locationSearching = YES;
    } else {
        if (_currentNode != nil) {
            // We are on a Node, so need to find all connecting
            // edges and localize on one of them.
            NSArray *neighborEdges = [_currentNode getConnectingEdges];
            location = [self getLocationInEdges:neighborEdges withKNNThreshold:MIN_KNNDIST_THRESHOLD withInit:NO];
            
            NSLog(@"On node %@, searching neighbor %lu edges.", _currentNode.nodeID, (unsigned long)[neighborEdges count]);
        } else {
            // If not on a node, just localize within the edge we
            // are on.
            NavLocation *pos = [self getLocationOnEdge:_currentEdge.edgeID];
            
            location.layerID = _currentEdge.parentLayer.zIndex;
            location.edgeID = _currentEdge.edgeID;
            location.xInEdge = pos.xInEdge;
            location.yInEdge = pos.yInEdge;
            NSLog(@"On edge %@, found current position (%f, %f).", _currentEdge.edgeID, pos.xInEdge, pos.yInEdge);
        }
    }
    [self updateCurrentLocation:location];
    
    
    // trigger debugCurrentLocation
    if (_currentLocation) {
        [self setDebugCurrentLocation:_currentLocation];
    }
//    [[NSNotificationCenter defaultCenter]
//     postNotificationName:@CURRENT_LOCATION_NOTIFICATION_NAME
//     object:self
//     userInfo:@{@"location": location}
//     ];
}

- (void)updateCurrentLocation:(NavLocation *)location {
    if (location == _currentLocation) {
        return;
    }
    if (location.edgeID != nil) {
        _currentLocation = location;
        _currentEdge = [_topoMap getEdgeFromLayer:_currentLocation.layerID withEdgeID:_currentLocation.edgeID];
        _currentNode = [_currentEdge checkValidEndNodeAtLocation:_currentLocation];
        if (_currentNode != nil) {
            _currentEdge = nil;
        }
    }

//  redundant. TODO: to be removed
//    [[NSNotificationCenter defaultCenter]
//     postNotificationName:@CURRENT_LOCATION_NOTIFICATION_NAME
//     object:self
//     userInfo:@{@"location": location}
//     ];
}

- (void)initLocalizationOnEdge:(NSString *)edgeID withOptions:(NSDictionary *)options
{
    NavEdgeLocalizer *nel = [NavLocalizerFactory localizerForEdge:edgeID];
    
    [nel initializeState:options];
}

- (NavLocation *)getCurrentLocationWithInit: (BOOL) init {
    if (init) {
        for(NavLocalizer* nl in [NavLocalizerFactory allCoreLocalizers]) {
            [nl initializeState:@{@"allreset":@(true)}];
        }
    }
    
    NavLocation *r = [self getLocation:[NavLocalizerFactory allEdgeLocalizers] withKNNThreshold:1.0 withInit:NO];
    NSLog(@"current location(init=%d) %f %f %f ", init, r.xInEdge, r.yInEdge, r.knndist);
    return r;
}

- (NavLocation *)getLocationOnEdge:(NSString*) edgeID
{
    NavEdgeLocalizer *nel = [NavLocalizerFactory localizerForEdge:edgeID];
    
    NavLocation *location = [[NavLocation alloc] initWithMap:_topoMap];
    NavEdge *edge = [_topoMap getEdgeById:edgeID];
    NavLocalizeResult *pos = [nel getLocation];
    
    location.layerID = edge.parentLayer.zIndex;
    location.edgeID = edge.edgeID;
    location.xInEdge = pos.x;
    location.yInEdge = pos.y;
    location.knndist = pos.knndist;
    
    return location;
}

- (NavLocation *)getLocationInEdges:(NSArray *)edges withKNNThreshold:(float)minKnnDist withInit:(BOOL) init{
    
    NSMutableArray *ids = [@[] mutableCopy];
    for(NavEdge *edge in edges) {
        [ids addObject:edge.edgeID];
    }
    
    return [self getLocation:[NavLocalizerFactory localizersForEdges:ids] withKNNThreshold:minKnnDist withInit:init];
}

- (NavLocation *)getLocation:(NSArray *)localizers withKNNThreshold:(float)minKnnDist withInit:(BOOL) init
{
    NavLocation *location = [[NavLocation alloc] initWithMap:_topoMap];
    float lastKnnDist = 0;
    for (NavEdgeLocalizer *nel in localizers) {
        
        NavEdge *edge = [_topoMap getEdgeById:nel.edgeInfo.edgeID];
        if (edge == nil) {
            continue;
        }
        if (init) {
            [nel initializeState:nil];
        }
        NavLocalizeResult *pos = [nel getLocation];

        float dist = (pos.knndist - edge.minKnnDist) / (edge.maxKnnDist - edge.minKnnDist);
        // Log search information for edge
        NSMutableArray *data = [[NSMutableArray alloc] init];
        [data addObject:[NSNumber numberWithFloat:dist]];
        [data addObject:edge.parentLayer.zIndex];
        [data addObject:edge.edgeID];
        [data addObject:[NSNumber numberWithFloat:pos.x]];
        [data addObject:[NSNumber numberWithFloat:pos.y]];
        [data addObject:[NSNumber numberWithFloat:pos.knndist]];
        // if distance is less than threshold, set new location
        if (dist < minKnnDist) {
            minKnnDist = dist;
            lastKnnDist = pos.knndist;
            location.layerID = edge.parentLayer.zIndex;
            location.edgeID = edge.edgeID;
            location.xInEdge = pos.x;
            location.yInEdge = pos.y;
            location.knndist = pos.knndist;
            [data addObject:@"OK"];
        }
        [NavLog logArray:data withType:@"SearchingCurrentLocation"];
    } // end for
    // Log info if location found
    if (location.edgeID == NULL) {
        location.edgeID = nil;
        NSLog(@"NoCurrentLocation");
    } else {
        NSMutableArray *data = [[NSMutableArray alloc] init];
        [data addObject:[NSNumber numberWithFloat:minKnnDist]];
        [data addObject:location.layerID];
        [data addObject:location.edgeID];
        [data addObject:[NSNumber numberWithFloat:location.xInEdge]];
        [data addObject:[NSNumber numberWithFloat:location.yInEdge]];
        [data addObject:[NSNumber numberWithFloat:lastKnnDist]];
        [NavLog logArray:data withType:@"FoundCurrentLocation"];
    }
    [self setDebugCurrentLocation2: location];
    return location;
}


- (void)triggerAccelerationWithData: (NSMutableDictionary*) data {
    [NavLog logAcc:data];
    if ([_currentMachine getCurrentState]) {
        NSString *edgeID = [[[_currentMachine getCurrentState] walkingEdge] edgeID];
        NavEdgeLocalizer *nel = [NavLocalizerFactory localizerForEdge:edgeID];
        [nel inputAcceleration:data];
    }
}

- (void)triggerMotionWithData: (NSMutableDictionary*) data {
    [NavLog logMotion:data];
    
    if ([_currentMachine getCurrentState]) {
        NSString *edgeID = [[[_currentMachine getCurrentState] walkingEdge] edgeID];
                NavEdgeLocalizer *nel = [NavLocalizerFactory localizerForEdge:edgeID];
        [nel inputMotion:data];
    }
    
    NSNumber* yaw = [data objectForKey:@"yaw"];    
    _curOri = - [yaw doubleValue] / M_PI * 180;
    
    NavState* _currentState = [_currentMachine getWalkingState];
    if (_currentState) {
        double edgeori;
        if (_currentState.startNode == _currentState.walkingEdge.node1)
            edgeori = _currentState.walkingEdge.ori1;
        else
            edgeori = _currentState.walkingEdge.ori2;
        
        //model that gracefully adapts to drift.
        _gyroDrift += clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(edgeori))/GyroDriftMultiplier;
        //limit drift correction to some degrees each update. very naive
        //_gyroDrift += limitAngle(clipAngle2(_curOri - _gyroDrift - clipAngle2(edgeori)));
        //simple model that completely offsets drift
        //_gyroDrift = clipAngle2(_curOri - clipAngle2(edgeori));
        [NavLog logGyroDrift:_gyroDrift edge:clipAngle2(edgeori) curori:_curOri fixedDelta: clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(edgeori)) oldDelta: clipAngle2(_curOri - clipAngle2(edgeori))];
    }

    // trigger orientationUpdated
    _currentOrientation = [NavUtil clipAngle2:_curOri - _gyroDrift];
    [self setOrientationUpdated:@(YES)];
//    [[NSNotificationCenter defaultCenter]
//     postNotificationName:@CURRENT_ORIENTATION_NOTIFICATION_NAME
//     object:self userInfo:nil];

}

- (void) setCurrentOrientation:(float) orientation
{
    _currentOrientation = orientation;
}


//TODO: try to get pedometer updates and only update gyro drift on steps

- (NSString *)getTimeStamp {
    return [_dateFormatter stringFromDate:[NSDate date]];
}


- (void)simulateSensorFromLogFile:(NavLogFile*) logFile
{
    _gyroDrift = 0;
    double timeMultiplier = 1;
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    if ([env valueForKey:@"simspeed"]) {
        timeMultiplier = 1.0/[[env valueForKey:@"simspeed"] doubleValue];
    }

    
    NSArray *timesArray = logFile.timesArray;
    NSArray *objectsArray = logFile.objectsArray;
    NSDate *startTime = logFile.startTime;
    
    _logReplay = true;
    
    //if started kill motionmanager
    [self stopAllSensors];
    
    dispatch_queue_t queue = dispatch_queue_create("com.navcog.logsimulatorqueue", NULL);
    
    unsigned long int arraySize = [timesArray count];
    
    dispatch_async(queue, ^{
        
        NSDate* time = startTime;
        
        for (int i=0; i < arraySize; i++) {
            if (!_logReplay) {
                return;
            }

            if ([objectsArray[i] isKindOfClass: [NSArray class]]) {
                //create
                NSTimeInterval waitTime = [timesArray[i] timeIntervalSinceDate:time];
                
                NSArray* beacons = objectsArray[i];
                
                //call beacons
                [NSThread sleepForTimeInterval:waitTime*timeMultiplier];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    [self receivedBeaconsArray: beacons];
                });
                
                time = timesArray[i];
                
            } else if ([objectsArray[i] isKindOfClass: [NSMutableDictionary class]]) {
                
                NSTimeInterval waitTime = [timesArray[i] timeIntervalSinceDate:time];
                
                NSMutableDictionary* data = objectsArray[i];
                
                if ([data[@"type"] isEqualToString:@"acceleration"]) {
                    [NSThread sleepForTimeInterval:waitTime*timeMultiplier];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self triggerAccelerationWithData:data];
                    });
                } else if ([data[@"type"] isEqualToString:@"motion"]) {
                    [NSThread sleepForTimeInterval:waitTime*timeMultiplier];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self triggerMotionWithData:data];
                    });
                    
                }
                //call motion
                
                time = timesArray[i];
                
            }
            
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [_currentMachine stopNavigation];
            [_currentMachine.delegate navigationFinished];
        });
        
    });
    
}

- (void) setCurrentLocation:(NavLocation*) currentLocation
{
    _currentLocation = currentLocation;
}

- (void) setLocationUpdated:(NSValue *)locationUpdated
{
    _locationUpdated = locationUpdated;
}

- (void)setOrientationUpdated:(NSValue *)orientationUpdated
{
    _orientationUpdated = orientationUpdated;
}


- (void) setDebugCurrentLocation:(NavLocation *)debugCurrentLocation
{
    _debugCurrentLocation = debugCurrentLocation;
}

- (void) setDebugCurrentLocation2:(NavLocation *)debugCurrentLocation2
{
    _debugCurrentLocation2 = debugCurrentLocation2;
}


- (void) stopSimulation
{
    _logReplay = false;
}


/*
 
 //TODO: this even used?
 - (void)triggerNextState {
 if (!(_logReplay)) {
 [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
 }
 _currentState = _currentState.nextState;
 if (_currentState != nil) {
 if (!(_logReplay)) {
 [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
 }
 } else {
 [_delegate navigationFinished];
 [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
 [_topoMap cleanTmpNodeAndEdges];
 }
 }
 */


@end;