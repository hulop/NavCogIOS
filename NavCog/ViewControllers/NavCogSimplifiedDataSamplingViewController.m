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

#import "NavCogSimplifiedDataSamplingViewController.h"


@interface NavCogSimplifiedDataSamplingViewController ()

@property (nonatomic) int currentSmpNum;

@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSUUID *uuid;

@property (nonatomic) float xvalue;
@property (nonatomic) float yvalue;

enum AutoMode {None, AutoInc, AutoDec};

// writing data to files
@property (strong, nonatomic) NSFileHandle *dataFile;
@property (strong, nonatomic) NSMutableString *dataFileName;
@property (strong, nonatomic) NSMutableString *dataFilePath;
@property (nonatomic) Boolean isSampling;
@property (nonatomic) Boolean isRangingBeacon;

@end

@implementation NavCogSimplifiedDataSamplingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    _stopButton.enabled = false;
    
    _xvalue = 0.0;
    _yvalue = 0.0;

    _beaconManager = [[CLLocationManager alloc] init];
    if([_beaconManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [_beaconManager requestAlwaysAuthorization];
    }
    _beaconManager.delegate = self;
    _beaconManager.pausesLocationUpdatesAutomatically = NO;
    _isSampling = false;
    _isRangingBeacon = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_isRangingBeacon) {
        [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
        _isRangingBeacon = false;
    }
}

- (IBAction)startButtonClicked:(UIButton *)sender {
    if (!_isRangingBeacon) {
        _uuid = [[NSUUID alloc] initWithUUIDString:_uuid_string];
        _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:_uuid major:(_major_string.intValue) identifier:@"cmaccess"];
        [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
        _isRangingBeacon = true;
    }
    _stopButton.enabled = true;
    _startButton.enabled = false;
    
    _dataFileName = [[NSMutableString alloc] init];
    [_dataFileName appendString:@"edge_"];
    [_dataFileName appendString:_edgeid_string];
    [_dataFileName appendFormat:@"_%.1f_%.1f.txt", _xvalue, _yvalue];
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _dataFilePath = [[NSMutableString alloc] init];
    [_dataFilePath appendString: documentPath];
    [_dataFilePath appendString:@"/"];
    [_dataFilePath appendString: _dataFileName];

    [[NSFileManager defaultManager] createFileAtPath:_dataFilePath contents:nil attributes:nil];
    _dataFile = [NSFileHandle fileHandleForWritingAtPath:_dataFilePath];
    NSMutableString *strLine = [[NSMutableString alloc] init];
    [strLine appendFormat:@"MinorID of %zd Beacon Used : ", _beaconMinors.count];
    int *beaconMinorIDs = malloc(sizeof(int) * _beaconMinors.count);
    int i = 0;
    for (NSString *str in _beaconMinors) {
        beaconMinorIDs[i] = str.intValue;
        i++;
    }
    qsort_b(beaconMinorIDs, i, sizeof(int), ^int(const void *p1, const void *p2) {
        const int *x1 = p1;
        const int *x2 = p2;
        
        if (*x1 > *x2) {
            return 1;
        } else {
            return -1;
        }
    });
    
    for (int j = 0; j < _beaconMinors.count; j++) {
        [strLine appendFormat:@"%d,", beaconMinorIDs[j]];
    }
    [strLine appendString:@"\n"];
    [_dataFile writeData:[strLine dataUsingEncoding:NSUTF8StringEncoding]];
    _isSampling = true;
    
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if (!_isSampling) {
        return;
    }
    
    if (_currentSmpNum >= _targetSmpNum) {
        return;
    }
    
    int validBeaconCount = 0;
    if (beacons.count > 0) {
        for (CLBeacon *beacon in beacons) {
            NSString *minorID = [NSString stringWithFormat:@"%d", [beacon.minor intValue]];
            if ([_beaconMinors containsObject:minorID]) {
                validBeaconCount++;
            }
        }
    }
    if (validBeaconCount > 0) {
        NSMutableString *strLine = [[NSMutableString alloc] init];
        [strLine appendString: [NSString stringWithFormat:@"%f", _xvalue]];
        [strLine appendString:@","];
        [strLine appendString: [NSString stringWithFormat:@"%f", _yvalue]];
        [strLine appendString:@","];
        [strLine appendFormat:@"%d,", validBeaconCount];
        for (CLBeacon *beacon in beacons) {
            NSString *minorID = [NSString stringWithFormat:@"%d", [beacon.minor intValue]];
            if ([_beaconMinors containsObject:minorID]) {
                NSString *majorID = [NSString stringWithFormat:@"%d", [beacon.major intValue]];
                [strLine appendString:majorID];
                [strLine appendString:@","];
                [strLine appendString:minorID];
                [strLine appendString:@","];
                int rssi = (int)beacon.rssi;
                if (rssi == 0) {
                    rssi = -100;
                }
                [strLine appendFormat:@"%d", rssi];
                [strLine appendString:@","];
            }
        }
        [strLine appendString:@"\n"];
        [_dataFile writeData:[strLine dataUsingEncoding:NSUTF8StringEncoding]];
        
        _currentSmpNum++;
        if (_currentSmpNum == _targetSmpNum) {
            _isSampling = false;
            [_dataFile closeFile];
            
            if(_send)
                [self sendData];

            _startButton.enabled = true;
            _stopButton.enabled = false;
            _currentSmpNum = 0;
            
            if (_yMode == true)
                _yvalue++;
            else if (_yMode == false)
                _yvalue--;
        }
    }
}

