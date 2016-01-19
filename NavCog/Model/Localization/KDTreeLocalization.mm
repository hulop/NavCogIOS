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

#import "KDTreeLocalization.h"
#import <opencv2/opencv.hpp>
#import <unordered_map>
#import <CoreLocation/CoreLocation.h>
#import <algorithm>

#define KNN_NUM 5
#define TREE_NUM 5
#define SMOOTHING_WEIGHT 0.6
#define JUMPING_BOUND 3

using namespace std;

@interface KDTreeLocalization ()

@property (nonatomic) vector<float> preFeatVec;
@property (nonatomic) vector<float> featVec;
@property (nonatomic) vector<int> indices;
@property (nonatomic) vector<float> dists;
@property (nonatomic) cv::Mat featMap;
@property (nonatomic) cv::Mat posMap;
@property (nonatomic) cv::flann::Index kdTree;
@property (nonatomic) NavPoint currentLocation;
@property (nonatomic) unordered_map<int, int> beaconIndexMap;
@property (nonatomic) int sampleNum;
@property (nonatomic) int beaconNum;
@property (nonatomic) Boolean bStart;
@property (nonatomic) struct NavPoint prePoint;
@property (nonatomic) NSDate *preDate, *jumpDate;
@property (nonatomic) NavLocalizeResult *result;
@property (nonatomic) double timeMultiplier;

@end

@implementation KDTreeLocalization

- (instancetype)init
{
    self = [super init];
    if (self) {
        for (int i = 0; i < _beaconNum; i++) {
            _featVec[i] = -100;
        }
        for (int i = 0; i < _beaconNum; i++) {
            _preFeatVec[i] = -100;
        }
        _bStart = false;
    }
    _timeMultiplier = 1;
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    if ([env valueForKey:@"simspeed"]) {
        _timeMultiplier = 1.0/[[env valueForKey:@"simspeed"] doubleValue];
    }
    return self;
}

// when you restart navigation for another path
// you need to clean the history knowledge
- (void)initializeState:(NSDictionary *)options {
    for (int i = 0; i < _beaconNum; i++) {
        _featVec[i] = -100;
    }
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _bStart = false;
}

- (void)initializeWithFile:(NSString *)filename {
    _bStart = false;
    NSArray *split = [filename componentsSeparatedByString:@"."];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:(NSString *)split[0] ofType:(NSString *)split[1]];
    [self initializeWithAbsolutePath:filePath];
}

