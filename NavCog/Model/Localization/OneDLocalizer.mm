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

#import <bleloc/BeaconFilterChain.hpp>
#import <bleloc/CleansingBeaconFilter.hpp>
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

@property NSArray *previousBeaconInput;
@property NavLocalizeResult *result;
@property long previousAttTimestamp;
@property long previousAccTimestamp;
@property LocalizerData userData;

@property std::shared_ptr<Location> d1meanLoc;
@property std::shared_ptr<Pose> d1meanPose;
@property std::shared_ptr<States> d1states;

@property std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> obsModel;
@property std::shared_ptr<BeaconFilterChain> beaconFilter;
@property std::shared_ptr<StatusInitializerImpl> statusInitializer;
@property Beacons cbeacons;
@property int minCountKnownBeacons;
@property double alphaObsModel;

@property BOOL transiting;

@end

@implementation OneDLocalizer
static OneDLocalizer *activeLocalizer;


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
    
    [[P2PManager sharedInstance] send:data withType:@"2d-position" ];
    [loc sendStatusByP2P: *loc.localizer->getStatus()];
    
    NSLog(@"%@ 1D %f, %f, %f, %f, %f\n", loc, loc.d1meanLoc->x(), loc.d1meanLoc->y(), loc.d1meanLoc->floor(), loc.d1meanPose->orientation(), loc.d1meanPose->velocity());
    //std::cout << meanLoc->toString() << std::endl;
    
    
    if (loc.transiting) {
        for(int i = 0; i < loc.d1states->size(); i++) {
            //double v = (rand()%360-180)/180.0*M_PI;
            double d1 = (rand()%100-50)/100.0;
            double d2 = (rand()%100-50)/100.0;
            //NSLog(@"i=%d v=%f", i, v);
            //loc.d1states->at(i).orientationBias(v);
            //loc.d1states->at(i).orientation(v);
            loc.d1states->at(i).x(fmin(2,fmax(-2,loc.d1states->at(i).x()+d1)));
            loc.d1states->at(i).y(loc.d1states->at(i).y()+d2);
        }
    }
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
    _alphaObsModel = 0.3;
    _localizer->alphaWeaken(0.3);
    
    _dataStore = std::shared_ptr<DataStoreImpl>(new DataStoreImpl());
    
    BuildingBuilder buildingBuilder;

    double ppmx = 8;
    double ppmy = -8;
    double ppmz = 1;
    double originx = 1000;
    double originy = 1000;
    double originz = 0;

    CoordinateSystemParameters coordSysParams(ppmx, ppmy, ppmz, originx, originy, originz);

    //NSString *imgpath = [[NSBundle mainBundle] pathForResource:@"corridor" ofType:@"png"];
    NSString *imgpath = [[NSBundle mainBundle] pathForResource:@"white" ofType:@"png"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:imgpath]) {
        NSLog(@"white.png file is not found, %@", imgpath);
        return;
    }
    
    std::string cppPath = [imgpath UTF8String];
    buildingBuilder.addFloorCoordinateSystemParametersAndImagePath(0, coordSysParams, cppPath);
    _dataStore->building(buildingBuilder.build());
    
    NSMutableArray *buildingJSON = [@[] mutableCopy];
    [buildingJSON addObject:[@{} mutableCopy]];
    NSDictionary *param = @{
                            @"ppmx":@(ppmx),
                            @"ppmy":@(ppmy),
                            @"ppmz":@(ppmz),
                            @"originx":@(originx),
                            @"originy":@(originy),
                            @"originz":@(originz)
        };
    buildingJSON[0][@"param"] = param;
    buildingJSON[0][@"data"] = nil;
    buildingJSON[0][@"image"] = @"white";
    [[P2PManager sharedInstance] addFilePath:imgpath withKey:@"white"];
    [[P2PManager sharedInstance] addJSON:buildingJSON withKey:@"building"];
    
    Samples samples;
    
    for(NSString* line: [lines subarrayWithRange:NSMakeRange(1, [lines count]-1)]) {
        NSArray *items = [line componentsSeparatedByString:@","];
        if ([items count] < 3) continue;
        double x = [TopoMap unit2meter:[items[0] doubleValue]*3];
        double y = [TopoMap unit2meter:[items[1] doubleValue]*3];
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
    //pedometerWSParams.walkDetectSigmaThreshold(0.1);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"wheelmode_preference"]) {
        NSString *tstr = [[NSUserDefaults standardUserDefaults] objectForKey:@"wheelmode_threthold_preference"];
        double t = tstr?[tstr doubleValue]:0.05;
        pedometerWSParams.walkDetectSigmaThreshold(t);
    }
    
    // END TODO
    std::shared_ptr<Pedometer> pedometer(new PedometerWalkingState(pedometerWSParams));
    
    // Set dependency
    _localizer->orientationMeter(orientationMeter);
    _localizer->pedometer(pedometer);
    
    // Build System Model
    // TODO (PoseProperty and StateProperty)
    PoseProperty poseProperty;
    StateProperty stateProperty;
    // The initial velocity of a particle is sampled from a truncated normal distribution defined by a mean, a standard deviation, a lower bound and an upper bound.
    poseProperty.meanVelocity(1.0); // mean
    poseProperty.stdVelocity(0.3); // standard deviation
    
    // if no effective beacon information, the average speed will be stable aroud (min+max)/2
    poseProperty.minVelocity(0.1); // lower bound
    poseProperty.maxVelocity(1.5); // upper bound
    poseProperty.diffusionVelocity(0.1); // standard deviation of a noise added to the velocity of a particle [m/s/s]
    
    poseProperty.stdOrientation(3.0/180.0*M_PI); // standard deviation of a noise added to the orientation obtained from the smartphone sensor.

    // The initial location of a particle is generated by adding a noise to a location where sampling data were collected. These are parameters of the noise.
    poseProperty.stdX(0); // standard deviation in x axis. (Zero in 1D cases.)
    poseProperty.stdY(2); // standard deviation in y axis.
    
    // The difference between the observed and the predicted RSSI is described by a RSSI bias parameter. The initial value is sampled from a normal distribution.
    stateProperty.meanRssiBias(0.0); // mean
    stateProperty.stdRssiBias(2.0); // standard deviation
    stateProperty.diffusionRssiBias(0.2); // standard deviation of a noise added to the rssi bias [dBm/s]
    // The difference between the observed and the actual orientation is described by a orientation bias parameter.
    stateProperty.diffusionOrientationBias(1.0/180*M_PI); // standard deviation of a noise added to the orientation bias [rad/s]
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
    
    
    std::shared_ptr<SystemModel<State, PoseRandomWalkerInput>> sysModel = poseRandomWalkerInBuilding;
    
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
    _statusInitializer = statusInitializer;
    
    // Set localizer
    //_localizer->observationModel(deserializedModel);
    
    // Beacon filter
    std::shared_ptr<CleansingBeaconFilter> cleansingBeaconFilter(new CleansingBeaconFilter());
    std::shared_ptr<StrongestBeaconFilter> strongestBeaconFilter(new StrongestBeaconFilter());
    
    int nStrongest = 10; // The number of the strongest RSSI beacons used to evaluate likelihoods in a localizer.
    _minCountKnownBeacons = 3;
    strongestBeaconFilter->nStrongest(nStrongest);
    _beaconFilter.reset(new BeaconFilterChain());
    _beaconFilter->addFilter(cleansingBeaconFilter);
    _beaconFilter->addFilter(strongestBeaconFilter);
    
    _localizer->beaconFilter(_beaconFilter);
    
}

