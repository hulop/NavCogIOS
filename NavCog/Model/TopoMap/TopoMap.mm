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
 *
 * Contributors:
 *  Chengxiong Ruan (CMU) - initial API and implementation
 *  Cole Gleason (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "TopoMap.h"
#import "NavLocalizerFactory.h"
#import "NavUtil.h"
#import "NavI18nUtil.h"
#import "NavLineSegment.h"

@interface TopoMap ()

@property (strong, nonatomic) NSMutableDictionary *layers;
@property (strong, nonatomic) NSMutableDictionary *nodeNameNodeIDDict;
@property (strong, nonatomic) NSMutableDictionary *nodeNameLayerIDDict;
@property (strong, nonatomic) NSString *uuidString;
@property (strong, nonatomic) NSString *majoridString;
@property (strong, nonatomic) NavNode *tmpNode;
@property (strong, nonatomic) NavLayer *tmpNodeParentLayer;
@property (strong, nonatomic) NavEdge *tmpNodeParentEdge;

@end

@implementation TopoMap

double TopoMapUnit = 1.0;  // 1 = 1 foot
static const double FEET_IN_METER = 0.3048;


+ (double)unit2feet:(double)value
{
    return value*TopoMapUnit;
}

+ (double)feet2unit:(double)value
{
    return value/TopoMapUnit;
}

+ (double)unit2meter:(double)value
{
    return value*TopoMapUnit*FEET_IN_METER;
}

+ (double)meter2unit:(double)value
{
    return value/TopoMapUnit/FEET_IN_METER;
}

- (NSString *)getUUIDString {
    return _uuidString;
}

- (NSString *)getMajorIDString {
    return _majoridString;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _layers = [[NSMutableDictionary alloc] init];
        _nodeNameNodeIDDict = [[NSMutableDictionary alloc] init];
        _nodeNameLayerIDDict = [[NSMutableDictionary alloc] init];
        _tmpNode = nil;
    }
    return self;
}

