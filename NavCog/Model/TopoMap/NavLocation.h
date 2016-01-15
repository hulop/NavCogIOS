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

#ifndef NavLocation_h
#define NavLocation_h

#import "TopoMap.h"
#import "NavEdge.h"
#import "NavNode.h"

@class TopoMap;
@class NavEdge;
@class NavNode;

@interface NavLocation : NSObject

@property (strong, nonatomic) NSString *layerID;
@property (strong, nonatomic) NSString *edgeID;
@property (nonatomic) double yInEdge;
@property (nonatomic) double xInEdge;
@property (nonatomic) float knndist;
@property (nonatomic) double lat;
@property (nonatomic) double lng;
@property (nonatomic) float ori1;
@property (nonatomic) float ori2;

- (instancetype)initWithMap:(TopoMap *)map;
- (double) distanceToNode:(NavNode*)node;
- (NSArray*) pathToNode:(NavNode*)node;
- (NSArray*) pathFromNode:(NavNode*)node;
- (NavEdge *)getEdge;

@end

#endif /* NavLocation_h */
