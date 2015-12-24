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
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "NavMapManager.h"
#define NAVCOG_ROOT @"https://navcog.mybluemix.net"

@interface NavMapManager ()

@property (strong, nonatomic) NSMutableDictionary *mapDict;
@property (strong, nonatomic) NSMutableDictionary *privateMapDict;
@property (strong, nonatomic) NSMutableArray *mapNameList;
@property (strong, nonatomic) void (^handler)(long long current, long long max);
@end

@implementation NavMapManager

+ (instancetype)getInstance {
    static NavMapManager *instance = nil;
    if (instance == nil) {
        instance = [[NavMapManager alloc] init];
        instance.mapDict = [[NSMutableDictionary alloc] init];
        instance.privateMapDict = [[NSMutableDictionary alloc] init];
        instance.mapNameList = [[NSMutableArray alloc] init];
        [instance selfLoadMapList];
    }
    return instance;
}

+ (void)setMapManagerDelegate:(id)obj {
    NavMapManager *instance = [NavMapManager getInstance];
    instance.delegate = obj;
}

+ (void)updateMapList {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *DocumentsDirPath = [paths objectAtIndex:0];
    NSLog(@"Document dir: %@", DocumentsDirPath);
    
    NavMapManager *instance = [NavMapManager getInstance];
    [instance selfUpdateMapDictAndList];
}

+ (void)loadTopoMapWithName:(NSString *)name withProgressHandler:(void (^)(long long, long long)) handler{
    NavMapManager *instance = [NavMapManager getInstance];
    instance.handler = handler;
    [instance selfLoadTopoMapWithName:name];
}

+ (NSArray *)getMapNameList {
    NavMapManager *instance = [NavMapManager getInstance];
    return instance.mapNameList;
}

+ (NSDictionary *)getMapDict {
    NavMapManager *instance = [NavMapManager getInstance];
    return instance.mapDict;
}

- (void)selfLoadMapList {
    [self loadMapListWithName:@"NavCogMapList"];
    [self loadMapListWithName:@"PrivateMapList"];
}

- (void)loadMapListWithName: (NSString*) name {
    NSString *mapListFilePath = [self getPathInDocumentDirForMapWithName:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:mapListFilePath]) {
        NSData *jsonData = [NSData dataWithContentsOfFile:mapListFilePath options:NSDataReadingMappedIfSafe error:nil];
        NSDictionary *mapListJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        NSArray *mapJsonList = [mapListJson objectForKey:@"maps"];
        for (NSDictionary *mapJson in mapJsonList) {
            NSString *mapName = [mapJson objectForKey:@"name"];
            [_mapDict setObject:mapJson forKey:mapName];
            [_mapNameList addObject:mapName];
            if ([name isEqualToString:@"PrivateMapList"]) {
                [_privateMapDict setObject:mapJson forKey:mapName];
            }
        }
    }
}

