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

- (id)initWithX:(double)x Y:(double)y
{
    self = [super init];
    _x = x;
    _y = y;
    return self;
}

- (id) initWithX: (double)x Y:(double)y Lat:(double)lat Lng:(double)lng {
    self = [self initWithX:x Y:y];
    _lat = lat;
    _lng = lng;
    return self;
}

+ (instancetype)pointWithData:(NSDictionary *)data
{
    double x = [data[@"x"] doubleValue];
    double y = [data[@"y"] doubleValue];
    double lat = [data[@"lat"] doubleValue];
    double lng = [data[@"lng"] doubleValue];
    
    return [[Nav2DPoint alloc] initWithX:x Y:y Lat:lat Lng:lng];
}

- (double)distanceTo:(Nav2DPoint *)p
{
    return sqrt(pow(_x - p.x,2)+pow(_y - p.y, 2));
}

@end


@implementation NavLineSegment

- (id) initWithPoint1:(Nav2DPoint *)point1 Point2:(Nav2DPoint *)point2 Ori1:(float)ori1 Ori2:(float)ori2 {
    self = [super init];
    _point1 = point1;
    _point2 = point2;
    _ori1 = ori1;
    _ori2 = ori2;
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
    t = (t<0)?0:t;
    t = (t>1)?1:t;
    Nav2DPoint *result = [[Nav2DPoint alloc]init];
    result.x = _point1.x + dx*t;
    result.y = _point1.y + dy*t;
    
    float dlat = _point2.lat - _point1.lat;
    float dlng = _point2.lng - _point1.lng;

    result.lat = _point1.lat + dlat*t;
    result.lng = _point1.lng + dlng*t;
    return result;
}

- (double) getDistanceNearestPointOnLineSegmentFromPoint: (Nav2DPoint*) p{
    Nav2DPoint* nearestPoint = [self getNearestPointOnLineSegmentFromPoint:p];
    double dx = nearestPoint.x - p.x;
    double dy = nearestPoint.y - p.y;
    double distance = sqrt(dx*dx + dy*dy);
    return distance;
}


- (Nav2DPoint *)pointAtRatio:(double)ratio
{
    ratio = MAX(0.0, MIN(1.0, ratio));
    float dx = _point2.x - _point1.x;
    float dy = _point2.y - _point1.y;
    return [[Nav2DPoint alloc] initWithX:_point1.x+dx*ratio Y:_point1.y+dy*ratio];    
}

- (double) length
{
    return [_point1 distanceTo:_point2];
}



@end


@implementation NavLightEdge

- (id) initWithEdge: (NavEdge*) edge{
    self = [super init];
    _edgeID = edge.edgeID;
    NavNode* n1 = edge.node1;
    NavNode* n2 = edge.node2;
    double x_n1 = [n1 getXInEdgeWithID:edge.edgeID];
    double y_n1 = [n1 getYInEdgeWithID:edge.edgeID];
    double x_n2 = [n2 getXInEdgeWithID:edge.edgeID];
    double y_n2 = [n2 getYInEdgeWithID:edge.edgeID];
    NSArray *path = edge.path;
    
    int floor1 = edge.node1.floor;
    //int floor2 = edge.node2.floor;
    _floor = floor1;

    Nav2DPoint* p1 = [[Nav2DPoint alloc] initWithX: x_n1 Y:y_n1 Lat:n1.lat Lng:n1.lng];
    Nav2DPoint* p2 = [[Nav2DPoint alloc] initWithX: x_n2 Y:y_n2 Lat:n2.lat Lng:n2.lng];
    
    NSMutableArray<NavLineSegment*> *lineSegments = [@[] mutableCopy];
    
    if (path != nil) {
        NSDictionary *p1 = path[0];
        Nav2DPoint *np1 = [Nav2DPoint pointWithData:path[0]];
        for(int i = 1; i < path.count; i++) {
            NSDictionary *p2 = path[i];
            Nav2DPoint *np2 = [Nav2DPoint pointWithData:p2];
            NavLineSegment *seg = [[NavLineSegment alloc] initWithPoint1:np1 Point2:np2
                                                                    Ori1:[p1[@"forward"] floatValue] Ori2:[p2[@"backward"] floatValue]];
            [lineSegments addObject:seg];
            p1 = p2;
            np1 = np2;
        }
        
    } else {
        [lineSegments addObject:[[NavLineSegment alloc] initWithPoint1:p1 Point2:p2 Ori1:edge.ori1 Ori2:edge.ori2]];
    }
    
    _lineSegments = lineSegments;
    return self;
}

