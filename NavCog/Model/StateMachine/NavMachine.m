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

#import "NavMachine.h"
#import "NavNotificationSpeaker.h"
#import "NavCogFuncViewController.h"
#import "NavLog.h"
#import "NavUtil.h"

#define clipAngle(angle) [NavUtil clipAngle:(angle)]
#define clipAngle2(angle) [NavUtil clipAngle2:(angle)]


@interface NavMachine ()

@property (strong, nonatomic) NavCurrentLocationManager *currentLocationManager;
@property (strong, nonatomic) NavState *initialState;
@property (strong, nonatomic) NavState *currentState;
@property (strong, nonatomic) NavLocation *currentLocation;
@property (strong, nonatomic) NavLocation *previousLocation;
@property (nonatomic) enum NavigationState navState;
@property (nonatomic) Boolean speechEnabled;
@property (nonatomic) Boolean clickEnabled;
@property (nonatomic) Boolean isStartFromCurrentLocation;
@property (nonatomic) Boolean isNavigationStarted;
@property (strong, nonatomic) NSString *destNodeName;
@property (strong, atomic) NSArray *pathNodes;
@property (strong, nonatomic) TopoMap *topoMap;
@property (strong, nonatomic) NSString *lastPre, *lastAccess, *lastSurround;

@property (nonatomic) float curOri;

@end

@implementation NavMachine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _initialState = nil;
        _currentState = nil;
        _currentLocation = nil;
        _previousLocation = nil;
        _navState = NAV_STATE_IDLE;
        [self setupCurrentLocationObserver];
    }
    return self;
}

- (instancetype) initWithTopoMap:(TopoMap*) topoMap withUUID:(NSString *)uuidStr
{
    
    self = [super init];
    if (self) {
        _initialState = nil;
        _currentState = nil;
        _currentLocation = nil;
        _previousLocation = nil;
        _navState = NAV_STATE_IDLE;
        
        _currentLocationManager = [[NavCurrentLocationManager alloc] initWithTopoMap:topoMap withUUID:uuidStr];
        _currentLocationManager.currentMachine = self;
        [self setupCurrentLocationObserver];
    }
    return self;
}