- (NSString *)initializaWithFile:(NSString *)filePath {
    NSMutableDictionary *mapDataJson;
    
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        mapDataJson = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    }
    
    if ([mapDataJson[@"unit"] isEqualToString:UNIT_METER]) {
        TopoMapUnit = 1.0/0.3048;
    } // otherwise 1.0
    
    BOOL advanced = false;
    BOOL usesTransitKnnDistThres = true;
    if (mapDataJson[@"isAdvanced"]) {
        advanced = [mapDataJson[@"isAdvanced"] boolValue];
    }
    if(advanced){
        usesTransitKnnDistThres = false;
        if([mapDataJson.allKeys containsObject:@"usesTransitKnnDistThres"]){
            usesTransitKnnDistThres = [mapDataJson[@"usesTransitKnnDistThres"] boolValue];
        }
    }
    
    NSString *language = [NavI18nUtil getPreferredLanguage:[mapDataJson objectForKey:@"languages"]];
    NSLog(@"%@ is selected", language);
    self.language = language;
    
    NSArray *localizationsJson = [mapDataJson objectForKey:@"localizations"];
    _uuidString = [mapDataJson objectForKey:@"lastUUID"];
    _majoridString = [mapDataJson objectForKey:@"lastMajorID"];
    
    [NavLocalizerFactory reset];    
    for (int i = 0; i < localizationsJson.count; i++) {
        NSDictionary *loc = [localizationsJson objectAtIndex:i];
        [NavLocalizerFactory createLocalizer:loc];
    }
    
    NSObject *buildings = mapDataJson[@"buildings"];
    
    NSDictionary *layersJson = (NSDictionary *)[mapDataJson objectForKey:@"layers"];
    for (NSString *zIndex in [layersJson allKeys]) {
        NSDictionary *layerJson = [layersJson objectForKey:zIndex];
        NavLayer *layer = [[NavLayer alloc] init];
        layer.zIndex = [layerJson objectForKey:@"z"];
        
        // load node information
        NSDictionary *nodesJson = [layerJson objectForKey:@"nodes"];
        for (NSString *nodeID in [nodesJson allKeys]) {
            NSDictionary *nodeJson = [nodesJson objectForKey:nodeID];
            NavNode *node = [[NavNode alloc] init];
            node.language = language;
            node.nodeID = [nodeJson objectForKey:@"id"];
            node.name = [nodeJson objectForKey:[NavI18nUtil key:@"name" lang:language]];
            node.type = NodeType(((NSNumber *)[nodeJson objectForKey:@"type"]).intValue);
            
            if ([buildings isKindOfClass:NSDictionary.class]) {
                NSDictionary *building = [(NSDictionary*)buildings objectForKey:[nodeJson objectForKey:@"building"]];
                node.buildingName = [building objectForKey:[NavI18nUtil key:@"name" lang:language]];
            } else { // backward compati
                node.buildingName = [nodeJson objectForKey:@"building"];
            }
            node.floor = ((NSNumber *)[nodeJson objectForKey:@"floor"]).intValue;
            node.layerZIndex = zIndex;
            node.lat = ((NSNumber *)[nodeJson objectForKey:@"lat"]).doubleValue;
            node.lng = ((NSNumber *)[nodeJson objectForKey:@"lng"]).doubleValue;
            [node.infoFromEdges addEntriesFromDictionary:[nodeJson objectForKey:@"infoFromEdges"]];
            node.transitInfo = [nodeJson objectForKey:@"transitInfo"];
            node.transitKnnDistThres = ((NSNumber *)[nodeJson objectForKey:@"knnDistThres"]).floatValue;
            if (advanced && !usesTransitKnnDistThres) {
                node.transitKnnDistThres = 1.0;
            }
            node.transitPosThres = ((NSNumber *)[nodeJson objectForKey:@"posDistThres"]).floatValue;
//            node.transitKnnDistThres = MAX(1.0, node.transitKnnDistThres);
//            node.transitPosThres = MAX(10, node.transitPosThres);
            node.parentLayer = layer;
            [_nodeNameNodeIDDict setObject:node.nodeID forKey:node.name];
            [_nodeNameLayerIDDict setObject:zIndex forKey:node.name];
            [layer.nodes setObject:node forKey:node.nodeID];
        }
        
        // load edge information
        NSDictionary *edgesJson = [layerJson objectForKey:@"edges"];
        for (NSString *edgeID in [edgesJson allKeys]) {
            NSDictionary *edgeJson = [edgesJson objectForKey:edgeID];
            NavEdge *edge = [[NavEdge alloc] init];
            edge.language = language;
            edge.edgeID = [edgeJson objectForKey:@"id"];
            
            edge.type = EdgeType(((NSNumber *)[edgeJson objectForKey:@"type"]).intValue);
            edge.len = (int)[TopoMap unit2feet:((NSNumber *)[edgeJson objectForKey:@"len"]).doubleValue];
            edge.ori1 = ((NSNumber *)[edgeJson objectForKey:@"oriFromNode1"]).floatValue;
            edge.ori2 = ((NSNumber *)[edgeJson objectForKey:@"oriFromNode2"]).floatValue;
            edge.minKnnDist = ((NSNumber *)[edgeJson objectForKey:@"minKnnDist"]).floatValue;
            edge.maxKnnDist = ((NSNumber *)[edgeJson objectForKey:@"maxKnnDist"]).floatValue;
            edge.nodeID1 = [edgeJson objectForKey:@"node1"];
            edge.node1 = [layer.nodes objectForKey:edge.nodeID1];
            edge.nodeID2 = [edgeJson objectForKey:@"node2"];
            edge.node2 = [layer.nodes objectForKey:edge.nodeID2];
            
            NSString *idStr = [edgeJson objectForKey:@"localizationID"];
            
            if (edgeJson[@"path"]) {
                NSMutableArray *temp = [@[] mutableCopy];
                for(NSDictionary *point in edgeJson[@"path"]) {
                    NSMutableDictionary *newPoint = [@{} mutableCopy];
                    for(NSString *key in point.allKeys) {
                        if ([key isEqualToString:@"x"] || [key isEqualToString:@"y"]) {
                            newPoint[key] = @([TopoMap unit2feet:[point[key] doubleValue]]);
                        } else {
                            newPoint[key] = point[key];
                        }
                    }
                    [temp addObject:newPoint];
                }
                edge.path = temp;
                edge.ori1 = [temp[0][@"forward"] doubleValue];
                edge.ori2 = [temp[temp.count-1][@"backward"] doubleValue];
            }
            
            NavLightEdge* edgeInfo = [[NavLightEdge alloc] initWithEdge:edge];
            [[NavLightEdgeHolder sharedInstance] appendNavLightEdge:edgeInfo];
            
            NSMutableDictionary *temp = [edgeJson mutableCopy];
            temp[@"beacons"] = layerJson[@"beacons"]; // for 1D PDR
            if (!idStr || !advanced) {
                NSString *path = [NavUtil createTempFile:[edgeJson objectForKey:@"dataFile"] forID:&idStr];
                [NavLocalizerFactory create1D_KNN_LocalizerForID:idStr FromFile:path];
            }else{ // for localizers with PDR
                edge.minKnnDist = 0;
                edge.maxKnnDist = 1;                
            }
            [NavLocalizerFactory localizerForID:idStr withEdgeInfo:edgeInfo andOptions:temp];
            
            
            edge.info1 = [edgeJson objectForKey:[NavI18nUtil key:@"infoFromNode1" lang:language]];
            edge.info2 = [edgeJson objectForKey:[NavI18nUtil key:@"infoFromNode2" lang:language]];
            edge.parentLayer = layer;
            [layer.edges setObject:edge forKey:edge.edgeID];
        }
        
        // get neighbor information from all nodes and edges
        for (NSString *nodeID in layer.nodes) {
            NavNode *node = [layer.nodes objectForKey:nodeID];
            for (NSString *edgeID in node.infoFromEdges) {
                NavEdge *edge = [layer.edges objectForKey:edgeID];
                NavNeighbor *neighbor = [[NavNeighbor alloc] init];
                neighbor.edge = edge;
                if (node != edge.node1) {
                    neighbor.node = edge.node1;
                } else {
                    neighbor.node = edge.node2;
                }
                [node.neighbors addObject:neighbor];
            }
        }
        
        [_layers setObject:layer forKey:layer.zIndex];
    }
    NSMutableDictionary *temp = mapDataJson[@"layers"];
    //temp[@"localizations"] = nil;
    //return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:temp options:0 error:nil] encoding:NSUTF8StringEncoding];
}