- (void)initializeState:(NSDictionary *)options;
{
    self.currentOptions = options;
    if (options == nil) {
        return;
    }
    _transiting = true;
    if ([options[@"type"] isEqualToString:@"transition"]) {
        NSLog(@"1D localizer is all reset for transition");
        self.localizer->resetStatus();
        return;
    }
    if ([options[@"type"] isEqualToString:@"end"]) {
        NSLog(@"1D localizer is all reset for end");
        self.localizer->resetStatus();
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
    
    _transiting = false;
    
    NavLightEdge *ledge = [[NavLightEdgeHolder sharedInstance] getNavLightEdgeByEdgeID:options[@"edgeID"]];
    bool forward = [options[@"forward"] boolValue];
    
    NavLineSegment *seg = ledge.lineSegments[forward?0:ledge.lineSegments.count-1];
    
    double n1x = forward?seg.point1.x:seg.point2.x;
    double n1y = forward?seg.point1.y:seg.point2.y;
    double n2x = forward?seg.point2.x:seg.point1.x;
    double n2y = forward?seg.point2.y:seg.point1.y;

    NavLocalizeResult *r = [[NavLocalizeResult alloc] init];  // in feet
    r.x = n1x;
    r.y = n1y;
    _result = r;

    double x, y, z, floor, orientation;
    
    x = Feet2Meter(n1x);
    y = Feet2Meter(n1y);
    z = Feet2Meter(0);
    floor = [options[@"floor"] doubleValue];
    orientation = atan2(n2y-n1y, n2x-n1x);
    loc::Pose pose;
    pose.x(x).y(y).z(z).floor(floor).orientation(orientation); // in meter
    
    NSLog(@"reset:(%f,%f)->(%f,%f), x=%f,y=%f,orientation=%f",n1x,n1y,n2x,n2y,x, y, orientation);
    
    std::cout << "Sending reset request to the localizer.";
    std::cout << ", resetPose = " << pose << std::endl;
    
    // Set standard deviation of Pose
    loc::Pose stdevPose;
    stdevPose.x(0.25).y(0.25).orientation(1.0/180.0*M_PI);
    // stdevPose.normalVelocity(0.2); // TODO
    
    self.localizer->resetStatus(pose, stdevPose);
    NSLog(@"Reset %f %f %f %f", pose.x(), pose.y(), pose.floor(), pose.orientation());
}

- (NavLocalizeResult *)getLocation
{
    // need to convert 2D result into 1D
    return _result;
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
    _cbeacons = cbeacons;
    
    if(_transiting){
        [self inputBeaconsTransit:cbeacons];
        return;
    }
    
    _localizer->putBeacons(cbeacons);
    //[self sendStatusByP2P: *_localizer->getStatus()];
    
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
    
    _result = r;
}

int nEvalPoint = 1000;
double cumProba = 0.99;

- (void) inputBeaconsTransit: (Beacons) beacons{
    
    States states = _statusInitializer->initializeStates(nEvalPoint);

    State maxLLState = [self findMaximumLikelihoodLocation:beacons Given:states With: cumProba];
    NavLocalizeResult *r = [[NavLocalizeResult alloc] init];
    
    r.x = Meter2Feet(maxLLState.x());
    r.y = Meter2Feet(maxLLState.y());
    r.knndist = maxLLState.mahalanobisDistance();
    
    //NSLog(@"TRANSIT:x=%f,y=%f,knndist=%f",r.x,r.y,r.knndist);

    [self sendStatesByP2P:states];

    NSDictionary *data = @{
                           @"x": @(maxLLState.x()),
                           @"y": @(maxLLState.y()),
                           @"z": @(maxLLState.z()),
                           @"floor": @(maxLLState.floor()),
                           @"orientation": @(maxLLState.orientation()),
                           @"velocity":@(maxLLState.velocity())
                           };
    
    if (self == activeLocalizer) {
        [[P2PManager sharedInstance] send:data withType:@"2d-position" ];
    }
    
    _result = r;
}

- (State) findMaximumLikelihoodLocation: (Beacons) beacons Given: (States) states With:(double) cumulative{
    Beacons beaconsFiltered = _beaconFilter->filter(beacons);
    
    _obsModel->fillsUnknownBeaconRssi(false);
    std::vector<std::vector<double>> logLLAndMahaDists = _obsModel->computeLogLikelihoodRelatedValues(states, beaconsFiltered);
    
    double countKnown = 0, countUnknown = 0;
    double minMahaDist = std::numeric_limits<double>::max();
    State stateMinMD;
    for(int i=0; i<states.size(); i++){
        std::vector<double> logLLAndMahaDist = logLLAndMahaDists.at(i);
        double logLikelihood = _alphaObsModel * logLLAndMahaDist.at(0);
        double mahaDist = _alphaObsModel * logLLAndMahaDist.at(1);
        countKnown = logLLAndMahaDist.at(2);
        countUnknown = logLLAndMahaDist.at(3);
        if(mahaDist < minMahaDist){
            minMahaDist = mahaDist;
            stateMinMD = states.at(i);
        }
    }
    
    int dof = 0;
    double quantile = 0.0;
    if(self.minCountKnownBeacons<=countKnown){
        dof = countKnown;
        quantile = MathUtils::quantileChiSquaredDistribution(dof, cumulative);
    }else{
        dof = 0;
        minMahaDist = 1000; // large value
        quantile = 1; // small value
    }
    
//    if(minMahaDist<1000){
//        NSLog(@"Mahalanobis distance: dof=%d, distance=%.2f, quantile=%.2f, #known=%.0f, #unknown=%.0f", dof, minMahaDist, quantile, countKnown, countUnknown);
//    }
    
    double normalizedMD = minMahaDist/quantile;
    stateMinMD.mahalanobisDistance(normalizedMD);
    return stateMinMD;
}

- (double) computeNormalizedMahalanobisDistance: (Beacons) beacons Given: (States) states With:(double) quantile{
    State stateMinMD = [self findMaximumLikelihoodLocation:beacons Given:states With:quantile];
    return stateMinMD.mahalanobisDistance();
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
    if (self != activeLocalizer) {
        return;
    }
    NSDictionary* data = [self statusToNSData: status];
    [[P2PManager sharedInstance] send:data withType:@"2d-status" ];
}

- (void) sendStatesByP2P: (States) states{
    Status status;
    States* statesNew = new States(states);
    status.states(statesNew);
    [self sendStatusByP2P:status];
}


- (void)inputAcceleration:(NSDictionary *)data
{
    activeLocalizer = self;
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=_previousAccTimestamp){
        
        Acceleration acc = Acceleration([data[@"timestamp"] doubleValue]*1000,
                                        [data[@"x"] doubleValue ],
                                        [data[@"y"] doubleValue ],
                                        [data[@"z"] doubleValue ]);
        
        //NSLog(@"input acc");
        if(!_transiting){
            _localizer->putAcceleration(acc);
        }
    }
    _previousAccTimestamp = timestamp;
}

