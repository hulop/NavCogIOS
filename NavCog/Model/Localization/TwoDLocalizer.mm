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
 *******************************************************************************/

#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

#import "P2PManager.h"

#import "TwoDLocalizer.h"
#import "NavUtil.h"
#import "NavEdge.h"
#import "NavNode.h"
#import "NavLocalizeResult.h"
#import "NavLineSegment.h"

#include <bleloc/StreamLocalizer.hpp>
#include <bleloc/StreamParticleFilter.hpp>

#include <bleloc/PoseRandomWalker.hpp>

#include <bleloc/GridResampler.hpp>
#include <bleloc/StatusInitializerImpl.hpp>

#include <bleloc/DataStore.hpp>
#include <bleloc/DataStoreImpl.hpp>

#include <bleloc/OrientationMeterAverage.hpp>
#include <bleloc/PedometerWalkingState.hpp>

#include <bleloc/GaussianProcessLDPLMultiModel.hpp>

// for pose random walker in building
#include <bleloc/Building.hpp>
#include <bleloc/PoseRandomWalkerInBuilding.hpp>

#include <bleloc/StrongestBeaconFilter.hpp>

#include <bleloc/MetropolisSampler.hpp>

#import "NavLineSegment.h"

using namespace loc;

typedef struct LocalizerData2 {
    TwoDLocalizer* localizer;
} LocalizerData;

enum ResetMode{
    reset,
    allReset
};

@interface TwoDLocalizer ()
@property NavEdge *currentEdge;
@property std::shared_ptr<OrientationMeter> orientationMeter;
@property NSMutableArray *buildingJSON;
@property NSTimer *tryResetTimer;
@property NSDictionary *currentOptions;
@property LocalizerData2 userData;

@property std::shared_ptr<Location> meanLoc;
@property std::shared_ptr<Pose> meanPose;
@property std::shared_ptr<States> states;

@property loc::Pose stdevPose;
@property NSArray *previousBeaconInput;
@property NavLocalizeResult *result;

@property long previousTimestamp;
@property ResetMode resetMode;

@end

@implementation TwoDLocalizer

- (void)dealloc
{
    delete _localizer;
}

- (id) init
{
    self = [super init];
    [self initDebug];
    return self;
}

- (instancetype) initWithID: (NSString*) idStr
{
    self = [super initWithID: idStr];
    [self initDebug];
    return self;
}

- (void) initDebug {
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
}

- (void)initializeState:(NSDictionary *)options;
{
    _resetMode = ResetMode::reset;
    self.currentOptions = options;
    if (options == nil) {
        return;
    }
    if (options[@"allreset"]) {
        NSLog(@"2D localizer is all reset");
        _resetMode = ResetMode::allReset;
        self.localizer->resetStatus();
        return;
    }
    if (!options[@"first"] || ![options[@"first"] boolValue]) {
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
        
        NavLightEdge *ledge = [[NavLightEdgeHolder sharedInstance] getNavLightEdgeByEdgeID:options[@"edgeID"]];
        bool forward = [options[@"forward"] boolValue];
        
        NavLineSegment *seg = ledge.lineSegments[forward?0:ledge.lineSegments.count-1];
        
        double n1x = forward?seg.point1.x:seg.point2.x;
        double n1y = forward?seg.point1.y:seg.point2.y;
        double n2x = forward?seg.point2.x:seg.point1.x;
        double n2y = forward?seg.point2.y:seg.point1.y;
        
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
        if (_meanLoc) {
            r.x = Meter2Feet(_meanLoc->x());
            r.y = Meter2Feet(_meanLoc->y());
            r.knndist = 0.25;
        }
        _result = r;
        return;
    }
    
    if ([beacons count] == 0) {
        if (_meanLoc) {
            r.x = Meter2Feet(_meanLoc->x());
            r.y = Meter2Feet(_meanLoc->y());
            r.knndist = 0.25;
        }
        _result = r;
        return;
    }

    // convert NSArray* to loc::Beacons to input it into the localizer
    Beacons cbeacons;
    for(int i = 0; i < [beacons count]; i++) {
        CLBeacon *b = [beacons objectAtIndex: i];
        int rssi = -100;
        if (b.rssi < 0) {
            rssi = b.rssi;
        }
        Beacon cb(b.major.intValue, b.minor.intValue, rssi);
        cbeacons.push_back(cb);
    }
    cbeacons.timestamp([[NSDate date] timeIntervalSince1970]*1000);
    
    // reset status with observed beacons during allReset mode.
    if(_resetMode==allReset){
        std::cout << "resetMode=allReset" << std::endl;
        _localizer->resetStatus(cbeacons);
    }
    
    _localizer->putBeacons(cbeacons);
    if (_meanLoc) {
        r.x = Meter2Feet(_meanLoc->x());
        r.y = Meter2Feet(_meanLoc->y());
        r.knndist = 0.25;
        //NSLog(@"%f, %f, %f", r.x, r.y, r.knndist);
    } else {
        r.x = 0;
        r.y = 0;
    }
    std::cout << "meanPose=" << *_meanPose << std::endl;
    
    //[self sendStatusByP2P: *_localizer->getStatus()];
    
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
    NSDictionary* data = [self statusToNSData: status];
    [[P2PManager sharedInstance] send:data withType:@"2d-status" ];
}