- (NSArray *)findShortestPathFromCurrentLocation:(NavLocation *)curLocation toNodeWithName:(NSString *)toNodeName{
    NavEdge *curEdge = [self getEdgeFromLayer:curLocation.layerID withEdgeID:curLocation.edgeID];
    NavLayer *curLayer = [_layers objectForKey:curLocation.layerID];
    
    // if your current location reach one of the ends of current edge
    // then just do the same, not touching the topo map
    if ([curEdge checkValidEndNodeAtLocation:curLocation] != nil) {
        NavNode *node = [curEdge checkValidEndNodeAtLocation:curLocation];
        return [self findShortestPathFromNode:node toNodeWithName:toNodeName];
    } else {
        // use a tmp node to split the edge into two
        NavNode *tmpNode = [[NavNode alloc] init];
        _tmpNode = tmpNode;
        _tmpNodeParentLayer = curLayer;
        _tmpNodeParentEdge = curEdge;
        tmpNode.nodeID = @"tmp_node";
        tmpNode.type = NODE_TYPE_NORMAL;
        tmpNode.layerZIndex = curLocation.layerID;
        tmpNode.buildingName = curEdge.node1.buildingName;
        tmpNode.floor = curEdge.node1.floor;
        
        double slat = curEdge.node1.lat;
        double slng = curEdge.node1.lng;
        double tlat = curEdge.node2.lat;
        double tlng = curEdge.node2.lng;

        double sx = [curEdge.node1 getXInEdgeWithID:curEdge.edgeID];
        double sy = [curEdge.node1 getYInEdgeWithID:curEdge.edgeID];
        double tx = [curEdge.node2 getXInEdgeWithID:curEdge.edgeID];
        double ty = [curEdge.node2 getYInEdgeWithID:curEdge.edgeID];
        
        double ax = tx-sx;
        double ay = ty-sy;
        double bx = curLocation.xInEdge - sx;
        double by = curLocation.yInEdge - sy;
        
        double alen = sqrt(ax*ax+ay*ay);
        double ratio = (ax*bx+ay*by)/alen/alen;
        ratio = fmin(1, fmax(0, ratio));
        
        //double ratio = (curLocation.yInEdge - sy) / (ty - sy);
        //ratio = ratio < 0 ? 0 : ratio;
        //ratio = ratio > 1 ? 1 : ratio;
        
        //tmpNode.lat = slat + ratio * (tlat - slat);
        //tmpNode.lng = slng + ratio * (tlng - slng);
        tmpNode.lat = curLocation.lat;
        tmpNode.lng = curLocation.lng;
        tmpNode.parentLayer = curLayer;
        
        // the dynamic topo map looks lik this
        //          tmp edge 1              tmp edge 2
        // (node1)--------------(tmp node)--------------(node2)
        //      \_________________________________________/
        //                   current edge
        // new two edges
        NavEdge *tmpEdge1 = [curEdge clone];
        tmpEdge1.edgeID = @"tmp_edge_1";
        tmpEdge1.node2 = tmpNode;
        tmpEdge1.nodeID2 = tmpNode.nodeID;
        tmpEdge1.len = [curLocation distanceToNode:curEdge.node1];
        tmpEdge1.path = [curLocation pathFromNode:curEdge.node1];
        if (tmpEdge1.path) {
            tmpEdge1.ori1 = [tmpEdge1.path[0][@"forward"] floatValue];
            tmpEdge1.ori2 = [tmpEdge1.path[tmpEdge1.path.count-1][@"backward"] floatValue];
        }
        //tmpEdge1.len = sqrt(pow(curLocation.yInEdge - sy,2)+pow(curLocation.xInEdge - sx,2));
        NavEdge *tmpEdge2 = [curEdge clone];
        tmpEdge2.edgeID = @"tmp_edge_2";
        tmpEdge2.node1 = tmpNode;
        tmpEdge2.nodeID1 = tmpNode.nodeID;
        tmpEdge2.len = [curLocation distanceToNode:curEdge.node2];
        tmpEdge2.path = [curLocation pathToNode:curEdge.node2];
        if (tmpEdge2.path) {
            tmpEdge2.ori1 = [tmpEdge2.path[0][@"forward"] floatValue];
            tmpEdge2.ori2 = [tmpEdge2.path[tmpEdge2.path.count-1][@"backward"] floatValue];
        }
        //tmpEdge2.len = sqrt(pow(curLocation.yInEdge - ty,2)+pow(curLocation.xInEdge - tx,2));
        
        // add info from edges to tmp node
        NSDictionary *infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge1.edgeID andXInEdge:curLocation.xInEdge andYInEdge:curLocation.yInEdge];
        [tmpNode.infoFromEdges setObject:infoDict forKey:tmpEdge1.edgeID];
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge2.edgeID andXInEdge:curLocation.xInEdge andYInEdge:curLocation.yInEdge];
        [tmpNode.infoFromEdges setObject:infoDict forKey:tmpEdge2.edgeID];
        
        // add neighbor information
        NavNeighbor *nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge1;
        nb.node = curEdge.node1;
        [tmpNode.neighbors addObject:nb];
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge2;
        nb.node = curEdge.node2;
        [tmpNode.neighbors addObject:nb];
        
        // add neighbor information to node1 and node2 of curEdge
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge1;
        nb.node = tmpNode;
        [curEdge.node1.neighbors addObject:nb];
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge2;
        nb.node = tmpNode;
        
        [tmpEdge1.node1.infoFromEdges setObject:[tmpEdge1.node1.infoFromEdges objectForKey:curEdge.edgeID] forKey:tmpEdge1.edgeID];
        [tmpEdge2.node2.infoFromEdges setObject:[tmpEdge2.node2.infoFromEdges objectForKey:curEdge.edgeID] forKey:tmpEdge2.edgeID];
        
        // copy edge localization for temp edges
        NavLightEdge* edgeInfo1 = [[NavLightEdge alloc] initWithEdge:tmpEdge1];
        [[NavLightEdgeHolder sharedInstance] appendNavLightEdge:edgeInfo1];
        NavEdgeLocalizer *nl1 = [NavLocalizerFactory cloneLocalizerForEdge:curEdge.edgeID withEdgeInfo:edgeInfo1];

        NavLightEdge* edgeInfo2 = [[NavLightEdge alloc] initWithEdge:tmpEdge2];
        [[NavLightEdgeHolder sharedInstance] appendNavLightEdge:edgeInfo2];
        NavEdgeLocalizer *nl2 = [NavLocalizerFactory cloneLocalizerForEdge:curEdge.edgeID withEdgeInfo:edgeInfo2];


        
        // add info from tmp edges for node1 and node2
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge1.edgeID andXInEdge:[curEdge.node1 getXInEdgeWithID:curEdge.edgeID] andYInEdge:[curEdge.node1 getYInEdgeWithID:curEdge.edgeID]];
        [curEdge.node1.infoFromEdges setObject:infoDict forKey:tmpEdge1.edgeID];
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge2.edgeID andXInEdge:[curEdge.node2 getXInEdgeWithID:curEdge.edgeID] andYInEdge:[curEdge.node2 getYInEdgeWithID:curEdge.edgeID]];
        [curEdge.node2.infoFromEdges setObject:infoDict forKey:tmpEdge2.edgeID];
        
        [curLayer.nodes setObject:tmpNode forKey:tmpNode.nodeID];
        [curLayer.edges setObject:tmpEdge1 forKey:tmpEdge1.edgeID];
        [curLayer.edges setObject:tmpEdge2 forKey:tmpEdge2.edgeID];
        return [self findShortestPathFromNode:tmpNode toNodeWithName:toNodeName];
    }
}