- (void) inputMotion: (NSDictionary*) data
{
    activeLocalizer = self;
    long timestamp = [data[@"timestamp"] doubleValue]*1000;
    
    if(timestamp!=_previousAttTimestamp){
//        Attitude att = Attitude([data[@"timestamp"] doubleValue]*1000,
//                                [data[@"pitch"] doubleValue ],
//                                [data[@"roll"] doubleValue ],
//                                [data[@"yaw"] doubleValue ]);
        // ignore gyro sensor
        Attitude att = Attitude([data[@"timestamp"] doubleValue]*1000, 0, 0, 0);
        
        [[P2PManager sharedInstance] send:@{@"value":@(-[data[@"yaw"] doubleValue]/M_PI*180)} withType:@"orientation"];
        
        //NSLog(@"input att");
        if(!_transiting){
            _localizer->putAttitude(att);
        }
    }
    _previousAttTimestamp = timestamp;
}

- (std::vector<State>) navEdgeLightToKnotStates: (NavLightEdge*) edge ByFeet: (double) feet{
    double edgeLength = [edge length];
    
    double cutSize = edgeLength/feet;
    
    std::vector<State> states;
    for(int i=0; i <(cutSize+1); i++) {
        double ratio = (feet*i)/edgeLength;
        
        Nav2DPoint *p = [edge pointAtRatio:ratio];
        double xM = Feet2Meter(p.x);
        double yM = Feet2Meter(p.y);
        double z = 0;
        double floor = 0;
        Location loc(xM, yM, z, floor);
        Pose pose(loc);
        State state(pose);
        states.push_back(state);
    }
    return states;
}

