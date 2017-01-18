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

#import "NavCogDataSamplingViewController.h"


@interface NavCogDataSamplingViewController ()

@property (weak, nonatomic) IBOutlet UITextField *xTextField;
@property (weak, nonatomic) IBOutlet UISwitch *xAutoLock;

@property (weak, nonatomic) IBOutlet UISegmentedControl *xAutoModeSeg;


@property (weak, nonatomic) IBOutlet UILabel *countDownLabel;


@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (nonatomic) enum AutoMode xAutoMode;

@property (strong, nonatomic) NSArray *pickerStrs;

@property (nonatomic) int currentSmpNum;

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSUUID *uuid;

// writing data to files
@property (strong, nonatomic) NSFileHandle *dataFile;
@property (strong, nonatomic) NSMutableString *dataFileName;
@property (strong, nonatomic) NSString *dataFilePath;
@property (nonatomic) Boolean isSampling;
@property (nonatomic) Boolean isRangingBeacon;

@end

@implementation NavCogDataSamplingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    _xTextField.text = [NSString stringWithFormat:@"%.1f", _xStepper.value];
    _yTextField.text = [NSString stringWithFormat:@"%.1f", _yStepper.value];
    _xAutoLock.on = false;
    _yAutoLock.on = false;
    _xAutoModeSeg.enabled = false;
    _yAutoModeSeg.enabled = false;
    _pickerStrs = @[@"1", @"5",@"10",@"15",@"20",@"25",@"30",@"35",@"40",@"45",@"50",@"55",@"60"];
    _currentSmpNum = 0;
    _targetSmpNum = 30;
    _sampleNumPicker.dataSource = self;
    _sampleNumPicker.delegate = self;
    _sampleNumPicker.userInteractionEnabled = false;
    [_sampleNumPicker selectRow:6 inComponent:0 animated:false];
    _stopButton.enabled = false;
    _beaconFilterString = _beaconFilterTextView.text;
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

- (IBAction)xStepperValueChanged:(UIStepper *)sender {
    _xTextField.text = [NSString stringWithFormat:@"%.1f", _xStepper.value];
}

- (IBAction)yStepperValueChanged:(UIStepper *)sender {
    _yTextField.text = [NSString stringWithFormat:@"%.1f", _yStepper.value];
}

- (IBAction)stopButtonClicked:(UIButton *)sender {
    _isSampling = false;
    [_dataFile closeFile];
    _startButton.enabled = true;
    _stopButton.enabled = false;
    _currentSmpNum = 0;
}

- (IBAction)startButtonClicked:(UIButton *)sender {
    if (!_isRangingBeacon) {
        NSString* uuid_string = [NSString stringWithString:_uuidTextField.text];
        NSString* major_string = [NSString stringWithString:_majorIDTextField.text];
        _uuid = [[NSUUID alloc] initWithUUIDString:uuid_string];
        _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:_uuid major:(major_string.intValue) identifier:@"cmaccess"];
        [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
        _isRangingBeacon = true;
    }
    _stopButton.enabled = true;
    _startButton.enabled = false;
    
    _xStepper.value = _xTextField.text.floatValue;
    _yStepper.value = _yTextField.text.floatValue;
    
    _targetSmpNum = ((NSString *)([_pickerStrs objectAtIndex:[_sampleNumPicker selectedRowInComponent:0]])).intValue;
    _countDownLabel.text = [NSString stringWithFormat:@"%d", _targetSmpNum];
    if (![_beaconFilterString isEqualToString:_beaconFilterTextView.text]) {
        _beaconFilterString = _beaconFilterTextView.text;
        _beaconMinors = [self analysisBeaconFilter:_beaconFilterString];
    }
    
    _dataFileName = [[NSMutableString alloc] init];
    [_dataFileName appendString:@"/edge_"];
    [_dataFileName appendString:_edgeIDTextField.text];
    [_dataFileName appendFormat:@"_%.1f_%.1f.txt", _xTextField.text.floatValue, _yTextField.text.floatValue];
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    _dataFilePath = [documentPath stringByAppendingString:_dataFileName];
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
        [strLine appendString:_xTextField.text];
        [strLine appendString:@","];
        [strLine appendString:_yTextField.text];
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
        _countDownLabel.text = [NSString stringWithFormat:@"%d", _targetSmpNum - _currentSmpNum];
        if (_currentSmpNum == _targetSmpNum) {
            _isSampling = false;
            [_dataFile closeFile];
            _startButton.enabled = true;
            _stopButton.enabled = false;
            _currentSmpNum = 0;
            if (_xAutoMode == AutoInc) {
                _xStepper.value = _xTextField.text.floatValue + 1;
                _xTextField.text = [NSString stringWithFormat:@"%.1f", _xStepper.value];
            } else if (_xAutoMode == AutoDec) {
                _xStepper.value = _xTextField.text.floatValue - 1;
                _xTextField.text = [NSString stringWithFormat:@"%.1f", _xStepper.value];
            }
            
            if (_yAutoMode == AutoInc) {
                _yStepper.value = _yTextField.text.floatValue + 1;
                _yTextField.text = [NSString stringWithFormat:@"%.1f", _yStepper.value];
            } else if (_yAutoMode == AutoDec){
                _yStepper.value = _yTextField.text.floatValue - 1;
                _yTextField.text = [NSString stringWithFormat:@"%.1f", _yStepper.value];
            }
            
            if (_sendData ==YES) {
                NSString *filename = _dataFileName;
                NSString *fname = @"fingerprint";
                NSString *mimetype = @"text/plain";
                NSData *data = [[NSData alloc] initWithContentsOfFile:_dataFilePath];
                
                NSString *urlString = @"http://hulop.qolt.cs.cmu.edu/fprint/index.php";
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
            
        }
    }
}

