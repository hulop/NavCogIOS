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

#import "NavLocalizerFactory.h"
#import "KDTreeLocalization.h"
#import "TwoDLocalizer.h"
#import "TwoDFloorLocalizer.h"
#import "NavEdgeLocalizer.h"
#import "NavUtil.h"

@implementation NavLocalizerFactory

static const NSMutableDictionary *navLocalizers = [[NSMutableDictionary alloc] init];
static const NSMutableDictionary *floorLocalizers = [[NSMutableDictionary alloc] init];
static const NSMutableDictionary *edgeLocalizers = [[NSMutableDictionary alloc] init];


+ (NSArray*) allCoreLocalizers
{
    return [navLocalizers allValues];
}

+ (NSArray*) allEdgeLocalizers
{
    return [edgeLocalizers allValues];
}

+ (NSArray*) localizersForEdges:(NSArray*) edges
{
    NSMutableArray *array = [@[] mutableCopy];
    for(NSString* edge in edges) {
        [array addObject:[edgeLocalizers objectForKey:edge]];
    }
    return array;
}

+ (NavEdgeLocalizer*) localizerForEdge:(NSString*) edgeID
{
    return [edgeLocalizers objectForKey:edgeID];
}

+ (NavLocalizer*) localizerForID:(NSString*)idStr withEdgeInfo:(NavLightEdge *)edgeInfo andOptions:(NSDictionary *)options
{
    
    NavLocalizer *nl = [navLocalizers objectForKey:idStr];
    if (options[@"localizationFloor"]) {
        idStr = [NSString stringWithFormat:@"%@:%@", idStr, options[@"localizationFloor"]];
        nl = [floorLocalizers objectForKey:idStr];
    }
    if (nl) {
        if (edgeInfo.edgeID) {
            NavEdgeLocalizer *nel = [[NavEdgeLocalizer alloc] initWithLocalizer:nl withEdgeInfo:edgeInfo];
            [edgeLocalizers setObject:nel forKey:edgeInfo.edgeID];
            return nel;
        }
        return nl;
    }
    return nil;
}


+ (NavLocalizer *)createLocalizer:(NSMutableDictionary *)loc
{
    NSString *idStr = [loc objectForKey:@"id"];
    NSString *type = [loc objectForKey:@"type"];
    NSString *path = [NavUtil createTempFile:[loc objectForKey:@"dataFile"] forID:&idStr];
    [loc removeObjectForKey:@"dataFile"];
    
    if ([type isEqualToString:@"2D_Beacon_PDR"]) {
        NavLocalizer *localizer = [NavLocalizerFactory create2D_PF_PDR_LocalizerForID:idStr FromFile:path];
        
        NSArray *floors = [loc[@"floors"] componentsSeparatedByString:@","];
        for(NSString *floor in floors) {
            [NavLocalizerFactory create2D_PF_PDR_LocalizerForID:idStr onFloor:[floor intValue]];
        }
        return localizer;
    }
    else if ([type isEqualToString:@"1D_Beacon_PDR"]) {
        return [NavLocalizerFactory create1D_PF_PDR_LocalizerForID:idStr FromFile:path];
    }
    else if ([type isEqualToString:@"1D_Beacon"]) {
        return [NavLocalizerFactory create1D_KNN_LocalizerForID:idStr FromFile:path];
    }
    return nil;
}

+ (NavLocalizer*) create1D_KNN_LocalizerForID:(NSString *)idStr FromFile:(NSString *)path
{
    KDTreeLocalization *loc = [[KDTreeLocalization alloc] init];
    
    [loc initializeWithAbsolutePath:path];
    
    if (idStr) {
        [navLocalizers setObject:loc forKey:idStr];
    }
    return loc;
}

+ (NavLocalizer*) create2D_PF_PDR_LocalizerForID:(NSString*) idStr FromFile:(NSString*)path
{
    NSError *error;
    
    NSMutableDictionary *json;
    @autoreleasepool {
        NSData *data = [[NSData alloc] initWithContentsOfFile:path];
        json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    }
    if (error) {
        NSLog(@"%@", error.description);
        return nil;
    }
    
    TwoDLocalizer *loc = [[TwoDLocalizer alloc] init];
    [loc initializeWithJSON: json];

    if (idStr && loc) {
        [navLocalizers setObject:loc forKey:idStr];
    }
    return loc;
}

+ (NavLocalizer *)create2D_PF_PDR_LocalizerForID:(NSString *)idStr onFloor:(int)floor
{
    NSString* idStrFloor = [NSString stringWithFormat:@"%@:%d", idStr, floor];
    if (![navLocalizers objectForKey:idStrFloor]) {
        TwoDLocalizer *loc = (TwoDLocalizer*)[navLocalizers objectForKey: idStr];
        NavLocalizer *floc = [[TwoDFloorLocalizer alloc] initWithLocalizer:loc onFloor:floor];
    
        if (idStr && floc) {
            [floorLocalizers setObject:floc forKey:idStrFloor];
        }
    }
    return [floorLocalizers objectForKey:idStrFloor];
}

+ (NavEdgeLocalizer *)cloneLocalizerForEdge:(NSString *)edgeID withEdgeInfo:(NavLightEdge *)edgeInfo
{
    NavEdgeLocalizer *nel = [[edgeLocalizers objectForKey:edgeID] cloneWithEdgeInfo:edgeInfo];
    
    [edgeLocalizers setObject:nel forKey:edgeInfo.edgeID];
    return nel;
}

@end