- (NavLineSegment *)getNearestSegmentFromPoint:(Nav2DPoint *)p
{
    double min = MAXFLOAT;
    NavLineSegment *minseg = nil;
    for (NavLineSegment *segment in _lineSegments) {
        double d = [segment getDistanceNearestPointOnLineSegmentFromPoint:p];
        if (d < min) {
            min = d;
            minseg = segment;
        }
    }
    return minseg;
}

-(double)distanceFrom:(Nav2DPoint *)from To:(Nav2DPoint *)to
{
    NavLineSegment *s1 = [self getNearestSegmentFromPoint:from];
    NavLineSegment *s2 = [self getNearestSegmentFromPoint:to];
    
    int i1 = (int)[_lineSegments indexOfObject:s1];
    int i2 = (int)[_lineSegments indexOfObject:s2];

    double d = 0;
    if (i1 == i2) {
        d = [from distanceTo:to];
    } else if (i1 < i2) {
        d += [from distanceTo:s1.point2];
        d += [s2.point1 distanceTo:to];
        for(int i = i1+1; i < i2; i++) {
            d += [_lineSegments[i] length];
        }
    } else if (i2 < i1) {
        d += [to distanceTo:s2.point2];
        d += [s1.point1 distanceTo:from];
        for(int i = i2+1; i < i1; i++) {
            d += [_lineSegments[i] length];
        }        
    }
    return d;
}

- (NSArray *)pathFrom:(Nav2DPoint *)from To:(Nav2DPoint *)to
{
    
    NavLineSegment *s1 = [self getNearestSegmentFromPoint:from];
    from = [s1 getNearestPointOnLineSegmentFromPoint:from];
    NavLineSegment *s2 = [self getNearestSegmentFromPoint:to];
    to = [s2 getNearestPointOnLineSegmentFromPoint:to];
    
    int i1 = (int)[_lineSegments indexOfObject:s1];
    int i2 = (int)[_lineSegments indexOfObject:s2];
    
    NSMutableArray *temp = [@[] mutableCopy];
    if (i1 == i2) {
        return nil;
    } else if (i1 < i2) {
        [temp addObject:[[NavLineSegment alloc] initWithPoint1:from Point2:s1.point2 Ori1:s1.ori1 Ori2:s1.ori2]];
        for(int i = i1+1; i < i2; i++) {
            [temp addObject:_lineSegments[i]];
        }
        [temp addObject:[[NavLineSegment alloc] initWithPoint1:s2.point1 Point2:to Ori1:s2.ori1 Ori2:s2.ori2]];
    } else if (i2 < i1) {
        [temp addObject:[[NavLineSegment alloc] initWithPoint1:to Point2:s2.point2 Ori1:s2.ori1 Ori2:s2.ori2]];
        for(int i = i2+1; i < i1; i++) {
            [temp addObject:_lineSegments[i]];
        }
        [temp addObject:[[NavLineSegment alloc] initWithPoint1:s1.point1 Point2:from Ori1:s1.ori1 Ori2:s1.ori2]];
    }

    NSMutableArray *ret = [@[] mutableCopy];
    for(int i = 0; i < (int)temp.count; i++) {
        NavLineSegment *s1 = temp[i];
        [ret addObject:[@{
                        @"x":@(s1.point1.x),
                        @"y":@(s1.point1.y),
                        @"lat":@(s1.point1.lat),
                        @"lng":@(s1.point1.lng),
                        @"forward":@(s1.ori1)
                        } mutableCopy]];
        if (i > 0) {
            NavLineSegment *s2 = temp[i-1];
            ret[i][@"backward"] = @(s2.ori2);
        }
        if (i == temp.count-1) {
            [ret addObject:[@{
                              @"x":@(s1.point2.x),
                              @"y":@(s1.point2.y),
                              @"lat":@(s1.point2.lat),
                              @"lng":@(s1.point2.lng),
                              @"backward":@(s1.ori2)
                              } mutableCopy]];
        }
    }
    return ret;
}

- (Nav2DPoint *)pointAtRatio:(double)ratio
{
    ratio = MAX(0.0, MIN(1.0, ratio));
    
    Nav2DPoint *result = [[Nav2DPoint alloc] initWithX:0 Y:0];
    double edgeLen = [self length];
    double acumLen = 0;
    for(int i = 0; i < _lineSegments.count; i++) {
        double len = [_lineSegments[i] length];
        if (ratio < (acumLen + len) / edgeLen) {
            double localRatio = (ratio * edgeLen - acumLen) / len;
            result = [_lineSegments[i] pointAtRatio:localRatio];
            break;
        }
        acumLen += len;
    }
    return result;
}

- (double) length
{
    double d = 0;
    for(NavLineSegment *seg in _lineSegments) {
        d += [seg length];
    }
    return d;
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