- (double) trim: (double)x InRangeBetween : (double)x1 And : (double)x2{
    if(x1<x2){
        return [self trim: x InRangeFrom:x1 To:x2];
    }else{
        return [self trim: x InRangeFrom:x2 To:x1];
    }
}

- (double) trim:(double) x InRangeFrom: (double)x1 To: (double)x2{
    double xnew = std::max(x, x1);
    xnew = std::min(xnew, x2);
    return xnew;
}


- (double) computeDistanceScoreWithOptions: (NSDictionary*) options{
    if (_transiting) {
        return _result.knndist;
    }
    return [self computeBeaconBasedDistanceScoreWithOptions:options];
}

- (double) computeBeaconBasedDistanceScoreWithOptions: (NSDictionary*) options{
    double intervalInFeet = 1;
    double cumDensity = 0.99;
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    States states = [self navEdgeLightToKnotStates:edge ByFeet:intervalInFeet];
    double v = 100;
    
    Beacons beaconsFiltered = _beaconFilter->filter(_cbeacons);
    int dof = static_cast<int>(beaconsFiltered.size());
    
    if(_cbeacons.size()>0){
        v = [self computeNormalizedMahalanobisDistance:beaconsFiltered Given:states With: cumDensity];
    }
    //double v = _normalizedMahalanobisDistance;
    //NSLog(@"2D knnDist: eid=%@, dist=%.2f, dof=%d", edgeID, v, dof);
    return v;
}

