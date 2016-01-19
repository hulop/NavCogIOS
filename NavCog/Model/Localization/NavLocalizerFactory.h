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
#import "NavLocalizer.h"
#import "NavEdgeLocalizer.h"
#import "TopoMap.h"

@interface NavLocalizerFactory : NSObject

+ (NSArray*) allCoreLocalizers;
+ (NSArray*) allEdgeLocalizers;

+ (NSArray*) localizersForEdges:(NSArray*) edges;
+ (NavEdgeLocalizer*) localizerForEdge:(NSString*) edgeID;

+ (NavLocalizer*) localizerForID:(NSString*)idStr withEdgeInfo:(NavLightEdge*) edgeInfo andOptions:(NSDictionary*)options;
+ (NavLocalizer*) createLocalizer:(NSDictionary*)loc;
+ (NavLocalizer*) create1D_KNN_LocalizerForID:(NSString*) idStr FromFile:(NSString*)path;
+ (NavLocalizer*) create2D_PF_PDR_LocalizerForID:(NSString*) idStr FromFile:(NSString*)path;
+ (NavLocalizer*) create2D_PF_PDR_LocalizerForID:(NSString *)idStr onFloor:(int) floor;

+ (NavLocalizer*) create1D_PF_PDR_LocalizerForID:(NSString*) idStr FromFile:(NSString*)path;

+ (NavEdgeLocalizer*) cloneLocalizerForEdge:(NSString*) edgeID withEdgeInfo:(NavLightEdge*) edgeInfo;

@end
