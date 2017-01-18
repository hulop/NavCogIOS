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
#import "TopoMap.h"
#import "NavMachine.h"
#import "NavCogFuncViewController.h"
#import "NavCogChooseMapViewController.h"
#import "NavCogChooseLogViewController.h"
#import "NavCogDataSamplingViewController.h"
#import "NavCogSimplifiedDataSamplingViewController.h"
#import "NavCogHelpPageViewController.h"
#import "NavDownloadingViewController.h"
#import "NavCogSettingViewController.h"
#import "NavCogBeaconSweepViewController.h"
#import "NavCogBeaconCheckViewController.h"
#import "NavCogDataTesterViewController.h"

enum UIType {SpeechForAll, SpeechForStartAndTurnSoundForDistance, SpeechForAllAndSoundForDistance, SpeechForStartSoundForDistanceAndTurn};

@interface NavCogMainViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, NavMachineDelegate, NavCogFuncViewControllerDelegate, NavCogChooseMapViewControllerDelegate, NavCogChooseLogViewControllerDelegate>

@property (nonatomic) enum {datasampler, beaconchecker, beaconsweep, datatester, defaultscreen} fromURL;
@property (strong, nonatomic) NavCogSimplifiedDataSamplingViewController *simplifiedDataSamplingViewCtrl;
@property (strong, nonatomic) NavCogBeaconSweepViewController *beaconSweepViewCtrl;
@property (strong, nonatomic) NavCogBeaconCheckViewController *beaconCheckViewCtrl;
@property (strong, nonatomic) NavCogDataTesterViewController *dataTesterViewCtrl;

- (void)switchToDataSamplingUIFromLink;


@end