- (void)initializeWithAbsolutePath:(NSString *)filePath {
    _sampleNum = [self getDataNumOfFeatureFile:[filePath UTF8String]];
    
    FILE *fp = fopen([filePath UTF8String], "r");
    fscanf(fp, "MinorID of %d Beacon Used : ", &_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        int beaconID;
        fscanf(fp, "%d,", &beaconID);
        _beaconIndexMap[beaconID] = i;
    }
    
    _indices.resize(KNN_NUM);
    _dists.resize(KNN_NUM);
    _featVec.resize(_beaconNum);
    _preFeatVec.resize(_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _featMap.create(_sampleNum, _beaconNum, CV_32F);
    _posMap.create(_sampleNum, 2, CV_32F);
    for (int i = 0; i < _sampleNum; i++) {
        float x, y;
        int validBeaconNum;
        fscanf(fp, "%f,%f,%d,", &x, &y, &validBeaconNum);
        _posMap.at<float>(i,0) = x;
        _posMap.at<float>(i,1) = y;
        for (int j = 0; j < _beaconNum; j++) {
            _featMap.at<float>(i, j) = -100.0;
        }
        for (int j = 0; j < validBeaconNum; j++) {
            int majorID, minorID, rssi, indx;
            fscanf(fp, "%d,%d,%d,", &majorID, &minorID, &rssi);
            indx = _beaconIndexMap[minorID];
            _featMap.at<float>(i, indx) = rssi;
        }
    }
    
    _kdTree.build(_featMap, cv::flann::KDTreeIndexParams(TREE_NUM));
    fclose(fp);
}

/*
- (void)initializeWithDataString:(NSString *)dataStr {
    _bStart = false;
    const char *p = [dataStr UTF8String];
    int nr = 0;
    _sampleNum = [self getDataNumOfDataString:p];
    sscanf(p, "MinorID of %d Beacon Used : %n", &_beaconNum, &nr);
    p += nr;
    for (int i = 0; i < _beaconNum; i++) {
        int beaconID;
        sscanf(p, "%d,%n", &beaconID, &nr);
        p += nr;
        _beaconIndexMap[beaconID] = i;
    }
    
    _indices.resize(KNN_NUM);
    _dists.resize(KNN_NUM);
    _featVec.resize(_beaconNum);
    _preFeatVec.resize(_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _featMap.create(_sampleNum, _beaconNum, CV_32F);
    _posMap.create(_sampleNum, 2, CV_32F);
    for (int i = 0; i < _sampleNum; i++) {
        float x, y;
        int validBeaconNum;
        sscanf(p, "%f,%f,%d,%n", &x, &y, &validBeaconNum, &nr);
        p += nr;
        _posMap.at<float>(i,0) = x;
        _posMap.at<float>(i,1) = y;
        for (int j = 0; j < _beaconNum; j++) {
            _featMap.at<float>(i, j) = -100.0;
        }
        for (int j = 0; j < validBeaconNum; j++) {
            int majorID, minorID, rssi, indx;
            sscanf(p, "%d,%d,%d,%n", &majorID, &minorID, &rssi, &nr);
            p += nr;
            indx = _beaconIndexMap[minorID];
            _featMap.at<float>(i, indx) = rssi;
        }
    }
    
    _kdTree.build(_featMap, cv::flann::KDTreeIndexParams(TREE_NUM));
}
 */

- (NavLocalizeResult *)getLocation
{
    return _result;
}


//- (NavLocalizeResult *)localizeWithBeacons:(NSArray *)beacons {
- (void) inputBeacons:(NSArray *)beacons
{
    NSDate* now = [NSDate date];
    if (_bStart && _preDate && [now timeIntervalSinceDate:_preDate] < 0.5*_timeMultiplier) {
        // Return last position after 0.5 sec
        NavLocalizeResult *result;
        //struct NavPoint result;
        result.knndist = _prePoint.knndist;
        result.x = _prePoint.x * 3;
        result.y = _prePoint.y * 3;
        _result = result;
    }
    _preDate = now;
    float jump = JUMPING_BOUND, smooth = SMOOTHING_WEIGHT;
    if (_bStart && _jumpDate) {
        double duration = [now timeIntervalSinceDate:_jumpDate];
        if (duration > 10) {
            // Adjust jump & smooth parameter based on jumping duration
            jump = jump * duration;
//            smooth = 1.0;
            NSLog(@"duration=%f, jump=%f, smooth=%f", duration, jump, smooth);
        }
    }
    for (int i = 0; i < _beaconNum; i++) {
        _featVec[i] = -100;
    }
    for (CLBeacon *beacon in beacons) {
        if (_beaconIndexMap.find(beacon.minor.intValue) != _beaconIndexMap.end()) {
            _featVec[_beaconIndexMap[beacon.minor.intValue]] = (beacon.rssi == 0 ? -100 : beacon.rssi);
        }
    }
    
    for (int i = 0; i < _beaconNum; i++) {
        if (_preFeatVec[i] > -90) {
            _featVec[i] = (_featVec[i] < -99 ? _preFeatVec[i] : _featVec[i]);
        }
    }
    
    if (_bStart) {
        for (int i = 0; i < _beaconNum; i++) {
            _featVec[i] = _featVec[i] * smooth + _preFeatVec[i] * (1 - smooth);
        }
    }
    
    _kdTree.knnSearch(_featVec, _indices, _dists, KNN_NUM);
    //struct NavPoint result;
    NavLocalizeResult *result = [[NavLocalizeResult alloc] init];
    result.knndist = _dists[0];
    result.x = 0;
    result.y = 0;
    float distSum = 0;
    for (int i = 0; i < KNN_NUM; i++) {
        result.x += _posMap.at<float>(_indices[i], 0) / (_dists[i] + 1e-20);
        result.y += _posMap.at<float>(_indices[i], 1) / (_dists[i] + 1e-20);
        distSum += 1 / (_dists[i] + 1e-20);
    }
    result.x /= (distSum + 1e-20);
    result.y /= (distSum + 1e-20);
    
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = _featVec[i];
    }
    
    if (_bStart) {
        if (ABS(result.x - _prePoint.x) > jump || ABS(result.y - _prePoint.y) > jump) {
            if (_jumpDate == nil) {
                _jumpDate = now;
            }
        } else {
            _jumpDate = nil;
        }
        if (result.x - _prePoint.x > jump) {
            result.x = _prePoint.x + jump;
        } else if (result.x - _prePoint.x < -jump) {
            result.x = _prePoint.x - jump;
        }
        
        if (result.y - _prePoint.y > jump) {
            result.y = _prePoint.y + jump;
        } else if (result.y - _prePoint.y < -jump) {
            result.y = _prePoint.y - jump;
        }
        
        result.x = result.x * smooth + _prePoint.x * (1 - smooth);
        result.y = result.y * smooth + _prePoint.y * (1 - smooth);
        
        _prePoint.x = result.x;
        _prePoint.y = result.y;
    } else {
        _prePoint.x = result.x;
        _prePoint.y = result.y;
        _jumpDate = nil;
    }
    _prePoint.knndist = result.knndist;
    
    _bStart = true;
    result.x *= 3;
    result.y *= 3;
    _result = result;
}

- (int)getDataNumOfFeatureFile:(const char *)path {
    FILE *fp = fopen(path, "r");
    char line[1024];
    int lineCnt = 0;
    while (fgets(line, 1024, fp) != NULL) {
        lineCnt++;
    }
    fclose(fp);
    return lineCnt - 1;
}

- (int)getDataNumOfDataString:(const char *)dataStr {
    int count = 0;
    const char* p = dataStr;
    while (*p != '\0') {
        p = strchr(p, '\n');
        p++;
        count++;
    }
    return count - 1;
}

- (int)shiftOverNextChar:(char)c count:(int)n inString:(const char*)str {
    int s = 0;
    for (int i = 0; i < n; i++) {
        while (str[s] != c) {
            s++;
        }
        s++;
    }
    return s;
}

- (double)computeDistanceScoreWithOptions:(NSDictionary *)options
{
    if (_result) {
        return _result.knndist;
    }
    return 100;
}

@end