- (void)inputAcceleration:(NSDictionary *)data
{
    
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=_previousTimestamp){
    
    Acceleration acc = Acceleration([data[@"timestamp"] doubleValue]*1000,
                                    [data[@"x"] doubleValue ],
                                    [data[@"y"] doubleValue ],
                                    [data[@"z"] doubleValue ]);

    //NSLog(@"input acc");
    _localizer->putAcceleration(acc);
    }
    _previousTimestamp = timestamp;
}

- (void) inputMotion: (NSDictionary*) data
{
    static long previousTimestamp = -1;
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=previousTimestamp){
    Attitude att = Attitude([data[@"timestamp"] doubleValue]*1000,
                                    [data[@"pitch"] doubleValue ],
                                    [data[@"roll"] doubleValue ],
                                    [data[@"yaw"] doubleValue ]);

    //NSLog(@"input att");
    _localizer->putAttitude(att);
    }
    previousTimestamp = timestamp;
}


- (double) computeDistanceScoreWithOptions: (NSDictionary*) options{
    if(_resetMode==allReset){
        return [self computeDistanceScoreWithOptionsMeanLocation:options];
    }else{
        return [self computeDistanceScoreWithOptionsTransit:options];
    }
    //return [self computeDistanceScoreWithOptionsAvgDist:options];
}

// Parameters to compute distance score
double largeDistance = 100*100;
double distanceByFloorDiff = 10;
double floorDifferenceTolerance = 0.1;

- (double) computeDistanceScoreWithOptionsMeanLocation: (NSDictionary*) options{
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    if (!_states) {
        return largeDistance; // return far distance if not ready
    }
    assert(_states);
    
    double distance = [self computeDistanceBetweenLocation:*_meanLoc AndEdge:edge];
    distance = Feet2Meter(distance); // in meter
    loc::Location stdloc = loc::Location::standardDeviation(*_states); //in meter

    double distThresh95percentile = 5.1;
    double v = fmax(distance, sqrt(pow(stdloc.x(),2) + pow(stdloc.y(),2)))/distThresh95percentile;
    NSLog(@"2D dist for current loc: %@, %.2f, %.2f, %.2f, %.2f", edgeID, v, distance, stdloc.x(), stdloc.y());
    if(v<=1.0){
        std::cout << "2D dist for initialization < 1." << std::endl;
    }
    return v;
}

