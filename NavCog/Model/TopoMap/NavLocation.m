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
#import "NavLocation.h"

@interface NavLocation ()

@property (strong, nonatomic) TopoMap *map;

@end

@implementation NavLocation

- (instancetype)initWithMap:(TopoMap *)map {
    self = [super init];
    if (self) {
        _map = map;
    }
    return self;
}

- (NavEdge *) getEdge {
    if (_map)
        return [_map getEdgeFromLayer:_layerID withEdgeID:_edgeID];
    else
        return nil;
}

- (BOOL)isEqualToNavLocation:(NavLocation *)other {
    if (!other) {
        return NO;
    }
    
    BOOL sameEdge = (!self.edgeID && !other.edgeID) || [self.edgeID isEqualToString:other.edgeID];
    BOOL sameLayer = (!self.layerID && !other.layerID) || [self.layerID isEqualToString:other.layerID];
    
    
    return sameEdge && sameLayer && (self.xInEdge == other.xInEdge) && (self.yInEdge == other.yInEdge) && (self.knndist == other.knndist);
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[NavLocation class]]) {
        return NO;
    }
    
    return [self isEqualToNavLocation:(NavLocation *)object];
}

- (NSUInteger)hash {
    return [self.edgeID hash] ^ [self.layerID hash] ^ [@([self xInEdge]) hash] ^ [@([self yInEdge]) hash];
}

@end