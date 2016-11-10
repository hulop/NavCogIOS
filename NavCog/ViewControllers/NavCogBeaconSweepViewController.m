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

#import "NavCogBeaconSweepViewController.h"


@interface NavCogBeaconSweepViewController ()

@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSUUID *uuid;

@property (strong, nonatomic) NSMutableSet *beaconMinors_found;

@property (nonatomic) Boolean isRangingBeacon;

@end

@implementation NavCogBeaconSweepViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    
    _beaconMinors_found = [[NSMutableSet alloc] init];

    [_statusLabel setText:@"Status: Not scanning"];
    [_startButton setTitle:@"Start scanning" forState:UIControlStateNormal];

    _beaconManager = [[CLLocationManager alloc] init];
    if([_beaconManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [_beaconManager requestAlwaysAuthorization];
    }
    _beaconManager.delegate = self;
    _beaconManager.pausesLocationUpdatesAutomatically = NO;
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
        
        [_statusLabel setText:@"Status: Scanning"];
        [_startButton setTitle:@"Stop scanning" forState:UIControlStateNormal];
    } else {
        [self sendData];
        [_statusLabel setText:@"Status: Not scanning"];
        [_startButton setTitle:@"Start scanning" forState:UIControlStateNormal];
        [self.view removeFromSuperview];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"fb-messenger://user-thread/720072294762496"]];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if (!_isRangingBeacon) {
        return;
    }

    if (beacons.count > 0) {
        for (CLBeacon *beacon in beacons) {
            NSString *minorID = [NSString stringWithFormat:@"%d", [beacon.minor intValue]];
            if ([_beaconMinors containsObject:minorID]) {
                [_beaconMinors removeObject:minorID];
                [_beaconMinors_found addObject:minorID];
            }
        }
    }
}

- (void) sendData {
    NSString *urlString = @"http://hulop.qolt.cs.cmu.edu/sweep/index.php";
    NSMutableURLRequest *request= [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    NSMutableString *postString = [[NSMutableString alloc] init];

    [postString appendString:@"missing="];
    [postString appendString:[[_beaconMinors allObjects] componentsJoinedByString:@","]];
    [postString appendString:@"&present="];
    [postString appendString:[[_beaconMinors_found allObjects] componentsJoinedByString:@","]];

    NSData *postdata = [postString dataUsingEncoding:NSUTF8StringEncoding];

    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"%lu", [postdata length]] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody:postdata];

    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    NSLog(@"%@", returnString);
}

- (NSMutableSet *)analysisBeaconFilter:(NSString *)str {
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
@end