- (double) computeDistanceScoreWithOptionsAvgDist: (NSDictionary*) options{
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    double distanceSum = 0;
    if (!_states) {
        return largeDistance; // return far distance if not ready
    }
    assert(_states);
    
    double x = Meter2Feet(_meanLoc->x());
    double y = Meter2Feet(_meanLoc->y());
    Nav2DPoint* meanPoint = [[Nav2DPoint alloc] initWithX:x Y:y];
    Nav2DPoint* pointOnSeg = [[edge getNearestSegmentFromPoint:meanPoint] getNearestPointOnLineSegmentFromPoint:meanPoint];
    
    x = Feet2Meter(pointOnSeg.x);
    y = Feet2Meter(pointOnSeg.y);
    double z = 0;
    double floor = edge.floor - 1; // floor field in Edge class starts from 1.
    Location meanLocOnSeg(x,y,z,floor);
    
    // in meter
    distanceSum = 0;
    std::stringstream ss;
    for(State state: *_states){
        double distance = [self computeDistanceBetweenPoint:meanLocOnSeg And:state];
        distanceSum += distance;
        ss << distance << ",";
    }
    distanceSum/=(_states->size());
    // in feet
    double threshold = 6.0; // feet
    double v = Meter2Feet(distanceSum)/threshold;
    NSLog(@"2D distance: edgeID=%@, dist=%.2f", edgeID, v);
    return v;
}


- (double) computeDistanceScoreWithOptionsTransit: (NSDictionary*) options{
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    if(!_states){
        return largeDistance; // return far distance if not ready
    }
    assert(_states);
    
    loc::Location stdloc = loc::Location::standardDeviation(*_states);
    double distanceSum = 0;
    for(State state: *_states){
        double distance = [self computeDistanceBetweenLocation:state AndEdge:edge];
        distanceSum += distance;
    }
    double distanceMean = distanceSum/_states->size();
    double v = fmax(distanceMean, sqrt(pow(stdloc.x(),2) + pow(stdloc.y(),2)))/6.0;
    NSLog(@"2D knnDist: %@, %.2f, %.2f, %.2f, %.2f", edgeID, v, distanceMean, stdloc.x(), stdloc.y());
    return v;
}

- (double) computeDistanceBetweenLocation: (Location) state AndEdge:(NavLightEdge*) edge{
    
    double distance = 0;
    double x = Meter2Feet(state.x());
    double y = Meter2Feet(state.y());
    double floor = state.floor() + 1;
    Nav2DPoint* point = [[Nav2DPoint alloc] initWithX:x Y:y];
    
    double floorDifference = fabs(floor-edge.floor);
    if(floorDifference>floorDifferenceTolerance){
        distance += floorDifference*distanceByFloorDiff;
    }
    
    distance += [[edge getNearestSegmentFromPoint:point] getDistanceNearestPointOnLineSegmentFromPoint:point];
                 
    return distance;
}

- (double) computeDistanceBetweenPoint: (Location) point1 And: (Location) point2{

    double distance = 0;
    double floorDifference = std::abs(point1.floor()-point2.floor());
    if(floorDifference>floorDifferenceTolerance){
        distance += floorDifference*distanceByFloorDiff;
    }
    distance += Location::distance2D(point1, point2);
    
    return distance;
}


void calledWhenUpdated(void *userData, Status * pStatus){
    //NSLog(@"location updated");
    LocalizerData2 *localizerData = (LocalizerData2*)userData;
    TwoDLocalizer *loc = localizerData->localizer;
    
    loc.meanLoc = pStatus->meanLocation();
    loc.meanPose = pStatus->meanPose();
    loc.states = pStatus->states();
    
    NSDictionary *data = @{
                           @"x": @(loc.meanLoc->x()),
                           @"y": @(loc.meanLoc->y()),
                           @"z": @(loc.meanLoc->z()),
                           @"floor": @(loc.meanLoc->floor()),
                           @"orientation": @(loc.meanPose->orientation()),
                           @"velocity":@(loc.meanPose->velocity())
                           };

    [[P2PManager sharedInstance] send:data withType:@"2d-position" ];
    [loc sendStatusByP2P: *loc.localizer->getStatus()];
    
   // printf("2D %f, %f, %f, %f, %f\n", meanLoc->x(), meanLoc->y(), meanLoc->floor(), meanPose->orientation(), meanPose->velocity());
    //std::cout << meanLoc->toString() << std::endl;
}


