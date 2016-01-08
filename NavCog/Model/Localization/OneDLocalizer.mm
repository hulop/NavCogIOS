//
//  OneDLocalizer.m
//  NavCog
//
//  Created by Daisuke Sato on 12/17/15.
//  Copyright © 2015 HULOP. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

#import "P2PManager.h"

#import "OneDLocalizer.h"
#import "NavUtil.h"
#import "NavEdge.h"
#import "NavNode.h"
#import "NavLocalizeResult.h"
#import "NavLineSegment.h"
#import "TopoMap.h"

#import <bleloc/StreamLocalizer.hpp>
#import <bleloc/StreamParticleFilter.hpp>

#import <bleloc/PoseRandomWalker.hpp>

#import <bleloc/GridResampler.hpp>
#import <bleloc/StatusInitializerStub.hpp>
#import <bleloc/StatusInitializerImpl.hpp>

#import <bleloc/DataStore.hpp>
#import <bleloc/DataStoreImpl.hpp>

#import <bleloc/OrientationMeterAverage.hpp>
#import <bleloc/PedometerWalkingState.hpp>

#import <bleloc/GaussianProcessLDPLMultiModel.hpp>

// for pose random walker in building
#import <bleloc/Building.hpp>
#import <bleloc/PoseRandomWalkerInBuilding.hpp>

#import <bleloc/StrongestBeaconFilter.hpp>

using namespace loc;

typedef struct LocalizerData {
    OneDLocalizer* localizer;
} LocalizerData;

@interface OneDLocalizer ()
@property NSArray *beaconIDs;
@property std::shared_ptr<OrientationMeter> orientationMeter;
@property std::shared_ptr<DataStoreImpl> dataStore;
@property NSTimer *tryResetTimer;
@property NSDictionary *currentOptions;
@property bool p2pDebug;

@property loc::Pose stdevPose;
@property NSArray *previousBeaconInput;
@property NavLocalizeResult *result;
@property long previousAttTimestamp;
@property long previousAccTimestamp;
@property LocalizerData userData;

@property std::shared_ptr<Location> d1meanLoc;
@property std::shared_ptr<Pose> d1meanPose;
@property std::shared_ptr<States> d1states;

@end

@implementation OneDLocalizer

- (void)dealloc
{
    delete _localizer;
}

- (id) init
{
    self = [super init];
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    self.p2pDebug = false;
    if ([[env valueForKey:@"p2pdebug"] isEqual:@"true"]) {
        self.p2pDebug = true;
    }
    return self;
}

void d1calledWhenUpdated(void *userData, Status * pStatus){
    
    LocalizerData *localizerData = (LocalizerData*)userData;
    OneDLocalizer *loc = localizerData->localizer;
    
    //NSLog(@"location updated");
    loc.d1meanLoc = pStatus->meanLocation();
    loc.d1meanPose = pStatus->meanPose();
    loc.d1states = pStatus->states();
    
    NSDictionary *data = @{
                           @"x": @(loc.d1meanLoc->x()),
                           @"y": @(loc.d1meanLoc->y()),
                           @"z": @(loc.d1meanLoc->z()),
                           @"floor": @(loc.d1meanLoc->floor()),
                           @"orientation": @(loc.d1meanPose->orientation()),
                           @"velocity":@(loc.d1meanPose->velocity())
                           };
    
    //[[P2PManager sharedInstance] send:data withType:@"2d-position" ];
    
    printf("1D %f, %f, %f, %f, %f\n", loc.d1meanLoc->x(), loc.d1meanLoc->y(), loc.d1meanLoc->floor(), loc.d1meanPose->orientation(), loc.d1meanPose->velocity());
    //std::cout << meanLoc->toString() << std::endl;
}

