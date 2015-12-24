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

#import "NavUtil.h"
#import <zlib.h>



@implementation NavUtil

+ (NSString *)createTempFile:(NSString *)dataStr forID:(NSString**)idStr
{
    if (*idStr == nil) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        *idStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
    }
    
    NSString *tempPath = NSTemporaryDirectory();
    
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^data:([a-z]+/[a-z]+);base64," options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:dataStr options:NSMatchingReportProgress range:NSMakeRange(0, dataStr.length)];
    NSString *type = nil;
    @autoreleasepool {
        NSData *data = nil;
        
        if (result != nil) {
            type = [dataStr substringWithRange:[result rangeAtIndex:1]];
            type = [type stringByReplacingOccurrencesOfString:@"^[^/]+/(x-)?" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, type.length)];
            dataStr = [dataStr stringByReplacingCharactersInRange:[result rangeAtIndex:0] withString:@""];
            data = [[NSData alloc] initWithBase64EncodedString:dataStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
            
            tempPath = [tempPath stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.%@", *idStr, type]];
            [data writeToFile:tempPath atomically:YES];
        } else {
            type = @"txt";
            tempPath = [tempPath stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.%@", *idStr, type]];
            [dataStr writeToFile:tempPath atomically:true encoding:NSUTF8StringEncoding error:nil];
            /*
            NSFileManager* fileManager = [NSFileManager defaultManager];
            
            if (![fileManager fileExistsAtPath:tempPath]) {
                [fileManager createFileAtPath:tempPath
                                     contents:[NSData data]
                                   attributes:nil];
            }
            
            NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:tempPath];
            long s = 0;
            while (s + 1024 < dataStr.length) {
                @autoreleasepool {
                    [fileHandle writeData:[[dataStr substringWithRange:NSMakeRange(s, 1024)] dataUsingEncoding:NSUTF8StringEncoding]];
                }
                s+=1024;
            }
            [fileHandle writeData:[[dataStr substringFromIndex:s] dataUsingEncoding:NSUTF8StringEncoding]];
             */
        }
    }
    
    return tempPath;
}


+ (double) clipAngle:(double) x
{
    x = fmod(x, 360);
    if (x<0)
        x+=360;
    
    return x;
}

+ (double) clipAngle2:(double) x
{
    x = fmod(x+180, 360);
    if (x<0)
        x+=360;
    
    return x-180;
}

+ (double) clipAngle:(double)x withLimit:(double)l
{
    if (x > l)
        return l;
    else if (x < -l)
        return -l;
    else
        return x;
}

@end
