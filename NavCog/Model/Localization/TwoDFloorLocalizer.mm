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

#import "TwoDFloorLocalizer.h"

@implementation TwoDFloorLocalizer


- (id) initWithLocalizer:(TwoDLocalizer*) localizer onFloor:(int) floor
{
    self = [super init];
    self.localizer = localizer;
    self.floor = floor;
    return self;
}

- (void)initializeState:(NSDictionary*) options
{
    NSMutableDictionary *newOptions = [options mutableCopy];
    newOptions[@"floor"] = @(self.floor-1);
    [self.localizer initializeState:newOptions];
}

- (NavLocalizeResult *)getLocation
{
    NavLocalizeResult *r = [self.localizer getLocation];
    r.floor = self.floor;
    return r;
}

- (void) inputBeacons:(NSArray *)beacons
{
    [self.localizer inputBeacons:beacons];
}

- (void) inputAcceleration: (NSDictionary*) data
{
    [self.localizer inputAcceleration:data];
}

- (void) inputMotion: (NSDictionary*) data
{
    [self.localizer inputMotion:data];
}

- (double) computeDistanceScoreWithOptions:(NSDictionary *)options{
    return [self.localizer computeDistanceScoreWithOptions:options];
}

@end