- (void)initializeWithFile:(NSString *)path
{
    NSString *data = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [data componentsSeparatedByString:@"\n"];
    
    NSArray *beacons = [[lines[0] componentsSeparatedByString:@" : "][1] componentsSeparatedByString:@","];
    
    _beaconIDs = [beacons subarrayWithRange:NSMakeRange(0, [beacons count]-1)];
    
    NSLog(@"%@", [_beaconIDs componentsJoinedByString:@","]);
    
    
    
    _localizer = new StreamParticleFilter();
    _userData.localizer = self;
    _localizer->updateHandler(d1calledWhenUpdated, &_userData);
    _localizer->numStates(1000);
    _localizer->alphaWeaken(0.3);
    
    _dataStore = std::shared_ptr<DataStoreImpl>(new DataStoreImpl());
    
    BuildingBuilder buildingBuilder;

//    double ppmx = 2;
//    double ppmy = -2;
//    double ppmz = 1;
//    double originx = 400;
//    double originy = 20;
//    double originz = 0;
    double ppmx = 1;
    double ppmy = -1;
    double ppmz = 1;
    double originx = 400;
    double originy = 400;
    double originz = 0;

    CoordinateSystemParameters coordSysParams(ppmx, ppmy, ppmz, originx, originy, originz);

    //NSString *imgpath = [[NSBundle mainBundle] pathForResource:@"corridor" ofType:@"png"];
    NSString *imgpath = [[NSBundle mainBundle] pathForResource:@"white" ofType:@"png"];
    std::string cppPath = [imgpath UTF8String];
    buildingBuilder.addFloorCoordinateSystemParametersAndImagePath(0, coordSysParams, cppPath);
    _dataStore->building(buildingBuilder.build());
    
    Samples samples;
    
    for(NSString* line: [lines subarrayWithRange:NSMakeRange(1, [lines count]-1)]) {
        NSArray *items = [line componentsSeparatedByString:@","];
        if ([items count] < 3) continue;
        float x = [TopoMap unit2meter:[items[0] floatValue]*3];
        float y = [TopoMap unit2meter:[items[1] floatValue]*3];
        Location location = Location(x, y, 0, 0);
        int n = [items[2] intValue];
        Beacons beacons;
        for(int i = 0; i < n; i++) {
            int major = [items[3+i*3] intValue];
            int minor = [items[4+i*3] intValue];
            float rssi = [items[5+i*3] floatValue];
            Beacon beacon = Beacon(major, minor, rssi);
            beacons.push_back(beacon);
        }
        Sample sample = Sample();
        sample.beacons(beacons)->location(location);
        samples.push_back(sample);
    }
    _dataStore->samples(samples);
    
    // Instantiate sensor data processors
    // Orientation
    OrientationMeterAverageParameters orientationMeterAverageParameters;
    orientationMeterAverageParameters.interval(0.1);
    orientationMeterAverageParameters.windowAveraging(0.1);
    std::shared_ptr<OrientationMeter> orientationMeter(new OrientationMeterAverage(orientationMeterAverageParameters));
    
    self.orientationMeter = orientationMeter;
    
    // Pedometer
    PedometerWalkingStateParameters pedometerWSParams;
    // TODO
    pedometerWSParams.updatePeriod(0.1);
    // END TODO
    std::shared_ptr<Pedometer> pedometer(new PedometerWalkingState(pedometerWSParams));
    
    // Set dependency
    _localizer->orientationMeter(orientationMeter);
    _localizer->pedometer(pedometer);
    
    // Build System Model
    // TODO (PoseProperty and StateProperty)
    PoseProperty poseProperty;
    StateProperty stateProperty;
    poseProperty.meanVelocity(1.0);
    poseProperty.stdVelocity(0.3);
    poseProperty.diffusionVelocity(0.1);
    poseProperty.minVelocity(0.1);
    poseProperty.maxVelocity(1.5);
    poseProperty.stdOrientation(3.0/180.0*M_PI);
    
    //stateProperty.meanRssiBias(-4.0);
    stateProperty.meanRssiBias(0.0);
    stateProperty.stdRssiBias(0.2);
    stateProperty.diffusionRssiBias(0.2);
    stateProperty.diffusionOrientationBias(1.0/180*M_PI);
    // END TODO
    
    // Build poseRandomWalker
    PoseRandomWalkerProperty poseRandomWalkerProperty;
    std::shared_ptr<PoseRandomWalker>poseRandomWalker(new PoseRandomWalker());
    poseRandomWalkerProperty.orientationMeter(orientationMeter.get());
    poseRandomWalkerProperty.pedometer(pedometer.get());
    poseRandomWalkerProperty.angularVelocityLimit(30.0/180.0*M_PI);
    poseRandomWalker->setProperty(poseRandomWalkerProperty);
    poseRandomWalker->setPoseProperty(poseProperty);
    poseRandomWalker->setStateProperty(stateProperty);
    
    // Combine poseRandomWalker and building
    PoseRandomWalkerInBuildingProperty prwBuildingProperty;
    // TODO
    prwBuildingProperty.maxIncidenceAngle(45.0/180.0*M_PI);
    prwBuildingProperty.weightDecayRate(0.9);
    // END TODO
    Building building = _dataStore->getBuilding();
    std::shared_ptr<PoseRandomWalkerInBuilding> poseRandomWalkerInBuilding(new PoseRandomWalkerInBuilding());
    poseRandomWalkerInBuilding->poseRandomWalker(*poseRandomWalker);
    poseRandomWalkerInBuilding->building(building);
    poseRandomWalkerInBuilding->poseRandomWalkerInBuildingProperty(prwBuildingProperty);
    
    _localizer->systemModel(poseRandomWalkerInBuilding);
    
    // set resampler
    std::shared_ptr<Resampler<State>> resampler(new GridResampler<State>());
    _localizer->resampler(resampler);
    
    // Set status initializer
    ////PoseProperty poseProperty;
    ////StateProperty stateProperty;
    
    std::shared_ptr<StatusInitializerImpl> statusInitializer(new StatusInitializerImpl());
    statusInitializer->dataStore(_dataStore)
    .poseProperty(poseProperty).stateProperty(stateProperty);
    _localizer->statusInitializer(statusInitializer);
    
    // Set localizer
    //_localizer->observationModel(deserializedModel);
    
    // Beacon filter
    std::shared_ptr<StrongestBeaconFilter> beaconFilter(new StrongestBeaconFilter());
    beaconFilter->nStrongest(10);
    _localizer->beaconFilter(beaconFilter);
    
    
    // Set standard deviation of Pose
    double stdevX = 0.25;
    double stdevY = 0.25;
    _stdevPose.x(stdevX).y(stdevY);
    

}

