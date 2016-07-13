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

#import <UIKit/UIKit.h>
#import "NavMachine.h"
#import "TopoMap.h"
#import "NavCurrentLocationManager.h"

typedef NS_ENUM(NSUInteger, ButtonTags) {
    BUTTON_DUMMY = 100,
    BUTTON_PRE,
    BUTTON_ACCESS,
    BUTTON_SURROUND
};

@class NavMachine;

@protocol NavCogFuncViewControllerDelegate;

@interface NavCogFuncViewController : UIViewController <UIWebViewDelegate>

+ (instancetype)sharedNavCogFuntionViewController;

@property (strong, nonatomic) id <NavCogFuncViewControllerDelegate> delegate;

//@property double orientationDiff;

- (void)runCmdWithString:(NSString *)str;
- (void)setHintText:(NSString *)str withTag:(NSInteger)tag;

@end

@protocol NavCogFuncViewControllerDelegate <NSObject>

- (NavMachine*) getNavMachine;
- (void)didTriggerStopNavigation;
- (void)didTriggerPreviousInstruction;
- (void)didTriggerAccessInstruction;
- (void)didTriggerSurroundInstruction;
- (void)webViewLoaded;

@end
