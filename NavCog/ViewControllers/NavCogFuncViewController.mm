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

#import "NavCogFuncViewController.h"
#import "NavLocalizerFactory.h"
#import "TwoDLocalizer.h"

@interface NavCogFuncViewController ()

@property (strong, nonatomic) UIView *blankView;
@property (strong, nonatomic) UIWebView *webView;

@end

@implementation NavCogFuncViewController

+ (instancetype)sharedNavCogFuntionViewController {
    static NavCogFuncViewController *ctrl = nil;
    if (ctrl == nil) {
        ctrl = [[NavCogFuncViewController alloc] init];
    }
    return ctrl;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = [[UIScreen mainScreen] bounds];
    self.view.bounds = [[UIScreen mainScreen] bounds];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupUI];
    [self setupCurrentLocationObserver];
}

- (void)setupUI {
    // google map web view
    _webView = [[UIWebView alloc] init];
    _webView.frame = [[UIScreen mainScreen] bounds];
    _webView.bounds = [[UIScreen mainScreen] bounds];
    NSURL *pageURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"NavCogMapView" ofType:@"html" inDirectory:@"NavCogMapView"]];
    _webView.delegate = self;
    [self.view addSubview:_webView];
    [_webView loadRequest:[[NSURLRequest alloc] initWithURL:pageURL]];
    
    // blank view to block touch from google map
    _blankView = [[UIView alloc] init];
    _blankView.frame = [[UIScreen mainScreen] bounds];
    _blankView.bounds = [[UIScreen mainScreen] bounds];
    _blankView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_blankView];
    
    // buttons
    float sw = [[UIScreen mainScreen] bounds].size.width;
    float sh = [[UIScreen mainScreen] bounds].size.height;
    float bw = sw / 3;
    float bh = sh / 3;
    
    // previous instruction button
    UIButton *preButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [preButton addTarget:self action:@selector(playPreviousInstruction) forControlEvents:UIControlEventTouchUpInside];
    preButton.frame = CGRectMake(0, 0, bw, bh);
    preButton.bounds = CGRectMake(0, 0, bw, bh);
    preButton.layer.cornerRadius = 3;
    preButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    preButton.layer.borderWidth = 2.0;
    preButton.layer.borderColor = [UIColor blackColor].CGColor;
    preButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    preButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [preButton setTitle:NSLocalizedString(@"previousInstructionButton", @"HTML Label for previous instruction button in view")forState:UIControlStateNormal];
    [preButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [preButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    preButton.tag = BUTTON_PRE;
    [preButton setAccessibilityTraits:UIAccessibilityTraitNone];
    [self.view addSubview:preButton];
    
    // accessibility instruction button
    UIButton *accessButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [accessButton addTarget:self action:@selector(playAccessibilityInstruction) forControlEvents:UIControlEventTouchUpInside];
    accessButton.frame = CGRectMake(sw - bw, 0, bw, bh);
    accessButton.bounds = CGRectMake(0, 0, bw, bh);
    accessButton.layer.cornerRadius = 3;
    accessButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    accessButton.layer.borderWidth = 2.0;
    accessButton.layer.borderColor = [UIColor blackColor].CGColor;
    accessButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    accessButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [accessButton setTitle:NSLocalizedString(@"accessibilityInstructionButton", @"HTML Label for accessibility instruction button in view") forState:UIControlStateNormal];
    [accessButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [accessButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    accessButton.tag = BUTTON_ACCESS;
    [accessButton setAccessibilityTraits:UIAccessibilityTraitNone];
    [self.view addSubview:accessButton];
    
    // surrounding information button
    UIButton *surroundButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [surroundButton addTarget:self action:@selector(playSurroundingInformation) forControlEvents:UIControlEventTouchUpInside];
    surroundButton.frame = CGRectMake(0, sh - bh, bw, bh);
    surroundButton.bounds = CGRectMake(0, 0, bw, bh);
    surroundButton.layer.cornerRadius = 3;
    surroundButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    surroundButton.layer.borderWidth = 2.0;
    surroundButton.layer.borderColor = [UIColor blackColor].CGColor;
    surroundButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    surroundButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [surroundButton setTitle:NSLocalizedString(@"surroundingInformationButton", @"HTML Label for surrounding information button in view") forState:UIControlStateNormal];
    [surroundButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [surroundButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    surroundButton.tag = BUTTON_SURROUND;
    [surroundButton setAccessibilityTraits:UIAccessibilityTraitNone];
    [self.view addSubview:surroundButton];
    
    // stop navigation button
    UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [stopButton addTarget:self action:@selector(stopNavigation) forControlEvents:UIControlEventTouchUpInside];
    stopButton.frame = CGRectMake(sw -bw, sh - bh, bw, bh);
    stopButton.bounds = CGRectMake(0, 0, bw, bh);
    stopButton.layer.cornerRadius = 3;
    stopButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    stopButton.layer.borderWidth = 2.0;
    stopButton.layer.borderColor = [UIColor blackColor].CGColor;
    stopButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    stopButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [stopButton setTitle:NSLocalizedString(@"stopNavigationButton", @"HTML Label for stop navigation button in view") forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [self.view addSubview:stopButton];
}

- (void)setupCurrentLocationObserver {

    // cole
    [[[self.delegate getNavMachine] getCurrentLocationManager] addObserver:self forKeyPath:@"debugCurrentLocation" options:NSKeyValueObservingOptionNew context:nil];
    // itoh
    //[[[self.delegate getNavMachine] getCurrentLocationManager] addObserver:self forKeyPath:@"debugCurrentLocation2" options:NSKeyValueObservingOptionNew context:nil];
//    [[NSNotificationCenter defaultCenter]
//        addObserver:self
//        selector:@selector(updateRedDotWithLocation:)
//        name:@CURRENT_LOCATION_NOTIFICATION_NAME
//        object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"debugCurrentLocation"]) {
        [self updateRedDotWithLocation:change[@"new"]];
    }
    if ([keyPath isEqualToString:@"debugCurrentLocation2"]) {
        [self updateRedDotWithLocation:change[@"new"]];
    }
}

- (void)runCmdWithString:(NSString *)str {
    printf("%ld\n", [str length]);
    [_webView stringByEvaluatingJavaScriptFromString:str];
}
- (void)updateRedDotWithNotification:(NSNotification *)notification {
    [self updateRedDotWithLocation: notification.userInfo[@"location"]];
}
- (void)updateRedDotWithLocation:(NavLocation *)location {
    if (true) return; // TODO: remove this after current position fixed
    if (![NavLog isLogging]) {
        return;
    }
    //NavLocation *location = notification.userInfo[@"location"];
    if (location.edgeID == nil) {
        [self runCmdWithString:@"updateRedDot(null)"];
    } else {
        NavEdge *edge = [location getEdge];
        NavNode *node1 = edge.node1, *node2 = edge.node2;
        //NSDictionary* info1 = [node1.infoFromEdges objectForKey:edge.edgeID];
        //NSDictionary* info2 = [node2.infoFromEdges objectForKey:edge.edgeID];
        float cy = location.yInEdge;
        float cx = location.xInEdge;
        float slat = node1.lat;
        float slng = node1.lng;
        float tlat = node2.lat;
        float tlng = node2.lng;
        
        float sx = [node1 getXInEdgeWithID:edge.edgeID];
        float sy = [node1 getYInEdgeWithID:edge.edgeID];
        float tx = [node2 getXInEdgeWithID:edge.edgeID];
        float ty = [node2 getYInEdgeWithID:edge.edgeID];
        
//        float sy = ((NSNumber *)[info1 objectForKey:@"y"]).floatValue;
//        float ty = ((NSNumber *)[info2 objectForKey:@"y"]).floatValue;
//        float sx = ((NSNumber *)[info1 objectForKey:@"x"]).floatValue;
//        float tx = ((NSNumber *)[info2 objectForKey:@"x"]).floatValue;

        
        float distStartTarget = sqrtf(powf(tx-sx,2)+powf(ty-sy, 2));
        float distStartCurrent = sqrtf(powf(cx-sx,2)+powf(cy-sy,2));
        //float ratio = (cy - _sy) / (_ty - _sy); //1D
        float ratio = distStartCurrent/distStartTarget; //2D

        //float ratio = (cy - sy) / (ty - sy);
        float lat = slat + ratio * (tlat - slat);
        float lng = slng + ratio * (tlng - slng);
        NSString *cmd = [NSString stringWithFormat:@"updateRedDot({lat:%f, lng:%f})", lat, lng];
        [self runCmdWithString:cmd];
    }
}

// web view delegate methods
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_delegate webViewLoaded];
}

- (void)playPreviousInstruction {
    [_delegate didTriggerPreviousInstruction];
}

- (void)playAccessibilityInstruction {
    [_delegate didTriggerAccessInstruction];
}

- (void)playSurroundingInformation {
    [_delegate didTriggerSurroundInstruction];
}

- (void)stopNavigation {
    [_delegate didTriggerStopNavigation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)setHintText:(NSString *)str withTag:(NSInteger)tag {
    UIButton *button = [self.view viewWithTag:tag];
    if (button != nil) {
        [button setAccessibilityHint:str];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, [self.view viewWithTag:BUTTON_PRE]);
}


@end