// initialize the state machine with a new path of nodes
- (void)initializeWithPathNodes:(NSArray *)pathNodes {
    _initialState = nil;
    _currentState = nil;
    _navState = NAV_STATE_IDLE;
    for (int i = (int)[pathNodes count] - 1; i >= 1; i--) {
        NavNode *node1 = [pathNodes objectAtIndex:i];
        NavNode *node2 = [pathNodes objectAtIndex:i-1];
        NSMutableString *startInfo = [[NSMutableString alloc] init];

        NavState *newState = [[NavState alloc] init];
        newState.startNode = node1;
        newState.targetNode = node2;

        // if node2 is node1's transit node, then is should be a transition.
        if ([node1 transitEnabledToNode:node2]) {
            newState.type = STATE_TYPE_TRANSITION;
            newState.surroundInfo = [node1 getTransitInfoToNode:node2];
            // targetEdge is used to check if we arrive at next edge or not
            // in our project, we presume that there's no Destination node with transition
            // so we depend on node3's preEdgeInPath to get node2' position
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                newState.targetEdge = node3.preEdgeInPath;
                newState.tx = [node2 getXInEdgeWithID:node3.preEdgeInPath.edgeID];
                newState.ty = [node2 getYInEdgeWithID:node3.preEdgeInPath.edgeID];
                newState.sx = [node3 getXInEdgeWithID:node3.preEdgeInPath.edgeID];// fix for snap min/max
                newState.sy = [node3 getYInEdgeWithID:node3.preEdgeInPath.edgeID];// fix for snap min/max
                newState.floor = node2.floor;
            }
            [startInfo appendString:[node1 getInfoComingFromEdgeWithID:node1.preEdgeInPath.edgeID]];
            switch (node1.type) {
                case NODE_TYPE_DOOR_TRANSIT:
                    break;
                case NODE_TYPE_STAIR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeStairsFormat", @"Format string for taking the stairs"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                case NODE_TYPE_ELEVATOR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeElevatorFormat", @"Format string for taking the elevator"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                default:
                    break;
            }
        } else {
            newState.type = STATE_TYPE_WALKING;
            newState.walkingEdge = node2.preEdgeInPath;
            newState.surroundInfo = [node2.preEdgeInPath getInfoFromNode:node1];
            newState.isTricky = [node2 isTrickyComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.trickyInfo = newState.isTricky ? [node2 getTrickyInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID] : nil;
            newState.distMsg = [self getDistMessage:newState withLen:node2.preEdgeInPath.len withName:node2.name];
            float curOri = [node2.preEdgeInPath getOriFromNode:node1];
            newState.ori = curOri;
            newState.sx = [node1 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.sy = [node1 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.tx = [node2 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.ty = [node2 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.floor = node1.floor;
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                [startInfo appendString:NSLocalizedString(@"and", "Simple and used to join two nodes.")];
                if ([node2 transitEnabledToNode:node3]) { // next state is a transition
                    switch (node2.type) {
                        case NODE_TYPE_DOOR_TRANSIT:
                            // for door transition node, we use node information
                            newState.nextActionInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                            [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                            break;
                        case NODE_TYPE_STAIR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo = NSLocalizedString(@"goUpstairs", @"Short command telling the user to go upstairs");
                                [startInfo appendString:NSLocalizedString(@"goUpstairsStairCase", @"Command telling the user to go up the stairs using the stair case")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairs", @"Short command telling the user to go downstairs");
                                [startInfo appendString:NSLocalizedString(@"goDownstairsStairCase", @"Command telling the user to go down the stairs using the stair case")];
                            }
                            break;
                        case NODE_TYPE_ELEVATOR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo =NSLocalizedString(@"goUpstairsElevator", @"Command telling the user to go upstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeUpstairsElevator", @"Command telling the user take the elevator upstairs")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairsElevator", @"Command telling the user to go downstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeDownstairsElevator", @"Command telling the user take the elevator downstairs")];
                            }
                            break;
                        default:
                            break;
                    }
                } else { // if next state is normal walking state, then pre-tell the turn
                    float nextOri = [node3.preEdgeInPath getOriFromNode:node2];
                    [startInfo appendString:[self getTurnStringFromOri:curOri toOri:nextOri]];
                    if (![node2 hasTransition] && node2.type != NODE_TYPE_DESTINATION) {
                        newState.arrivedInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                    }
                    newState.nextActionInfo = [self getTurnStringFromOri:curOri toOri:nextOri];
                    if (curOri != nextOri) {
                        newState.approachingInfo = [NSString stringWithFormat:NSLocalizedString(@"approachingToTurnFormat", @"Format string to tell the user they are approaching a turn"), [self getTurnStringFromOri:curOri toOri:nextOri]];
                    }
                }
            } else {
                newState.nextActionInfo = [NSString stringWithFormat:NSLocalizedString(@"destinationFormat", @"Format string for destination alert"), [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                newState.arrivedInfo = [node2 getDestInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                [startInfo appendString:NSLocalizedString(@"destination", @"Destination alert")];
            }
            newState.plusMsg = startInfo; [startInfo setString:@""];
            [startInfo appendString:newState.surroundInfo];
        }

        if (![node1.buildingName isEqualToString:node2.buildingName]) {
            [startInfo appendString:[NSString stringWithFormat:NSLocalizedString(@"enteringFormat", @"Spoken when entering a location"), node2.buildingName]];
        }

        newState.infoMsg = startInfo;
        newState.stateStartInfo = [NSString stringWithFormat:@"%@%@%@", newState.distMsg, newState.plusMsg, newState.infoMsg];
        if (i == (int)[pathNodes count] - 1) {
            _initialState = newState;
            newState.isFirst = YES;
        } else {
            _currentState.nextState = newState;
            newState.prevState = _currentState;
        }
        _currentState = newState;
    }
    [self combineEdges:_initialState];

    _currentState = _initialState;
    // check if we need a initial turning

    if (_initialState.type == STATE_TYPE_WALKING) {
        float diff = clipAngle2(clipAngle2(_curOri) - clipAngle2(_initialState.ori));
        
        if (ABS(diff) > 15) { //have to rotate
            _currentState.previousInstruction = [self getTurnStringFromOri:clipAngle(_curOri) toOri:_currentState.ori];
            [NavNotificationSpeaker speakWithCustomizedSpeed:_currentState.previousInstruction];
            _navState = NAV_STATE_TURNING;
        } else { //straight
            _navState = NAV_STATE_WALKING;
        }
    }
    [self setHintTexts];

    NavState *state = _initialState;
    while (state != nil) {
        NSLog(@"*****************************************************************");
        NSLog(@"************                                          ***********");
        NSLog(@"*****************************************************************");
        NSLog(@"start info : %@", state.stateStartInfo);
        NSLog(@"approaching info : %@", state.approachingInfo);
        NSLog(@"arrived info : %@", state.arrivedInfo);
        NSLog(@"surounding info : %@", state.surroundInfo);
        NSLog(@"accessibility info : %@", state.trickyInfo);
        state = state.nextState;
    }
}

- (NSString *)getFloorString:(int)floor {
    NSString *ordinalNumber;

    // TODO(cgleason): find way to remove special case for floor numbering in Japanese
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    if([@"ja" compare:language] == NSOrderedSame) {
        ordinalNumber = [NSString stringWithFormat:@"%d", floor];
    } else {
        TTTOrdinalNumberFormatter*ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
        [ordinalNumberFormatter setLocale:[NSLocale currentLocale]];
        [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
        NSNumber *number = [NSNumber numberWithInteger:floor];
        ordinalNumber = [ordinalNumberFormatter stringFromNumber:number];
    }
    return [NSString stringWithFormat:NSLocalizedString(@"floorFormat", @"Format string for a floor that takes an ordinal number"), ordinalNumber];
}

- (NSString *)getTurnStringFromOri:(float)curOri toOri:(float)nextOri {
    curOri = clipAngle2(curOri);
    nextOri = clipAngle2(nextOri);
    
    float diff = clipAngle2(curOri - nextOri);
    
    NSString *slightLeft = NSLocalizedString(@"slightLeft", @"Instruction to turn slightly left");
    NSString *slightRight = NSLocalizedString(@"slightRight", @"Instruction to turn slightly right");
    NSString *turnLeft = NSLocalizedString(@"turnLeft", @"Instruction to turn left");
    NSString *turnRight = NSLocalizedString(@"turnRight", @"Instruction to turn right");
    NSString *keepStraight = NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    
    if (diff > 0) { //definitely right
        if (diff > 45) {
            return turnLeft;
        } else if (diff > 15) {
            return slightLeft;
        }
    } else { //definitely left
        if (diff < -45) {
            return turnRight;
        } else if (diff < -15) {
            return slightRight;
        }
    }
    
    return keepStraight;
}

- (NSString *)getTurnStringWithDegreeFromOri:(float)curOri toOri:(float)nextOri {
    if (curOri == nextOri || clipAngle2(curOri - nextOri) == -180) {
        return NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    }
    
    int diff = clipAngle(curOri - nextOri);
    NSString *leftFormat = NSLocalizedString(@"turnLeftDegreeFormat", @"Format string to turn left in degrees");
    NSString *rightFormat = NSLocalizedString(@"turnRightDegreeFormat", @"Format string to turn right in degrees");
    if (diff < 180) {
        return nextOri < curOri ? [NSString stringWithFormat:leftFormat, diff] : [NSString stringWithFormat:rightFormat, diff ];
    } else {
        return nextOri < curOri ? [NSString stringWithFormat:rightFormat, diff ] : [NSString stringWithFormat:leftFormat, diff] ;
    }
    
    return @"";
}

- (void)initializeOrientation {
    [self.currentLocationManager startMotionSensor];
}

- (void)setupCurrentLocationObserver
{
    [_currentLocationManager addObserver:self forKeyPath:@"locationUpdated" options:NSKeyValueObservingOptionNew context:nil];
    [_currentLocationManager addObserver:self forKeyPath:@"orientationUpdated" options:NSKeyValueObservingOptionNew context:nil];
    
//    [[NSNotificationCenter defaultCenter]
//     addObserver:self
//     selector:@selector(locationUpdated)
//     name:@LOCATION_UPDATED_NOTIFICATION_NAME
//     object:nil];
//    
//    [[NSNotificationCenter defaultCenter]
//     addObserver:self
//     selector:@selector(orientationUpdated)
//     name:@CURRENT_ORIENTATION_NOTIFICATION_NAME
//     object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"locationUpdated"]){
        [self locationUpdated];
    }
    if ([keyPath isEqualToString:@"orientationUpdated"]) {
        [self orientationUpdated];
    }
}


- (void)startNavigationOnTopoMap:(TopoMap *)topoMap fromNodeWithName:(NSString *)fromNodeName toNodeWithName:(NSString *)toNodeName usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled {
    [NavLog startLog];
    [NavLog logArray:@[fromNodeName,toNodeName] withType:@"Route"];

    // set speech rate of notification speaker
    [NavNotificationSpeaker setFastSpeechOnAndOff:fastSpeechEnabled];

    // set UI type (speech and click sound)
    _speechEnabled = speechEnabled;
    _clickEnabled = clickEnabled;


    //_currentLocationManager = [[NavCurrentLocationManager alloc] initWithTopoMap:topoMap withUUID:uuidstr];
    //_currentLocationManager.currentMachine = self;
    [_currentLocationManager startAccSensor];
    [_currentLocationManager startBeaconSensor];


    // search a path
    _topoMap = topoMap;
    _pathNodes = nil;
    _navState = NAV_STATE_INIT;
    if (![fromNodeName isEqualToString:NSLocalizedString(@"currentLocation", @"Current Location")]) {
        _pathNodes = [_topoMap findShortestPathFromNodeWithName:fromNodeName toNodeWithName:toNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isStartFromCurrentLocation = false;
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
    } else {
        _destNodeName = toNodeName;
        _isStartFromCurrentLocation = true;
        _isNavigationStarted = false;
    }
    
}


- (void) orientationUpdated
{
    _curOri = _currentLocationManager.currentOrientation;
    
    if (_navState == NAV_STATE_TURNING) {
        //if (ABS(_curOri - _currentState.ori) <= 10) {
        float diff = clipAngle2(clipAngle2(_curOri) - clipAngle2(_currentState.ori));
        if (ABS(diff) <= 10) {
            [NavSoundEffects playSuccessSound];
            _navState = NAV_STATE_WALKING;
            [self logState];
        }
    }

}

- (void)simulateNavigationOnTopoMap:(TopoMap *)topoMap usingLogFile:(NavLogFile *)logFile withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled
{
    //_currentLocationManager = [[NavCurrentLocationManager alloc] initWithTopoMap:topoMap withUUID:logFile.uuidStr];
    //_currentLocationManager.currentMachine = self;
    
    //logging
    [NavLog startLog];
    [NavLog logArray:@[logFile.fromNodeName,logFile.toNodeName] withType:@"Route"];
    // set speech rate of notification speaker
    [NavNotificationSpeaker setFastSpeechOnAndOff:fastSpeechEnabled];
    
    // set UI type (speech and click sound)
    _speechEnabled = speechEnabled;
    _clickEnabled = clickEnabled;
    
    // search a path
    _topoMap = topoMap;
    _pathNodes = nil;
    _navState = NAV_STATE_INIT;
    
    [_currentLocationManager simulateSensorFromLogFile:logFile];
    
    // wait a short period for motion sensor data (initial _curOri should be updated from log)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![logFile.fromNodeName isEqualToString:NSLocalizedString(@"currentLocation", @"Current Location")]) {
            _pathNodes = [_topoMap findShortestPathFromNodeWithName:logFile.fromNodeName toNodeWithName:logFile.toNodeName];
            [self initializeWithPathNodes:_pathNodes];
            _isStartFromCurrentLocation = false;
            _isNavigationStarted = true;
            [_delegate navigationReadyToGo];
        } else {
            _destNodeName = logFile.toNodeName;
            _isStartFromCurrentLocation = true;
            _isNavigationStarted = false;
        }
    });
}

- (void)stopNavigation {
    [self stopAudio];
    [_currentLocationManager stopBeaconSensor];
    [_currentLocationManager stopAccSensor];
    [_currentLocationManager reset];
    [_currentLocationManager stopSimulation];
    [_topoMap cleanTmpNodeAndEdges];
    _navState = NAV_STATE_IDLE;
    _initialState = nil;
    _currentState = nil;
}

- (void)repeatInstruction {
    if (_currentState != nil) {
        [_currentState repeatPreviousInstruction];
    }
}

- (void)announceSurroundInfo {
    if (_currentState != nil) {
        [_currentState announceSurroundInfo];
    }
}

- (void)announceAccessibilityInfo {
    if (_currentState != nil && _currentState.isTricky) {
        [_currentState announceAccessibilityInfo];
    }
}


- (void) locationUpdated
{
    _previousLocation = _currentLocation;
    //_currentLocation = _currentLocationManager.currentLocation;
    _currentLocation = [_currentLocationManager getCurrentLocationWithInit:NO];

    // if we start navigation from current location
    // and the navigation does not start yet
    if (_isStartFromCurrentLocation && !_isNavigationStarted) {
        //_previousLocation = _currentLocation;
        // if navigation has not started yet, then init all edge localization
        // otherwise ignore

        if (_currentLocation.edgeID == nil)
            return;

        _pathNodes = [_topoMap findShortestPathFromCurrentLocation:_currentLocation toNodeWithName:_destNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
        NSLog(@"***********************************************");
        NSLog(@"layer : %@", _currentLocation.layerID);
        NSLog(@"edge : %@", _currentLocation.edgeID);
        NSLog(@"x : %f", _currentLocation.xInEdge);
        NSLog(@"y : %f", _currentLocation.yInEdge);
    } else {
        [self logState];

        if ([NavLog isLogging] == YES) {
            [_currentLocationManager getCurrentLocationWithInit:NO];
            //[_topoMap getCurrentLocationOnMapUsingBeacons:beacons withInit:NO];
        }
        if (_navState == NAV_STATE_TURNING && _currentState != _initialState) {
            // check if user keep moving to destination without turn
            NavLocation *pos = [_currentLocationManager getLocationOnEdge:_currentState.walkingEdge.edgeID];
            
            NavEdge *edge = _currentState.walkingEdge;
            
            double dist = (pos.knndist - edge.minKnnDist) / (edge.maxKnnDist - edge.minKnnDist);
            
            float startDist = [_currentState getStartDistance:pos];
            float startRatio = [_currentState getStartRatio:pos];
            if (dist <= 1 && (startDist > 20 || (startDist > 10 && startRatio > 0.25))) {
                NSLog(@"ForceTurn,%f,%f",startDist, startRatio);
                [NavSoundEffects playSuccessSound];
                _navState = NAV_STATE_WALKING;
            }
        }
        if (_navState == NAV_STATE_WALKING) {
            
            if ([_currentState checkStateStatusUsingLocationManager:_currentLocationManager withSpeechOn:_speechEnabled withClickOn:_clickEnabled]) {
                
                _currentState = _currentState.nextState;
                if (_currentState == nil) {
                    [_delegate navigationFinished];
                    [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
                    //[_currentLocationManager stopAllSensors];
                    [_currentLocationManager stopBeaconSensor];
                    [_currentLocationManager stopAccSensor];
                    [_currentLocationManager reset];
                    [_topoMap cleanTmpNodeAndEdges];
                } else if (_currentState.type == STATE_TYPE_WALKING) {
                    // Attempt to do gyro drift updates only while moving. however the localization is not reliable enough to use it
                    //                    if(_previousLocation != nil) {
                    //                        if(_currentLocation.edgeID == _previousLocation.edgeID) {
                    //                            //calculate delta, TODO: only validate delta in forward direction
                    //                            double deltax = _currentLocation.xInEdge-_previousLocation.xInEdge;
                    //                            double deltay = _currentLocation.yInEdge-_previousLocation.yInEdge;
                    //                            double delta = sqrt(deltax*deltax+deltay*deltay);
                    //                            if (delta > _gyroDriftThreshold) {
                    //                                //update drift, called only in WALKING state, else check it
                    //                                double edgeori;
                    //                                if (_currentState.startNode == _currentState.walkingEdge.node1)
                    //                                    edgeori = _currentState.walkingEdge.ori1;
                    //                                else
                    //                                    edgeori = _currentState.walkingEdge.ori2;
                    //
                    //                                _gyroDrift = (_gyroDrift + (_curOri - edgeori))/2;
                    //                                [NavLog logGyroDrift:_gyroDrift edge: edgeori curori: _curOri];
                    //                            }
                    //                        }
                    //                    }
                    
                    
                    //                        if (ABS(_curOri - _currentState.ori) > 15) {
                    float diff = clipAngle2(clipAngle2(_curOri) - clipAngle2(_currentState.ori));
                    if (_currentState.isCombined) {
                        diff = 0; // Do not wait for turn on combined edges
                    }
                    if (ABS(diff) > 15) {
                        _currentState.previousInstruction = [self getTurnStringFromOri:clipAngle(_curOri) toOri:_currentState.ori];
                        [NavNotificationSpeaker speakWithCustomizedSpeed:_currentState.previousInstruction];
                        _navState = NAV_STATE_TURNING;
                    } else {
                        _navState = NAV_STATE_WALKING;
                    }
                } else if (_currentState.type == STATE_TYPE_TRANSITION) {
                    _navState = NAV_STATE_WALKING;
                }
            } else if (_currentState.type == STATE_TYPE_TRANSITION) {
                _navState = NAV_STATE_WALKING;
            }
            [self logState];
        }
    }
    [self setHintTexts];
}

- (void)setHintTexts {
    if (UIAccessibilityIsVoiceOverRunning()) {
        NSString *pre = [_currentState getPreviousInstruction], *surround = [_currentState getSurroundInfo], *access = [_currentState getAccessibilityInfo];
        if (![pre isEqualToString:_lastPre]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastPre = pre withTag:BUTTON_PRE];
        }
        if (![surround isEqualToString:_lastSurround]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastSurround = surround withTag:BUTTON_SURROUND];
        }
        if (![access isEqualToString:_lastAccess]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastAccess = access withTag:BUTTON_ACCESS];
        }
    }
}

- (NSArray *)getPathNodes {
    return _pathNodes;
}

- (void)stopAudio {
    if (_currentState != nil) {
        [_currentState stopAudios];
    }
}


- (void)logState {
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [data addObject:[NSNumber numberWithFloat:_curOri]];
    if(_currentState != nil) {
        [data addObject:[NSNumber numberWithFloat:_currentState.ori]];
        [data addObject:[NSNumber numberWithFloat:_currentState.sx]];
        [data addObject:[NSNumber numberWithFloat:_currentState.sy]];
        [data addObject:[NSNumber numberWithFloat:_currentState.tx]];
        [data addObject:[NSNumber numberWithFloat:_currentState.ty]];
        [data addObject:[NSNumber numberWithFloat:_currentState.floor]];
        switch (_currentState.type) {
            case STATE_TYPE_WALKING:
                [data addObject:@"STATE_TYPE_WALKING"];
                break;
            case STATE_TYPE_TRANSITION:
                [data addObject:@"STATE_TYPE_TRANSITION"];
                break;
        }
    }
    NSString *type = @"Navigation";
    switch (_navState) {
        case NAV_STATE_WALKING:
            type = @"Walking";
            break;
        case NAV_STATE_TURNING:
            type = @"Turning";;
            break;
        case NAV_STATE_INIT:
            type = @"Starting";
            break;
        case NAV_STATE_IDLE:
            type = @"Idle";
            break;
    }
    [NavLog logArray:data withType:type];
}

- (NavState*)getWalkingState {
    if ((_navState == NAV_STATE_WALKING) && (_currentState.type != STATE_TYPE_TRANSITION))
        return _currentState;
    else
        return nil;
}

- (NavState*)getCurrentState {
    return _currentState;
}

- (NavCurrentLocationManager *)getCurrentLocationManager
{
    return _currentLocationManager;
}

// message distance to target
- (NSString*)getDistMessage:(NavState*) state withLen:(int)len withName:(NSString*)name {
    int edgeLen = [state isMeter] ? [state toMeter:len] : len;
    if ([name length] > 0) {
        return [NSString stringWithFormat:NSLocalizedString([state isMeter]?@"meterToNameFormat":@"feetToNameFormat", @"format string describing the number of feet left to a named location"), edgeLen, name];
    } else {
        return [NSString stringWithFormat:NSLocalizedString([state isMeter]?@"meterPauseFormat":@"feetPauseFormat", @"Use to express a distance in feet with a pause"), edgeLen];
    }
}

// Combine straight edges
- (void)combineEdges:(NavState*)begin {
    while (begin != nil) {
        NavState *end = begin;
        int totalLen = begin.walkingEdge.len;
        while (end != nil &&
               end.type == STATE_TYPE_WALKING &&
               end.nextState != nil &&
               end.nextState.type == STATE_TYPE_WALKING) {
//            if (end.targetNode.type == NODE_TYPE_DESTINATION) {
//                break;
//            }
//            if ([end.targetNode.name length] > 0) {
//                break;
//            }
            if (ABS([NavUtil clipAngle2:(end.ori - end.nextState.ori)]) > 15) {
                break;
            }
            totalLen += (end = end.nextState).walkingEdge.len;
        }
        for (NavState *state = begin; end != begin; state = state.nextState) {
            if (state == begin) {
                state.distMsg = [self getDistMessage:state withLen:totalLen withName:end.targetNode.name];
                state.plusMsg = end.plusMsg;
            } else {
                state.isCombined = YES;
                state.distMsg = state.plusMsg = @"";
            }
            NSString * startInfo = [NSString stringWithFormat:@"%@%@%@", state.distMsg, state.plusMsg, state.infoMsg];
            NSLog(@"++++ %@", startInfo);
            NSLog(@"---- %@", state.stateStartInfo);
            state.stateStartInfo = startInfo;
            if (state != end) {
                NSLog(@"---- %@", state.approachingInfo);
                state.approachingInfo = NULL;
            }
            if (state == end) {
                break;
            }
        }
        begin = end.nextState;
    }
    for (NavState *state = _initialState; state != nil; ) {
        state.extraEdgeLength = 0;
        for (NavState *next = state.nextState; next != nil && next.isCombined; next = next.nextState) {
            state.extraEdgeLength += next.walkingEdge.len;
        }
        if (state.extraEdgeLength > 0) {
            state.walkingEdge = state.walkingEdge; // re-init
        }
        state = state.nextState;
    }
}
@end