- (void)initializeState:(NSDictionary *)options;
{
    self.currentOptions = options;
    if (options == nil) {
        return;
    }
    if (options[@"allreset"]) {
        NSLog(@"1D localizer is all reset");
        self.localizer->resetStatus();
        return;
    }
    if (self.tryResetTimer != nil) {
        [self.tryResetTimer invalidate];
    }
    self.tryResetTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(tryReset:) userInfo:options repeats:YES];
}

- (NavLocalizeResult *)getLocation
{
    // need to convert 2D result into 1D
    return _result;
}


- (void) tryReset:(NSTimer *)timer {
    if (self.orientationMeter->isUpdated()) {
        NSDictionary *options = timer.userInfo;
        
        double x, y, z, floor, orientation;
        
        double n1x = [options[@"sx"] doubleValue];
        double n1y = [options[@"sy"] doubleValue];
        double n2x = [options[@"tx"] doubleValue];
        double n2y = [options[@"ty"] doubleValue];
        
        x = Feet2Meter(n1x);
        y = Feet2Meter(n1y);
        z = Feet2Meter(0);
        floor = [options[@"floor"] doubleValue];
        orientation = atan2(n2y-n1y, n2x-n1x);
        loc::Pose pose;
        pose.x(x).y(y).z(z).floor(floor).orientation(orientation);
        
        std::cout << "Sending reset request to the localizer.";
        std::cout << ", resetPose = " << pose << std::endl;
        self.localizer->resetStatus();
        //        self.localizer->resetStatus(pose);
        self.localizer->resetStatus(pose, _stdevPose);
        NSLog(@"Reset %f %f %f %f", pose.x(), pose.y(), pose.floor(), pose.orientation());
        
        [timer invalidate];
    }
}