- (void)initializeWithJSON:(NSMutableDictionary *)json
{
    // write data into temp file and remove from memory
    NSString *idStr = @"ObservationModelParameters.json";
    NSString *ObservationModelParametersPath = [NavUtil createTempFile:[json objectForKey:@"ObservationModelParameters"] forID:&idStr];
    [json removeObjectForKey:@"ObservationModelParameters"];
    
    NSArray *samplesJson = [json objectForKey:@"samples"];
    for(int i = 0; i < [samplesJson count]; i++) {
        NSMutableDictionary *sample = [samplesJson objectAtIndex:i];
        NSString *idStr = [NSString stringWithFormat:@"sample%d", i];
        NSString *path = [NavUtil createTempFile:[sample objectForKey:@"data"] forID:&idStr];
        [sample removeObjectForKey:@"data"];
        [sample setObject:path forKey:@"dataPath"];
    }
    // end

    // observation model
    NSLog(@"observation model: %@", ObservationModelParametersPath);
    std::string serializedModelPath = [ObservationModelParametersPath UTF8String];
    std::cout << serializedModelPath << std::endl;
//    bool doTraining = false;
//    if(doTraining){
//        // Train observation model
//        std::shared_ptr<GaussianProcessLDPLMultiModelTrainer<State, Beacons>>obsModelTrainer( new GaussianProcessLDPLMultiModelTrainer<State, Beacons>());
//        obsModelTrainer->dataStore(dataStore);
//        std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> obsModel( obsModelTrainer->train());
//        //localizer->observationModel(obsModel);
//        
//        // Seriealize observation model
//        std::cout << "Serializing observationModel" <<std::endl;
//        {
//            std::ofstream ofs(serializedModelPath);
//            obsModel->save(ofs);
//        }
//    }
    
    // De-serialize observation model
    std::cout << "De-serializing observationModel" <<std::endl;
    std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> deserializedModel(new GaussianProcessLDPLMultiModel<State, Beacons>());
    {
        std::ifstream ifs(serializedModelPath);
        deserializedModel->load(ifs);
    }
    
    
    _localizer = new StreamParticleFilter();
    _userData.localizer = self;
    _localizer->updateHandler(calledWhenUpdated, &_userData);
    
    int nStates = 1000;
    _localizer->numStates(nStates);
    //double alphaWeaken = 0.5;
    double alphaWeaken = 0.3;
    //double alphaWeaken = 0.01;
    _localizer->alphaWeaken(alphaWeaken);
    
    // Create data store
    std::shared_ptr<DataStoreImpl> dataStore(new DataStoreImpl());
    
    // Building - change read order to reduce memory usage peak
    //ImageHolder::setMode(ImageHolderMode(heavy));
    BuildingBuilder buildingBuilder;
    NSArray *buildingsJson = [json objectForKey:@"layers"];
    self.buildingJSON = [buildingsJson mutableCopy];
    for(int floor_num = 0; floor_num < [buildingsJson count]; floor_num++) {
        NSDictionary *building = [buildingsJson objectAtIndex:floor_num];
        NSDictionary *param = building[@"param"];
        double ppmx = [[param objectForKey:@"ppmx"] doubleValue];
        double ppmy = [[param objectForKey:@"ppmy"] doubleValue];
        double ppmz = [[param objectForKey:@"ppmz"] doubleValue];
        double originx = [[param objectForKey:@"originx"] doubleValue];
        double originy = [[param objectForKey:@"originy"] doubleValue];
        double originz = [[param objectForKey:@"originz"] doubleValue];
        CoordinateSystemParameters coordSysParams(ppmx, ppmy, ppmz, originx, originy, originz);
        
        NSString *data = [building objectForKey:@"data"];
        NSString *idStr = [NSString stringWithFormat:@"building%d", floor_num];
        NSString *path = [NavUtil createTempFile:data forID:&idStr];
        NSLog(@"floor %d: %@", floor_num, path);
        std::string cppPath = [path UTF8String];
        
        buildingBuilder.addFloorCoordinateSystemParametersAndImagePath(floor_num, coordSysParams, cppPath);
        //self.building[@"data"]
        self.buildingJSON[floor_num] = [building mutableCopy];
        self.buildingJSON[floor_num][@"data"] = nil;
        self.buildingJSON[floor_num][@"image"] = idStr;
        [[P2PManager sharedInstance] addFilePath:path withKey:idStr];
    }
    [[P2PManager sharedInstance] addJSON:self.buildingJSON withKey:@"building"];
    dataStore->building(buildingBuilder.build());
    
    // Sampling data
    
    //Samples samples;
    for(int i = 0; i < [samplesJson count]; i++) {
        NSMutableDictionary *sample = [samplesJson objectAtIndex:i];
        NSString *path = [sample objectForKey:@"dataPath"];
        NSLog(@"sample %d: %@", i, path);
        std::string cppPath = [path UTF8String];
        std::ifstream  istream(cppPath);
        //Samples samplesTmp = DataUtils::csvSamplesToSamples(istream);
        //samples.insert(samples.end(), samplesTmp.begin(), samplesTmp.end());
        dataStore->readSamples(istream);
    }
    //dataStore->samples(samples);
    
    // BLE beacon locations
    
    BLEBeacons bleBeacons;
    NSArray *beaconsJson = [json objectForKey:@"beacons"];
    for(int i = 0; i < [beaconsJson count]; i++) {
        NSDictionary *beacon = [beaconsJson objectAtIndex:i];
        NSString *data = [beacon objectForKey:@"data"];
        NSString *idStr = [NSString stringWithFormat:@"beacon%d", i];
        NSString *path = [NavUtil createTempFile:data forID:&idStr];
        NSLog(@"beacon %d: %@", i, path);
        std::string cppPath = [path UTF8String];
        std::ifstream bleBeaconIStream(cppPath);
        BLEBeacons bleBeaconsTmp = DataUtils::csvBLEBeaconsToBLEBeacons(bleBeaconIStream);
        bleBeacons.insert(bleBeacons.end(), bleBeaconsTmp.begin(), bleBeaconsTmp.end());
    }
    dataStore->bleBeacons(bleBeacons);
    
    
    
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
//    poseProperty.stdOrientation(3.0/180.0*M_PI);
    poseProperty.stdOrientation(10.0/180.0*M_PI);
    poseProperty.stdX(2.0);
    poseProperty.stdY(2.0);
    
    stateProperty.meanRssiBias(0.0);
    stateProperty.stdRssiBias(0.2);
    stateProperty.diffusionRssiBias(0.2);
//    stateProperty.diffusionOrientationBias(1.0/180*M_PI);
    stateProperty.diffusionOrientationBias(3.0/180*M_PI);

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
    Building building = dataStore->getBuilding();
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
    statusInitializer->dataStore(dataStore)
    .poseProperty(poseProperty).stateProperty(stateProperty);
    _localizer->statusInitializer(statusInitializer);
    
    // Set localizer
    _localizer->observationModel(deserializedModel);
    
    // Beacon filter
    std::shared_ptr<StrongestBeaconFilter> beaconFilter(new StrongestBeaconFilter());
    beaconFilter->nStrongest(10);
    _localizer->beaconFilter(beaconFilter);
    
    // Set standard deviation of Pose
    double stdevX = 0.25;
    double stdevY = 0.25;
    _stdevPose.x(stdevX).y(stdevY);
    
    // ObservationDependentInitializer
    std::shared_ptr<MetropolisSampler<State, Beacons>> obsDepInitializer(new MetropolisSampler<State, Beacons>());
    obsDepInitializer->observationModel(deserializedModel);
    obsDepInitializer->statusInitializer(statusInitializer);
    obsDepInitializer->burnIn(1000);
    obsDepInitializer->radius2D(10); // 10[m]
    _localizer->observationDependentInitializer(obsDepInitializer);
    
    // Mixture settings
    double mixProba = 0.001;
    StreamParticleFilter::MixtureParameters mixParams;
    mixParams.mixtureProbability = mixProba;
    _localizer->mixtureParameters(mixParams);
    
}

@end
