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

#ifndef NavLineSegment_h
#define NavLineSegment_h

#import "NavEdge.h"

@class NavLineSegment;

@interface Nav2DPoint: NSObject

@property double x;
@property double y;
@property double lat;
@property double lng;

- (id) initWithX: (double)x Y:(double)y;
- (id) initWithX: (double)x Y:(double)y Lat:(double)lat Lng:(double)lng;

+ (instancetype) pointWithData:(NSDictionary*)data;
- (double) distanceTo:(Nav2DPoint*)p;

@end

@interface NavLineSegment: NSObject

@property Nav2DPoint* point1;
@property Nav2DPoint* point2;
@property float ori1;
@property float ori2;

- (id) initWithPoint1:(Nav2DPoint*) point1 Point2:(Nav2DPoint*) point2 Ori1:(float)ori1 Ori2:(float)ori2;
- (Nav2DPoint*) getNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p;
- (double) getDistanceNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p;
- (Nav2DPoint*) pointAtRatio:(double) ratio;
- (double) length;
- (NSDictionary*) toData;

@end


@interface NavLightEdge: NSObject

@property(nonatomic) NSString* edgeID;
@property NSArray<NavLineSegment*> *lineSegments;
@property int floor;

- (id) initWithEdge: (NavEdge*) edge;
- (NavLineSegment*) getNearestSegmentFromPoint:(Nav2DPoint*) p;
- (double) distanceFrom:(Nav2DPoint*)from To:(Nav2DPoint*)to;
- (NSArray*) pathFrom:(Nav2DPoint*)from To:(Nav2DPoint*)to;
- (Nav2DPoint*) pointAtRatio:(double) ratio;
- (double) length;

@end


@interface NavLightEdgeHolder: NSObject
@property NSMutableDictionary* edges;
+ (NavLightEdgeHolder*) sharedInstance;
- (void) appendNavLightEdge: (NavLightEdge*) edge;
- (NavLightEdge*) getNavLightEdgeByEdgeID: (NSString*) edgeID;
@end



#endif /* NavLineSegment_h */