- (void) sendData {
    NSMutableString *filename = [[NSMutableString alloc] init];
    [filename appendString:_edgeid_string];
    [filename appendString:@"_"];
    [filename appendString:_wid];
    [filename appendString:@"_"];
    [filename appendString:[NSString stringWithFormat:@"%f", _yvalue]];
    [filename appendString:@"_"];
    [filename appendString:[NSString stringWithFormat:@"%f", _length]];

    NSString *fname = @"fingerprint";
    NSString *mimetype = @"text/plain";
    NSData *data = [[NSData alloc] initWithContentsOfFile:_dataFilePath];
    
    NSString *urlString = @"http://hulop.qolt.cs.cmu.edu/datacheck/index.php";
    NSMutableURLRequest *request= [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"multipart/form-data" forHTTPHeaderField:@"content-type"];
    
    NSString *boundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *postdata = [NSMutableData data];
    [postdata appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postdata appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fname, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [postdata appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
    [postdata appendData:data];
    [postdata appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postdata appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    [request setHTTPBody:postdata];
    [request setValue:[NSString stringWithFormat:@"%lu", [postdata length]] forHTTPHeaderField:@"Content-Length"];
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    NSLog(@"%@", returnString);
}

- (NSSet *)analysisBeaconFilter:(NSString *)str {
    NSMutableSet *result = [[NSMutableSet alloc] init];
    NSArray *splits = [str componentsSeparatedByString:@","];
    for (NSString *split in splits) {
        if ([split containsString:@"-"]) {
            NSScanner *scanner = [NSScanner scannerWithString:split];
            NSInteger startID;
            NSInteger endID;
            [scanner scanInteger:&startID];
            [scanner scanInteger:&endID];
            int start = (int)startID;
            int end = abs((int)endID);
            for (int i = start; i <= end; i++) {
                [result addObject:[NSString stringWithFormat:@"%d", i]];
            }
        } else {
            NSScanner *scanner = [NSScanner scannerWithString:split];
            NSInteger beaconId;
            [scanner scanInteger:&beaconId];
            [result addObject:[NSString stringWithFormat:@"%zd", beaconId]];
        }
    }
    return result;
}

- (IBAction)closeDataSamplingView:(id)sender {
    [self.view removeFromSuperview];
}
@end
