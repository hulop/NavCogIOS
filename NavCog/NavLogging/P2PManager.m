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

#import <Foundation/Foundation.h>
#import "P2PManager.h"
//#import "NavUtil.h"

@interface P2PManager ()

@end

@implementation P2PManager

//static NSString *serviceType = @"navcog-monitor";
static P2PManager* sharedP2PManager = nil;

+ (P2PManager*) sharedInstance{
    if(!sharedP2PManager){
        sharedP2PManager = [[P2PManager alloc] init];
        sharedP2PManager.serviceType = @"p2p-manager";
        NSLog(@"P2PManager is instantiated");
    }
    return sharedP2PManager;
}

- (id) init{
    self = [super init];
    
    NSString *systemName = [[UIDevice currentDevice] systemName];
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    self.mPeerID = [[MCPeerID alloc] initWithDisplayName: [NSString stringWithFormat:@"%@-%@", systemName, uuid]];
    self.mSession = [[MCSession alloc] initWithPeer: self.mPeerID];
    self.mSession.delegate = self;
    NSLog(@"%@", self.mPeerID);
    return self;
}

- (void) startBrowse {
    if (!self.nearbyBrowser) {
        self.nearbyBrowser = [[MCNearbyServiceBrowser alloc]
                              initWithPeer:self.mPeerID
                              serviceType:self.serviceType];
        self.nearbyBrowser.delegate = self;
    }
    [self.nearbyBrowser startBrowsingForPeers];
}

- (void) stopBrowse {
    [self.nearbyBrowser stopBrowsingForPeers];
}


- (void) startAdvertise {
    if (!self.nearbyAdvertiser) {
        self.nearbyAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.mPeerID discoveryInfo:nil serviceType:self.serviceType];
        self.nearbyAdvertiser.delegate = self;
    }
    
    [self.nearbyAdvertiser startAdvertisingPeer];
}

- (void) stopAdvertise{
    [self.nearbyAdvertiser stopAdvertisingPeer];
}

- (void)addFilePath:(NSString *)path withKey:(NSString *)key
{
    if (self.filePaths == nil) {
        self.filePaths = [@{} mutableCopy];
    }
    self.filePaths[key] = path;
}

- (void)addJSON:(NSObject *)json withKey:(NSString *)key
{
    if (self.jsons == nil) {
        self.jsons = [@{} mutableCopy];
    }
    self.jsons[key] = json;
}

- (void)addReceiveHandler:(void (^)(NSObject *, NSString *))handler
{
    if (self.handlers == nil) {
        self.handlers = [@[] mutableCopy];
    }
    [self.handlers addObject:handler];
}


-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"didFinishReceivingResourceWithName");
}

-(void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler
{
    NSLog(@"didReceiveCertificate");
    certificateHandler(YES);
}

- (void) send: (NSDictionary*) content withType: (NSString*) type{
    NSDictionary *dic = @{@"type":type, @"content":content};
    //NSData *jdata = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSError *error = nil;
    NSArray *peerIDs = self.mSession.connectedPeers;
    
    if(! [self isActive]){
        return;
    }
    
    NSData *jdata = [NSKeyedArchiver archivedDataWithRootObject:dic];
    //jdata = [NavUtil compressByGzip:jdata];
    
    //NSLog(@"send %@ data %ld bytes", type, (unsigned long)[jdata length]);
    
    [self.mSession sendData:jdata
                    toPeers:peerIDs
                   withMode:MCSessionSendDataReliable
                      error:&error];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    //data = [NavUtil uncompressByGzip:data];
    //NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *dic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    NSObject *content = dic[@"content"];
    NSString *type = dic[@"type"];
    //NSLog(@"receive %@ data %ld bytes", type, (unsigned long)[data length]);
    
    if ([type isEqualToString:@"getfile"]) {
        if (self.filePaths[content]) {
            NSData *file = [NSData dataWithContentsOfFile:self.filePaths[content]];
            NSDictionary *data = @{@"content":file,@"key":content};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self send:data withType:@"putfile"];
            });
        }
    } else if ([type isEqualToString:@"getjson"]) {
        if (self.jsons[content]) {
            NSDictionary *data = @{@"content":self.jsons[content],@"key":content};
            dispatch_async(dispatch_get_main_queue(), ^{
                [self send:data withType:@"putjson"];
            });
        }
    } else {
        for(void (^handler)(NSObject*,NSString*) in self.handlers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(content, type);
            });
        }
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"didChangeState %ld", (long)state);
    [self.delegate updated];
    if (state != MCSessionStateConnecting) {
        [self.inviting removeObject:peerID];
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"didNotStartAdvertisingPeer");
}

-(void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nonnull))invitationHandler
{
    NSLog(@"didReceiveInvitationFromPeer from %@", peerID);
    invitationHandler(YES,self.mSession);
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info
{
    NSLog(@"foundPeer %@", peerID);
    if (!self.found) {self.found = [@[] mutableCopy];}
    if (!self.inviting) {self.inviting = [@[] mutableCopy];}
    if (![self.found containsObject:peerID]) {
        [self.found addObject:peerID];
    }
    [self invite];
    [self.delegate updated];
}

- (void) invite {
    for(MCPeerID *peerID in self.found) {
        if (![self.inviting containsObject:peerID]) {
            NSLog(@"invite %@", peerID);
            [self.nearbyBrowser invitePeer:peerID toSession:self.mSession withContext:nil timeout:30];
            [self.inviting addObject:peerID];
        }
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer %@", peerID);
    [self.delegate updated];
    [self.found removeObject:peerID];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"didNotStartBrowsingForPeers");
}

- (bool) isActive{
    NSArray *peerIDs = self.mSession.connectedPeers;
    if(peerIDs==nil || peerIDs.count==0){
        return false;
    }else{
        return true;
    }
}

@end