- (void)selfUpdateMapDictAndList {
    NSURL *mapListURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", NAVCOG_ROOT, @"NavCogMapList.json"]];
    NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:mapListURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            [_delegate mapListUpdated:nil withError:error];
            return;
        }

        NSData *jsonData = [NSData dataWithContentsOfURL:location options:NSDataReadingMappedIfSafe error:nil];
        NSLog(@"%@", jsonData);
        NSDictionary *mapListJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        NSArray *mapJsonList = [mapListJson objectForKey:@"maps"];

        // move map list file to document directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *destPath = [NSString stringWithFormat:@"%@/NavCogMapList.json", documentsDirectory];
        [jsonData writeToFile:destPath atomically:YES];

        NSFileManager *fm = [NSFileManager defaultManager];
        // delete map not in list
        for (NSString *mapName in _mapNameList) {
            // if it's a private map, just leave it there
            NSDictionary *privateMapJson = [_privateMapDict objectForKey:mapName];
            if (privateMapJson != nil) {
                continue;
            }
            // if it's not a private map, check it
            Boolean bExist = false;
            for (NSDictionary *mapJson in mapJsonList) {
                if ([mapName isEqualToString:[mapJson objectForKey:@"name"]]) {
                    bExist = true;
                    break;
                }
            }
            if (!bExist) {
                [_mapDict removeObjectForKey:mapName];
                NSString *mapDataFilePath = [self getPathInDocumentDirForMapWithName:mapName];
                [fm removeItemAtPath:mapDataFilePath error:nil];
            }
        }
        
        // delete map updated
        [_mapNameList removeAllObjects];
        for (NSDictionary *mapJson in mapJsonList) {
            NSString *mapName = [mapJson objectForKey:@"name"];
            NSDictionary *curMapJson = [_mapDict objectForKey:mapName];
            if (curMapJson != nil) {
                NSInteger curTimeStamp = ((NSNumber *)[curMapJson objectForKey:@"lastupdate"]).integerValue;
                NSInteger newTimeStamp = ((NSNumber *)[mapJson objectForKey:@"lastupdate"]).integerValue;
                if (newTimeStamp != curTimeStamp) {
                    NSString *mapDataFilePath = [self getPathInDocumentDirForMapWithName:mapName];
                    [fm removeItemAtPath:mapDataFilePath error:nil];
                }
            }
            [_mapDict setObject:mapJson forKey:mapName];
            [_mapNameList addObject:mapName];
        }
        
        [_delegate mapListUpdated:_mapNameList withError:nil];
    }];
    [downloadTask resume];
}

- (void)selfLoadTopoMapWithName:(NSString *)mapName {
    NSDictionary *mapJson = [_mapDict objectForKey:mapName];
    if (mapJson == nil) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:[self getPathInDocumentDirForMapWithName:mapName]]) {
        NSURL *mapURL = [NSURL URLWithString:[mapJson objectForKey:@"url"]];
        NSURLSession *session =
        [NSURLSession
         sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
         delegate:self
         delegateQueue:[NSOperationQueue mainQueue]];
        
        NSURLSessionDownloadTask *task = [session downloadTaskWithURL:mapURL ];
        self.loadingMapName = mapName;
        [task resume];
        
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            TopoMap *topoMap = [[TopoMap alloc] init];
            NSString *mapdataFilePath = [self getPathInDocumentDirForMapWithName:mapName];
            NSString *dataStr = [topoMap initializaWithFile: mapdataFilePath];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate topoMapLoaded:topoMap withMapDataString:dataStr withError:nil];
            });
        });
    }
}
/*
 
 NSProgress *progress;
 NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:mapListURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
 
 
 [progress removeObserver:self forKeyPath:@"fractionCompleted" context:NULL];
 }];
 [progress addObserver:self
 forKeyPath:@"fractionCompleted"
 options:NSKeyValueObservingOptionNew
 context:NULL];
 
 
 [downloadTask resume];
 */
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (self.handler) {
        self.handler(totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    NSLog(@"finished: %@", location);
    /*
    if (error) {
        NSLog(@"%@", error);
        [_delegate topoMapLoaded:nil withMapDataString:nil withError:error];
        return;
    }
     */
    // move map data file to document directory
    NSString *destPath = [self getPathInDocumentDirForMapWithName:_loadingMapName];
    NSData *jsonData = [NSData dataWithContentsOfURL:location options:NSDataReadingMappedIfSafe error:nil];
    [jsonData writeToFile:destPath atomically:YES];
    
    // load topo map
    TopoMap *topoMap = [[TopoMap alloc] init];
    NSString *dataStr = [topoMap initializaWithFile:[self getPathInDocumentDirForMapWithName:_loadingMapName]];
    [_delegate topoMapLoaded:topoMap withMapDataString:dataStr withError:nil];
}


- (NSString *)getPathInDocumentDirForMapWithName:(NSString *)mapName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *mapDataFilePath = [NSString stringWithFormat:@"%@/%@.json", documentsDirectory, mapName];
    return mapDataFilePath;
}

@end
