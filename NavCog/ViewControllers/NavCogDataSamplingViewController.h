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
 *******************************************************************************/

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface NavCogDataSamplingViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UIStepper *xStepper;
@property (weak, nonatomic) IBOutlet UIStepper *yStepper;
//where I started adding things from .m

enum AutoMode {None, AutoInc, AutoDec};

@property (weak, nonatomic) IBOutlet UISegmentedControl *yAutoModeSeg;
@property (weak, nonatomic) IBOutlet UISwitch *yAutoLock;
@property (nonatomic) enum AutoMode yAutoMode;
@property (weak, nonatomic) IBOutlet UITextView *beaconFilterTextView;
@property (nonatomic) Boolean sendData;
@property (weak, nonatomic) IBOutlet UITextField *edgeIDTextField;
@property (weak, nonatomic) IBOutlet UITextField *majorIDTextField;
@property (weak, nonatomic) IBOutlet UITextField *uuidTextField;


@property (strong, nonatomic) NSSet *beaconMinors;
@property (strong, nonatomic) NSString *beaconFilterString;

@property (weak, nonatomic) IBOutlet UISwitch *sampleNumLock;
@property (weak, nonatomic) IBOutlet UIPickerView *sampleNumPicker;
@property (nonatomic) int targetSmpNum;

//where I stopped

@property (weak, nonatomic) IBOutlet UITextField *yTextField;


@end