- (void)cleanTmpNodeAndEdges {
    [NavLog stopLog];
    [_tmpNodeParentLayer.nodes removeObjectForKey:@"tmp_node"];
    [_tmpNodeParentLayer.edges removeObjectForKey:@"tmp_edge_1"];
    [_tmpNodeParentLayer.edges removeObjectForKey:@"tmp_edge_2"];
    [_tmpNodeParentEdge.node1.infoFromEdges removeObjectForKey:@"tmp_edge_1"];
    [_tmpNodeParentEdge.node2.infoFromEdges removeObjectForKey:@"tmp_edge_2"];
    for (NavNeighbor *nb in _tmpNodeParentEdge.node1.neighbors) {
        if ([nb.node.nodeID isEqualToString:@"tmp_node"]) {
            [_tmpNodeParentEdge.node1.neighbors removeLastObject];
        }
    }
    for (NavNeighbor *nb in _tmpNodeParentEdge.node2.neighbors) {
        if ([nb.node.nodeID isEqualToString:@"tmp_node"]) {
            [_tmpNodeParentEdge.node2.neighbors removeLastObject];
        }
    }
}

- (NSDictionary *)getNodeInfoDictFromEdgeWithID:(NSString *)edgeID andXInEdge:(double)x andYInEdge:(double)y {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:edgeID forKey:@"edgeID"];
    [dict setObject:[NSNumber numberWithDouble:[TopoMap feet2unit:x]] forKey:@"x"];
    [dict setObject:[NSNumber numberWithDouble:[TopoMap feet2unit:y]] forKey:@"y"];
    return dict;
}

