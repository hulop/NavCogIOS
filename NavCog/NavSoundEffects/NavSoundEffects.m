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

#import "NavSoundEffects.h"

#define SUCCESS_URL
@interface NavSoundEffects ()

@property (nonatomic) SystemSoundID successSoundID;
@property (nonatomic) SystemSoundID clickSoundID;

@end

@implementation NavSoundEffects

+ (instancetype)getInstance {
    static NavSoundEffects *instance = nil;
    if (instance == nil) {
        instance = [[NavSoundEffects alloc] init];
        SystemSoundID tmp;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"click" ofType:@"wav"];
        NSURL* url = [NSURL fileURLWithPath:path];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &tmp);
        instance.clickSoundID = tmp;
        
        url = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/Modern/calendar_alert_chord.caf"];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)url,&tmp);
        instance.successSoundID = tmp;
    }
    return instance;
}

+ (void)playClickSound {
    NavSoundEffects *instance = [NavSoundEffects getInstance];
    AudioServicesPlaySystemSound(instance.clickSoundID);
}

+ (void)playSuccessSound {
    NavSoundEffects *instance = [NavSoundEffects getInstance];
    AudioServicesPlaySystemSound(instance.successSoundID);
}

+ (SystemSoundID)clickSoundID {
    NavSoundEffects *instance = [NavSoundEffects getInstance];
    return instance.clickSoundID;
}

+ (SystemSoundID)successSoundID {
    NavSoundEffects *instance = [NavSoundEffects getInstance];
    return instance.successSoundID;
}

@end
