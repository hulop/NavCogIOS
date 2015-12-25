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
 *  Dragan Ahmetovic (CMU) - initial API and implementation
 *******************************************************************************/

#import "NavLogFile.h"
#import <CoreLocation/CoreLocation.h>

@implementation NavLogFile

- (id)initFromFileAtPath:(NSString *)path withUUIDStr:(NSString*) uuidStr
{
    self = [super init];
 
    _uuidStr = uuidStr;
    
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];

    //parse log to array
    //create dictionary with time -> object: either motion or beaconlist
    _timesArray = [[NSMutableArray alloc] init];
    _objectsArray = [[NSMutableArray alloc] init];
    
    //motion holds just 3 values, beaconlist holds array of clbeacons
    NSString *fileContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        
        if ([line isEqualToString:@""])
            break;
        
        //Explode the line with space
        if ([line length] < 23)
            continue;
        NSDate* dateAndTime = [dateFormat dateFromString:[line substringToIndex:23]];
        
        if (dateAndTime == nil)
            continue;
        
        NSArray *breakarray = [line componentsSeparatedByString:@"]"];
        if ([breakarray count] < 2)
            continue;
        NSString* typeAndData = [breakarray[1] substringFromIndex:1];
        NSArray *typeAndDataStringArray = [typeAndData componentsSeparatedByString:@","];
        
        
        if ([typeAndDataStringArray[0] isEqualToString: @"Route"]) {
            _startTime = dateAndTime;
            _fromNodeName = typeAndDataStringArray[1];
            _toNodeName = typeAndDataStringArray[2];
        } else if ([typeAndDataStringArray[0] isEqualToString: @"Acc"]) { //acceleration data
            //get time
            NSDate* currentTime = dateAndTime;
            
            //create motion data object
            NSMutableDictionary* accData = [@{} mutableCopy];
            accData[@"timestamp"] = @([currentTime timeIntervalSince1970]);
            accData[@"type"] = @"acceleration";
            accData[@"x"] = @([typeAndDataStringArray[1] floatValue]);
            accData[@"y"] = @([typeAndDataStringArray[2] floatValue]);
            accData[@"z"] = @([typeAndDataStringArray[3] floatValue]);
            
            //feed to object
            [_timesArray addObject: currentTime];
            [_objectsArray addObject: accData];
            
        } else if ([typeAndDataStringArray[0] isEqualToString: @"Motion"]) {
            //get time
            NSDate* currentTime = dateAndTime;
            
            //create motion data object
            NSMutableDictionary* motionData = [[NSMutableDictionary alloc] init];
            
            motionData[@"timestamp"] = @([currentTime timeIntervalSince1970]);
            motionData[@"type"] = @"motion";
            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[1] floatValue]] forKey:@"pitch"];
            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[2] floatValue]] forKey:@"roll"];
            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[3] floatValue]] forKey:@"yaw"];
            
            //feed to object
            [_timesArray addObject: currentTime];
            [_objectsArray addObject: motionData];
            
        } else if ([typeAndDataStringArray[0] isEqualToString: @"Beacon"]) { //beacon data
            //get number of beacons
            int beaconsNumber = [typeAndDataStringArray[1] intValue];
            NSMutableArray* beaconArrayTmp = [NSMutableArray arrayWithCapacity:beaconsNumber];
            
            for (int i = 0; i < beaconsNumber; i++) {
                CLBeacon* newBeacon = [[CLBeacon alloc] init];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+2] intValue]] forKey:@"major"];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+3] intValue]] forKey:@"minor"];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+4] intValue]] forKey:@"rssi"];
                [newBeacon setValue:[[NSUUID alloc] initWithUUIDString:uuidStr] forKey:@"proximityUUID"];
                
                [beaconArrayTmp addObject:newBeacon];
            }
            //transform it to nsarray
            NSArray* beaconArray = [NSArray arrayWithArray:beaconArrayTmp];
            //get time
            NSDate* currentTime = dateAndTime;
            
            //feed to object
            [_timesArray addObject: currentTime];
            [_objectsArray addObject: beaconArray];
        }
        
    }

    
    return self;
}
@end