// return all POI node names
- (NSArray *)getAllLocationNamesOnMap {
    NSMutableArray *allNames = [[NSMutableArray alloc] init];
    for (NavLayer *layer in [_layers allValues]) {
        for (NavNode *node in [layer.nodes allValues]) {
            if (node.type == NODE_TYPE_DESTINATION) {
                [allNames addObject:node.name];
            }
        }
    }
    return allNames;
}

- (NSArray *)getAllLocationNamesOnMapSorted:(bool) sorted {
    NSArray *a = [self getAllLocationNamesOnMap];
    if (sorted) {
        a = [a sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [(NSString*)obj1 compare:(NSString*)obj2] ;
        }];
    }
    return a;
}

// search a shortest path
- (NSArray *)findShortestPathFromNode:(NavNode *)startNode toNodeWithName:(NSString *)toName {
    // get start node and end node of the path
    NavNode *endNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:toName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:toName]];
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    
    // visited nodes and nodes have been reachable from start node
    NSMutableSet *visitedNodes = [[NSMutableSet alloc] init];
    NSMutableSet *reachableNodes = [[NSMutableSet alloc] init];
    
    // initialize the Min-Heap, maximum size is number of nodes
    NavMinHeap *heap = [[NavMinHeap alloc] init];
    [heap initHeapWithSize:(int)[[_nodeNameNodeIDDict allKeys] count]];
    
    // initial the search from start node, start the search from start node's neighbors
    startNode.distFromStartNode = 0;
    startNode.preNodeInPath = nil;
    [reachableNodes addObject:startNode];
    [heap offer:startNode];
    
    // search for end node, O((N+E)*log(N)), N is total number of nodes, E is total number of edges
    while ([heap getSize] > 0) {
        NavNode *node = [heap poll];
        [visitedNodes addObject:node];
        [reachableNodes removeObject:node];
        for (NavNeighbor *neighbor in node.neighbors) {
            NavNode *nbNode = neighbor.node;
            if ([visitedNodes containsObject:nbNode]) {
                continue;
            }
            if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                int newDist = node.distFromStartNode + neighbor.edge.len;
                if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                    nbNode.preNodeInPath = node;
                    nbNode.preEdgeInPath = neighbor.edge;
                    [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                }
            } else {
                nbNode.distFromStartNode = node.distFromStartNode + neighbor.edge.len;
                nbNode.preNodeInPath = node;
                nbNode.preEdgeInPath = neighbor.edge;
                if ([nbNode.name isEqualToString:endNode.name]) {
                    return [self traceBackForPathFromNode:nbNode];
                }
                [heap offer:nbNode];
                [reachableNodes addObject:nbNode];
            }
        }
        
        for (NSString *layerID in node.transitInfo) {
            NSDictionary *transitJson = [node.transitInfo objectForKey:layerID];
            Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
            if (transitEnabled) {
                NavNode *nbNode = [self getNodeWithID:[transitJson objectForKey:@"node"] fromLayerWithID:layerID];
                if (![visitedNodes containsObject:nbNode]) {
                    if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                        int newDist = node.distFromStartNode;
                        if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                            nbNode.preNodeInPath = node;
                            nbNode.preEdgeInPath = nil;
                            [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                        }
                    } else {
                        nbNode.distFromStartNode = node.distFromStartNode;
                        nbNode.preNodeInPath = node;
                        nbNode.preEdgeInPath = nil;
                        if ([nbNode.name isEqualToString:endNode.name]) {
                            return [self traceBackForPathFromNode:nbNode];
                        }
                        [heap offer:nbNode];
                        [reachableNodes addObject:nbNode];
                    }
                }
            }
        }
    }
    
    return nil;
}

