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
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "NavCogSettingViewController.h"
#import "HULOPSettingHelper.h"
#import "HULOPSetting.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@interface NavCogSettingViewController ()

@property HULOPSettingHelper *helper;

@end

@implementation NavCogSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;

    _helper = [[HULOPSettingHelper alloc] init];
    
    [_helper addSectionTitle:NSLocalizedString(@"Navigation", @"label for setting view navigation section")];    
    [_helper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"PlaySurroundInfoAutomatically", @"label for play surround info automatically setting") Name:@"playSurroundInfoAutomatically" DefaultValue:@(FALSE) Accept:nil];

    
    
    self.tableView.delegate = _helper;
    self.tableView.dataSource = _helper;
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)backToNavUIView:(id)sender {
    [self.view removeFromSuperview];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