- (IBAction)sampleNumLockChanged:(UISwitch *)sender {
    if (_sampleNumLock.on) {
        _sampleNumPicker.userInteractionEnabled = false;
    } else {
        _sampleNumPicker.userInteractionEnabled = true;
    }
}

- (IBAction)xAutoModeChanged:(UISegmentedControl *)sender {
    if (_xAutoModeSeg.selectedSegmentIndex == 0) {
        _xAutoMode = AutoDec;
    } else {
        _xAutoMode = AutoInc;
    }
}

- (IBAction)yAutoModeChanged:(UISegmentedControl *)sender {
    if (_yAutoModeSeg.selectedSegmentIndex == 0) {
        _yAutoMode = AutoDec;
    } else {
        _yAutoMode = AutoInc;
    }
}

- (IBAction)xAutoLockChanged:(UISwitch *)sender {
    if (_xAutoLock.on) {
        _xTextField.enabled = false;
        _xStepper.enabled = false;
        _xAutoModeSeg.enabled = true;
        if (_xAutoModeSeg.selectedSegmentIndex == 0) {
            _xAutoMode = AutoDec;
        } else {
            _xAutoMode = AutoInc;
        }
    } else {
        _xTextField.enabled = true;
        _xStepper.enabled = true;
        _xAutoModeSeg.enabled = false;
        _xAutoMode = None;
    }
}
- (IBAction)yAutoLockChanged:(UISwitch *)sender {
    if (_yAutoLock.on) {
        _yTextField.enabled = false;
        _yStepper.enabled = false;
        _yAutoModeSeg.enabled = true;
        if (_yAutoModeSeg.selectedSegmentIndex == 0) {
            _yAutoMode = AutoDec;
        } else {
            _yAutoMode = AutoInc;
        }
    } else {
        _yTextField.enabled = true;
        _yStepper.enabled = true;
        _yAutoModeSeg.enabled = false;
        _yAutoMode = None;
    }
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

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 12;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [_pickerStrs objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    _targetSmpNum = ((NSString *)([_pickerStrs objectAtIndex:row])).intValue;
}

- (IBAction)hideKeyboard:(id)sender {
    [_xTextField resignFirstResponder];
    [_yTextField resignFirstResponder];
    [_beaconFilterTextView resignFirstResponder];
    [_edgeIDTextField resignFirstResponder];
    [_uuidTextField resignFirstResponder];
    [_majorIDTextField resignFirstResponder];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)closeDataSamplingView:(id)sender {
    [self.view removeFromSuperview];
}
@end