// search a shortest path
- (NSArray *)findShortestPathFromNodeWithName:(NSString *)fromName toNodeWithName:(NSString *)toName {
    // get start node and end node of the path
    NavNode *startNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:fromName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:fromName]];
    NavNode *endNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:toName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:toName]];
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    
    // visited nodes and nodes have been reachable from start node
    NSMutableSet *visitedNodes = [[NSMutableSet alloc] init];
    NSMutableSet *reachableNodes = [[NSMutableSet alloc] init];
    
    // initialize the Min-Heap, maximum size is number of nodes
    NavMinHeap *heap = [[NavMinHeap alloc] init];
    [heap initHeapWithSize:(int)[[_nodeNameNodeIDDict allKeys] count]];
    
    // initial the search from start node, start the search from start node's neighbors
    startNode.distFromStartNode = 0;
    startNode.preNodeInPath = nil;
    [reachableNodes addObject:startNode];
    [heap offer:startNode];
    
    // search for end node, O((N+E)*log(N)), N is total number of nodes, E is total number of edges
    while ([heap getSize] > 0) {
        NavNode *node = [heap poll];
        [visitedNodes addObject:node];
        [reachableNodes removeObject:node];
        for (NavNeighbor *neighbor in node.neighbors) {
            NavNode *nbNode = neighbor.node;
            if ([visitedNodes containsObject:nbNode]) {
                continue;
            }
            if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                int newDist = node.distFromStartNode + neighbor.edge.len;
                if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                    nbNode.preNodeInPath = node;
                    nbNode.preEdgeInPath = neighbor.edge;
                    [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                }
            } else {
                nbNode.distFromStartNode = node.distFromStartNode + neighbor.edge.len;
                nbNode.preNodeInPath = node;
                nbNode.preEdgeInPath = neighbor.edge;
                if ([nbNode.name isEqualToString:endNode.name]) {
                    return [self traceBackForPathFromNode:nbNode];
                }
                [heap offer:nbNode];
                [reachableNodes addObject:nbNode];
            }
        }
        
        for (NSString *layerID in node.transitInfo) {
            NSDictionary *transitJson = [node.transitInfo objectForKey:layerID];
            Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
            if (transitEnabled) {
                NavNode *nbNode = [self getNodeWithID:[transitJson objectForKey:@"node"] fromLayerWithID:layerID];
                if (![visitedNodes containsObject:nbNode]) {
                    if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                        int newDist = node.distFromStartNode;
                        if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                            nbNode.preNodeInPath = node;
                            nbNode.preEdgeInPath = nil;
                            [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                        }
                    } else {
                        nbNode.distFromStartNode = node.distFromStartNode;
                        nbNode.preNodeInPath = node;
                        nbNode.preEdgeInPath = nil;
                        if ([nbNode.name isEqualToString:endNode.name]) {
                            return [self traceBackForPathFromNode:nbNode];
                        }
                        [heap offer:nbNode];
                        [reachableNodes addObject:nbNode];
                    }
                }
            }
        }
    }
    
    return nil;
}

