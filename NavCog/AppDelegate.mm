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

#import "AppDelegate.h"
#import "NavCogMainViewController.h"
#import "P2PManager.h"

@interface AppDelegate ()

@property (strong, nonatomic) NavCogMainViewController *rootView;

@end

@implementation AppDelegate

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    NSLog(@"url recieved: %@", url);
    NSLog(@"query string: %@", [url query]);
    NSLog(@"host: %@", [url host]);
    NSLog(@"url path: %@", [url path]);
    NSDictionary *dict = [self parseQueryString:[url query]];
    NSLog(@"query dict: %@", dict);
    
    if([[url host] isEqualToString:@"datasampler"]) {
        [self runSamplerLightWithData:dict];
    } else if([[url host] isEqualToString:@"beaconchecker"]) {
        [self runTestBeaconWithData:dict];
    } else if([[url host] isEqualToString:@"beaconsweeper"]) {
        [self runScanBeaconsWithData:dict];
    } else if([[url host] isEqualToString:@"datatester"]) {
        [self runDataTesterWithData:dict];
    }

    return YES;
}

-(void)runSamplerLightWithData:(NSDictionary *)dict {
    double yvalue = [dict[@"y"] floatValue];
    
    NSString *wid = dict[@"wid"];
    NSString *send = dict[@"send"];
    NSString *edge_id = dict[@"edge"];
    double length = [dict[@"length"] floatValue];
    NSString *major_id =dict[@"major"];
    int time = [dict[@"time"] intValue];
    NSString *direction = dict[@"dir"];
    NSString *beacon_filter = dict[@"beacons"];
    
    if ([direction isEqualToString:@"0"]){
        _rootView.simplifiedDataSamplingViewCtrl.yMode = true;
    }
    else{
        _rootView.simplifiedDataSamplingViewCtrl.yMode = false;
    }
    
    if ([send isEqualToString:@"0"]){
        _rootView.simplifiedDataSamplingViewCtrl.send = false;
    }
    else{
        _rootView.simplifiedDataSamplingViewCtrl.send = true;
    }
    
    _rootView.simplifiedDataSamplingViewCtrl.wid = wid;
    _rootView.simplifiedDataSamplingViewCtrl.yvalue = yvalue;
    _rootView.simplifiedDataSamplingViewCtrl.length = length;
    _rootView.simplifiedDataSamplingViewCtrl.edgeid_string = edge_id;
    _rootView.simplifiedDataSamplingViewCtrl.major_string = major_id;
    _rootView.simplifiedDataSamplingViewCtrl.targetSmpNum = time;
    
    _rootView.simplifiedDataSamplingViewCtrl.beaconMinors = [_rootView.simplifiedDataSamplingViewCtrl analysisBeaconFilter: beacon_filter];
    
    _rootView.simplifiedDataSamplingViewCtrl.uuid_string = @"F7826DA6-4FA2-4E98-8024-BC5B71E0893E";

    _rootView.fromURL = datasampler;
    [_rootView.view addSubview:_rootView.simplifiedDataSamplingViewCtrl.view];
}

-(void)runTestBeaconWithData:(NSDictionary *)dict {
    NSString *wid = dict[@"wid"];
    NSString *major_id =dict[@"major"];
    NSString *minor_id =dict[@"minor"];
    
    if([_rootView.beaconCheckViewCtrl isViewLoaded]) {
        [_rootView.beaconCheckViewCtrl.view removeFromSuperview];
    }
    
    _rootView.beaconCheckViewCtrl.wid = wid;
    _rootView.beaconCheckViewCtrl.major_string = major_id;
    _rootView.beaconCheckViewCtrl.minor_string = minor_id;
    _rootView.beaconCheckViewCtrl.uuid_string = @"F7826DA6-4FA2-4E98-8024-BC5B71E0893E";

    _rootView.fromURL = beaconchecker;
    [_rootView.view addSubview:_rootView.beaconCheckViewCtrl.view];
    


}

-(void)runDataTesterWithData:(NSDictionary *)dict {
    double yvalue = [dict[@"y"] floatValue];
    NSString *wid = dict[@"wid"];
    NSString *edge_id = dict[@"edge"];
    NSString *major_id =dict[@"major"];
    NSString *beacon_filter = dict[@"beacons"];
    
    _rootView.dataTesterViewCtrl.wid = wid;
    
    _rootView.dataTesterViewCtrl.yvalue = yvalue;
    
    _rootView.dataTesterViewCtrl.edgeid_string = edge_id;
    _rootView.dataTesterViewCtrl.major_string = major_id;
    
    _rootView.dataTesterViewCtrl.beaconMinors = [_rootView.dataTesterViewCtrl analysisBeaconFilter: beacon_filter];
    
    _rootView.dataTesterViewCtrl.uuid_string = @"F7826DA6-4FA2-4E98-8024-BC5B71E0893E";
    
    _rootView.fromURL = datatester;
    [_rootView.view addSubview:_rootView.dataTesterViewCtrl.view];
}

-(void)runScanBeaconsWithData:(NSDictionary *)dict {
    NSString *wid = dict[@"wid"];
    NSString *major_id =dict[@"major"];
    NSString *beacon_filter = dict[@"beacons"];

    _rootView.beaconSweepViewCtrl.wid = wid;
    _rootView.beaconSweepViewCtrl.major_string = major_id;
    _rootView.beaconSweepViewCtrl.uuid_string = @"F7826DA6-4FA2-4E98-8024-BC5B71E0893E";
    _rootView.beaconSweepViewCtrl.beaconMinors = [_rootView.beaconSweepViewCtrl analysisBeaconFilter: beacon_filter];

    _rootView.fromURL = beaconsweep;
    [_rootView.view addSubview:_rootView.beaconSweepViewCtrl.view];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _rootView = [[NavCogMainViewController alloc] init];
    [self.window setRootViewController:_rootView];
    [self.window makeKeyAndVisible];
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    if ([[env valueForKey:@"p2pdebug"] isEqual:@"true"]) {
        [P2PManager sharedInstance]; // instantiate P2P manager
        [P2PManager sharedInstance].serviceType = @"navcog-monitor";
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    if ([[env valueForKey:@"p2pdebug"] isEqual:@"true"]) {
        [[P2PManager sharedInstance] stopAdvertise];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    if ([[env valueForKey:@"p2pdebug"] isEqual:@"true"]) {
        [[P2PManager sharedInstance] startAdvertise];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

void uncaughtExceptionHandler(NSException *exception)
{
    NSLog(@"%@", exception.name);
    NSLog(@"%@", exception.reason);
    NSLog(@"%@", exception.callStackSymbols);
}

@end