- (void) inputBeacons:(NSArray*) beacons
{
    if (beacons == _previousBeaconInput) {
        return;
    }
    _previousBeaconInput = beacons;
    NavLocalizeResult *r = [[NavLocalizeResult alloc] init];
    
    // for run test
    if ([beacons count] == 1 && [[beacons objectAtIndex:0] isKindOfClass:[NSString class]]) {
        if (_d1meanLoc) {
            r.x = Meter2Feet(_d1meanLoc->x());
            r.y = Meter2Feet(_d1meanLoc->y());
            r.knndist = 0.25;
        }
        _result = r;
        return;
    }
    
    if ([beacons count] == 0) {
        if (_d1meanLoc) {
            r.x = Meter2Feet(_d1meanLoc->x());
            r.y = Meter2Feet(_d1meanLoc->y());
            r.knndist = 0.25;
        }
        _result = r;
        return;
    }
    
    Beacons cbeacons;
    
    for(int i = 0; i < [beacons count]; i++) {
        CLBeacon *b = [beacons objectAtIndex: i];
        int rssi = -100;
        if (b.rssi < 0) {
            rssi = b.rssi;
        }
        NSString *key = [NSString stringWithFormat:@"%d", b.minor.intValue];
        Beacon cb(b.major.intValue, b.minor.intValue, rssi);
        cbeacons.push_back(cb);
    }

    cbeacons.timestamp([[NSDate date] timeIntervalSince1970]*1000);
    _localizer->putBeacons(cbeacons);
    
    
    if (_d1meanLoc) {
        r.x = Meter2Feet(_d1meanLoc->x());
        r.y = Meter2Feet(_d1meanLoc->y());
        r.knndist = 0.25;
        //NSLog(@"%f, %f, %f", r.x, r.y, r.knndist);
    } else {
        r.x = 0;
        r.y = 0;
    }
    
    //std::cout << "meanPose=" << *_d1meanPose << std::endl;
    
    [self sendStatusByP2P: *_localizer->getStatus()];
    
    _result = r;
}

- (NSDictionary*) statusToNSData: (Status) status{
    bool outputState = true;
    picojson::object json =  DataUtils::statusToJSONObject(status, outputState);
    std::string cppstr = picojson::value(json).serialize();
    //std::cout << "cppstr=" << cppstr << std::endl;
    //NSString *str = [NSString stringWithFormat:@"Status JSON will be here."];
    NSString *str = [NSString stringWithCString:cppstr.c_str() encoding:[NSString defaultCStringEncoding]];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:nil];
    
    //obj[@"building"] = self.buildingJSON;
    
    return obj;
}

- (void) sendStatusByP2P: (Status) status{
    if (!_p2pDebug) {
        return;
    }
    NSDictionary* data = [self statusToNSData: status];
    [[P2PManager sharedInstance] send:data withType:@"2d-status" ];
}

- (void)inputAcceleration:(NSDictionary *)data
{
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=_previousAccTimestamp){
        
        Acceleration acc = Acceleration([data[@"timestamp"] doubleValue]*1000,
                                        [data[@"x"] doubleValue ],
                                        [data[@"y"] doubleValue ],
                                        [data[@"z"] doubleValue ]);
        
        //NSLog(@"input acc");
        _localizer->putAcceleration(acc);
    }
    _previousAccTimestamp = timestamp;
}

- (void) inputMotion: (NSDictionary*) data
{
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=_previousAttTimestamp){
        Attitude att = Attitude([data[@"timestamp"] doubleValue]*1000,
                                [data[@"pitch"] doubleValue ],
                                [data[@"roll"] doubleValue ],
                                [data[@"yaw"] doubleValue ]);
        
        //NSLog(@"input att");
        _localizer->putAttitude(att);
    }
    _previousAttTimestamp = timestamp;
}