- (NSArray *)traceBackForPathFromNode:(NavNode *)node {
    NSMutableArray *pathNodes = [[NSMutableArray alloc] init];
    [pathNodes addObject:node];
    NavNode *preNode = node.preNodeInPath;
    while (preNode != nil) {
        [pathNodes addObject:preNode];
        preNode = preNode.preNodeInPath;
    }
    return pathNodes;
}

- (NavNode *)getNodeWithID:(NSString *)nodeID fromLayerWithID:(NSString *)layerID {
    if ([_layers objectForKey:layerID] == nil) {
        return nil;
    }
    NavLayer *layer = [_layers objectForKey:layerID];
    
    if ([layer.nodes objectForKey:nodeID] == nil) {
        return nil;
    }
    
    return [layer.nodes objectForKey:nodeID];
}


- (NavNode *)getNodeFromLayer:(NSString *)layerID withNodeID:(NSString *)nodeID {
    NavLayer *layer = [_layers objectForKey:layerID];
    return [layer.nodes objectForKey:nodeID];
}

- (NavEdge *)getEdgeFromLayer:(NSString *)layerID withEdgeID:(NSString *)edgeID {
    NavLayer *layer = [_layers objectForKey:layerID];
    return [layer.edges objectForKey:edgeID];
}

- (NavEdge *)getEdgeById:(NSString *)edgeID {
    // assume edge id is unique
    for(NavLayer *layer in [_layers allValues]) {
        if ([layer.edges objectForKey:edgeID]) {
            return [layer.edges objectForKey:edgeID];
        }
    }
    return nil;
}


@end
