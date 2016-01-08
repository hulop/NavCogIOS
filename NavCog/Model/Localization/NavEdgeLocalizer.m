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

#import "NavEdgeLocalizer.h"

@interface NavEdgeLocalizer ()

@end


@implementation NavEdgeLocalizer

- (id) initWithLocalizer:(NavLocalizer*)parent withEdgeInfo:(NavLightEdge *)edgeInfo
{
    self = [super init];
    
    _parent = parent;
    _edgeInfo = edgeInfo;
    
    return self;
}

- (NavEdgeLocalizer*) cloneWithEdgeInfo: (NavLightEdge*) edgeInfo
{
    NavEdgeLocalizer *newLocalizer = [[NavEdgeLocalizer alloc] init];
    newLocalizer.parent = self.parent;
    newLocalizer.edgeInfo = edgeInfo;
    return newLocalizer;
}

- (void)initializeState:(NSDictionary*) options
{
    [_parent initializeState:options];
}

- (NavLocalizeResult *)getLocation
{
    NavLocalizeResult *r = [_parent getLocation];
    r.edgeID = _edgeInfo.edgeID;
    
    NSDictionary* emptyOptions = [NSDictionary dictionary];
    r.knndist = [self computeDistanceScoreWithOptions:emptyOptions];
    
    //2D -> 1D convert
    Nav2DPoint *p = [[Nav2DPoint alloc] initWithX:r.x Y:r.y];
    Nav2DPoint *p2 = [_edgeInfo.lineSegment getNearestPointOnLineSegmentFromPoint:p];
    
    NavLocalizeResult *r2 = [[NavLocalizeResult alloc] init];
    r2.x = p2.x;
    r2.y = p2.y;
    r2.knndist = r.knndist;
    
    NSLog(@"%@ %f %f %f %f %f", _edgeInfo.edgeID, r.x, r.y, r2.x, r2.y, r2.knndist);
    
    return r2;
}

- (void) inputBeacons:(NSArray *)beacons
{
    [_parent inputBeacons:beacons];
}

- (void) inputAcceleration: (NSDictionary*) data
{
    [_parent inputAcceleration:data];
}

- (void) inputMotion: (NSDictionary*) data
{
    [_parent inputMotion:data];
}


- (double) computeDistanceScoreWithOptions: (NSDictionary*) options;{
    NSMutableDictionary* newDict = [options mutableCopy];
    newDict[@"edgeID"] = _edgeInfo.edgeID;
    return [_parent computeDistanceScoreWithOptions:newDict];
}

- (void) setBeacons:(NSDictionary *)beacons
{
    if (!beacons) return;
    if ([_parent respondsToSelector:@selector(setBeacons:)]) {
        NSMutableDictionary *beaconsCopy = [@{} mutableCopy];
        for (NSString* key in beacons) {
            NSDictionary *beacon = beacons[key];
            if (beacon[@"infoFromEdges"] && beacon[@"infoFromEdges"][_edgeInfo.edgeID]) {
                NSDictionary *info = beacon[@"infoFromEdges"][_edgeInfo.edgeID];
                [beaconsCopy setObject:@{
                                         @"uuid": beacon[@"uuid"],
                                         @"major": beacon[@"major"],
                                         @"minor": beacon[@"minor"],
                                         @"x": info[@"x"],
                                         @"y": info[@"y"]
                                         } forKey:key];
            }
        }
        [_parent performSelector:@selector(setBeacons:) withObject:beaconsCopy];
    }
}

@end
