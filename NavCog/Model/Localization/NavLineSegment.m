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

#import "NavLineSegment.h"

@implementation Nav2DPoint

- (id) initWithX: (float)x Y:(float)y{
    self = [super init];
    self.x = x;
    self.y = y;
    return self;
}

@end


@implementation NavLineSegment

- (id) initWithPoint1:(Nav2DPoint *)point1 Point2:(Nav2DPoint *)point2{
    self = [super init];
    _point1 = point1;
    _point2 = point2;
    return self;
}


- (Nav2DPoint*) getNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p{
    float dx = _point2.x - _point1.x;
    float dy = _point2.y - _point1.y;
    float a = dx*dx + dy*dy;
    double b = dx*(_point1.x-p.x) + dy*(_point1.y-p.y);
    if (a == 0) {
        return _point1;
    }
    float t = -b/a;
    // if trim in the edge
    //t = (t<0)?0:t;
    //t = (t>1)?1:t;
    Nav2DPoint *result = [[Nav2DPoint alloc]init];
    result.x = _point1.x + dx*t;
    result.y = _point1.y + dy*t;
    return result;
}

- (double) getDistanceNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p{
    Nav2DPoint* nearestPoint = [self getNearestPointOnLineSegmentFromPoint:p];
    double dx = nearestPoint.x - p.x;
    double dy = nearestPoint.y - p.y;
    double distance = sqrt(dx*dx + dy*dy);
    return distance;
}

@end


@implementation NavLightEdge

- (id) initWithEdge: (NavEdge*) edge{
    self = [super init];
    _edgeID = edge.edgeID;
    NavNode* n1 = edge.node1;
    NavNode* n2 = edge.node2;
    float x_n1 = [n1 getXInEdgeWithID:edge.edgeID];
    float y_n1 = [n1 getYInEdgeWithID:edge.edgeID];
    float x_n2 = [n2 getXInEdgeWithID:edge.edgeID];
    float y_n2 = [n2 getYInEdgeWithID:edge.edgeID];
    
    int floor1 = edge.node1.floor;
    int floor2 = edge.node2.floor;
    _floor = floor1;

    Nav2DPoint* p1 = [[Nav2DPoint alloc] initWithX: x_n1 Y:y_n1];
    Nav2DPoint* p2 = [[Nav2DPoint alloc] initWithX: x_n2 Y:y_n2];
    
    _lineSegment = [[NavLineSegment alloc] initWithPoint1:p1 Point2:p2];
    return self;
}


- (double) getDistanceNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p{
    return [_lineSegment getDistanceNearestPointOnLineSegmentFromPoint:p];
}

@end


@implementation NavLightEdgeHolder

static NavLightEdgeHolder* instance;

- (id) init{
    self = [super init];
    _edges = [NSMutableDictionary dictionary];
    return self;
}


+ (NavLightEdgeHolder*) sharedInstance{
    if(!instance){
        instance = [[NavLightEdgeHolder alloc] init];
    }
    return instance;
}


- (void) appendNavLightEdge: (NavLightEdge*) edge{
    NSString* edgeID = edge.edgeID;
    _edges[edgeID] = edge;
    
}
- (NavLightEdge*) getNavLightEdgeByEdgeID: (NSString*) edgeID{
    return _edges[edgeID];
}

@end