- (double) computeParticleBasedDistanceScoreWithOptions: (NSDictionary*) options{
    NSString* edgeID = options[@"edgeID"];
    NavLightEdgeHolder* holder = [NavLightEdgeHolder sharedInstance];
    NavLightEdge* edge = [holder getNavLightEdgeByEdgeID:edgeID];
    
    double distanceSum = 0;
    if (!_d1states) {
        return 100 * 1000; // return far distance if not ready
    }
    assert(_d1states);
    
    loc::Location stdloc = loc::Location::standardDeviation(*_d1states);
    
    for(State state: *_d1states){
        double distance = [self computeDistanceBetweenState:state AndEdge:edge];
        distanceSum += distance;
    }
    double edgeLength = [edge length];
    
    double distanceMean = distanceSum/_d1states->size();
    double stdx = stdloc.x()*3;
    double stdy = stdloc.y()*3;
    double v = fmax(distanceMean, sqrt(pow(stdx,2) + pow(stdy,2)))/6.0;
    
    //NSLog(@"2D knnDist: %@, %.2f, %.2f, %.2f, %.2f, %.2f", edgeID, v, distanceMean, stdx, stdy, edgeLength);
    
    return v;
}


- (double) computeDistanceBetweenState: (State) state AndEdge:(NavLightEdge*) edge{
    static double distanceByFloorDiff = 100;
    static double floorDifferenceTolerance = 0.1;
    
    double distance = 0;
    double x = Meter2Feet(state.x());
    double y = Meter2Feet(state.y());
    //double floor = state.floor() + 1;
    Nav2DPoint* point = [[Nav2DPoint alloc] initWithX:x Y:y];
    
    //double floorDifference = fabs(floor-edge.floor);
    double floorDifference = 0; // assume on same floor
    if(floorDifference>floorDifferenceTolerance){
        distance += floorDifference*distanceByFloorDiff;
    }
    
    distance += [[edge getNearestSegmentFromPoint:point] getDistanceNearestPointOnLineSegmentFromPoint:point];
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
    
    std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> obsModel;
    if ([fm fileExistsAtPath:tempPath]) {
        //std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> deserializedModel(new GaussianProcessLDPLMultiModel<State, Beacons>());
        obsModel.reset(new GaussianProcessLDPLMultiModel<State, Beacons>());
        {
            std::ifstream ifs(serializedModelPath);
            obsModel->load(ifs);
        }
        _localizer->observationModel(obsModel);
        _obsModel = obsModel;
    } else {
        // Train observation model
        std::shared_ptr<GaussianProcessLDPLMultiModelTrainer<State, Beacons>>obsModelTrainer( new GaussianProcessLDPLMultiModelTrainer<State, Beacons>());
        obsModelTrainer->dataStore(_dataStore);
        obsModel.reset(obsModelTrainer->train());
        ////std::shared_ptr<GaussianProcessLDPLMultiModel<State, Beacons>> obsModel( obsModelTrainer->train());
        _localizer->observationModel(obsModel);
        _obsModel = obsModel;
        
        // Seriealize observation model
        std::cout << "Serializing observationModel" <<std::endl;
        {
            std::ofstream ofs(serializedModelPath);
            obsModel->save(ofs);
        }
    }
    obsModel->fillsUnknownBeaconRssi(false);
}

@end