- (double) computeDistanceScoreWithOptions: (NSDictionary*) options{
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    double distanceSum = 0;
    assert(_d1states);
    
    loc::Location stdloc = loc::Location::standardDeviation(*_d1states);
    
    for(State state: *_d1states){
        double distance = [self computeDistanceBetweenState:state AndEdge:edge];
        distanceSum += distance;
    }
    double distanceMean = distanceSum/_d1states->size();
    double v = fmax(distanceMean, sqrt(pow(stdloc.x(),2) + pow(stdloc.y(),2)))/6.0;
    
    NSLog(@"2D knnDist: %@, %.2f, %.2f, %.2f, %.2f", edgeID, v, distanceMean, stdloc.x(), stdloc.y());
    return v;
}


- (double) computeDistanceBetweenState: (State) state AndEdge:(NavLightEdge*) edge{
    static double distanceByFloorDiff = 100;
    static double floorDifferenceTolerance = 0.1;
    
    double distance = 0;
    double x = Meter2Feet(state.x());
    double y = Meter2Feet(state.y());
    double floor = state.floor() + 1;
    Nav2DPoint* point = [[Nav2DPoint alloc] initWithX:x Y:y];
    
    double floorDifference = fabs(floor-edge.floor);
    if(floorDifference>floorDifferenceTolerance){
        distance += floorDifference*distanceByFloorDiff;
    }
    
    distance += [edge getDistanceNearestPointOnLineSegmentFromPoint:point];
    return distance;
}

//- (double) computeDistanceScoreWithOptions: (NSDictionary*) options{
//    return [self computeAverageNegativeLogLikelihood];
//}


- (double) computeAverageNegativeLogLikelihood{
    double sum = 0;
    for(State s: *_d1states){
        sum += s.negativeLogLikelihood();
    }
    return sum/_d1states->size();
}

- (void)setBeacons:(NSDictionary *)beacons
{
    // BLE beacon locations
    
    BLEBeacons bleBeacons;
    for(NSString *key: beacons) {
        NSDictionary *beacon = beacons[key];
        std::string uuid = [beacon[@"uuid"] UTF8String];
        int major = [beacon[@"major"] intValue];
        int minor = [beacon[@"minor"] intValue];
        double x = [TopoMap unit2meter:[beacon[@"x"] doubleValue]];
        double y = [TopoMap unit2meter:[beacon[@"y"] doubleValue]];
        double z = 0;
        double floor = 0;
        BLEBeacon b = BLEBeacon(uuid, major, minor, x, y, z, floor);
        bleBeacons.push_back(b);
    }
    _dataStore->bleBeacons(bleBeacons);
    
    
    NSString *tempPath = NSTemporaryDirectory();
    tempPath = [tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-obsmodel.json", super.idStr]];
    NSFileManager *fm = [NSFileManager defaultManager];
    std::string serializedModelPath = [tempPath UTF8String];
    std::cout << "serializedModelPath: " << serializedModelPath << std::endl;
    
    if ([fm fileExistsAtPath:tempPath]) {
        std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> deserializedModel(new GaussianProcessLDPLMultiModel<State, Beacons>());
        {
            std::ifstream ifs(serializedModelPath);
            deserializedModel->load(ifs);
        }
        _localizer->observationModel(deserializedModel);
    } else {
        // Train observation model
        std::shared_ptr<GaussianProcessLDPLMultiModelTrainer<State, Beacons>>obsModelTrainer( new GaussianProcessLDPLMultiModelTrainer<State, Beacons>());
        obsModelTrainer->dataStore(_dataStore);
        std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> obsModel( obsModelTrainer->train());
        _localizer->observationModel(obsModel);
        
        // Seriealize observation model
        //std::cout << "Serializing observationModel" <<std::endl;
        //{
        //    std::ofstream ofs(serializedModelPath);
        //    obsModel->save(ofs);
        //}
    }
}

@end
