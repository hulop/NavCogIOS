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

#import <MultipeerConnectivity/MultipeerConnectivity.h>

#define ReceiveHandlerType void (^)(NSObject*,NSString*)

@protocol P2PManagerDelegate <NSObject>
- (void) updated;
@end

@interface P2PManager : NSObject<MCSessionDelegate, MCNearbyServiceAdvertiserDelegate,MCNearbyServiceBrowserDelegate>

@property NSString *serviceType;
@property NSObject<P2PManagerDelegate> *delegate;
@property MCPeerID *mPeerID;
@property MCSession* mSession;
@property MCNearbyServiceAdvertiser *nearbyAdvertiser;
@property MCNearbyServiceBrowser *nearbyBrowser;
@property NSMutableArray *callbacks;
@property NSMutableArray *found;
@property NSMutableArray *inviting;

@property NSMutableArray *handlers;
@property NSMutableDictionary *filePaths;
@property NSMutableDictionary *jsons;


+ (P2PManager*) sharedInstance;
- (void) startAdvertise;
- (void) stopAdvertise;
- (void) send: (NSObject*) content withType: (NSString*) type;
- (void) addReceiveHandler: (ReceiveHandlerType) handler;
- (void) addFilePath:(NSString*)path withKey:(NSString*)key;
- (void) addJSON:(NSObject*)json withKey:(NSString*)key;

- (void) startBrowse;
- (void) stopBrowse;
- (void) invite;

@end