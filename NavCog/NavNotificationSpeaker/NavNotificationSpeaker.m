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
 *******************************************************************************/

#import "NavNotificationSpeaker.h"
#import <AVFoundation/AVFoundation.h>
@import UIKit;


#define IS_IOS_9 ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion == 9)

@interface NavNotificationSpeaker ()

@property (strong, nonatomic) AVSpeechSynthesizer *avSpeaker;
@property (nonatomic) Boolean beFast;
@property (nonatomic) float fastRatio;
@property (nonatomic) float slowRatio;
@property (nonatomic) AVSpeechSynthesisVoice *voice;

@end

@implementation NavNotificationSpeaker

+ (instancetype)getInstance {
    static NavNotificationSpeaker *instance = nil;
    if (instance == nil) {
        instance = [[NavNotificationSpeaker alloc] init];
        instance.avSpeaker = [[AVSpeechSynthesizer alloc] init];
        instance.beFast = true;
        instance.fastRatio = IS_IOS_9 ? 1.7 : 4;
        instance.slowRatio = IS_IOS_9 ? 1.9 : 8;
        instance.voice = self.getVoice;
    }
    return instance;
}

+ (AVSpeechSynthesisVoice*)getVoice {
    // From http://stackoverflow.com/a/23826135/427299
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    NSString *voiceLangCode = [AVSpeechSynthesisVoice currentLanguageCode];
    if (![voiceLangCode hasPrefix:language]) {
        // the default voice can't speak the language the text is localized to;
        // switch to a compatible voice:
        NSArray *speechVoices = [AVSpeechSynthesisVoice speechVoices];
        for (AVSpeechSynthesisVoice *speechVoice in speechVoices) {
            if ([speechVoice.language hasPrefix:language]) {
                voiceLangCode = speechVoice.language;
                break;
            }
        }
    }
    return [AVSpeechSynthesisVoice voiceWithLanguage:voiceLangCode];
}

+ (void)setFastSpeechOnAndOff:(Boolean)isFast {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    instance.beFast = isFast;
}

+ (void)speakWithCustomizedSpeed:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    if (instance.beFast) {
        [instance selfSpeak:str];
    } else {
        [instance selfSpeakSlowly:str];
    }
}

+ (void)speakWithCustomizedSpeedImmediately:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    if (instance.beFast) {
        [instance selfSpeakImmediately:str];
    } else {
        [instance selfSpeakImmediatelyAndSlowly:str];
    }
}

+ (void)speakImmediately:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    [instance selfSpeakImmediately:str];
}

+ (void)speak:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    [instance selfSpeak:str];
}

+ (void)speakImmediatelyAndSlowly:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    [instance selfSpeakImmediatelyAndSlowly:str];
}

+ (void)speakSlowly:(NSString *)str {
    NavNotificationSpeaker *instance = [NavNotificationSpeaker getInstance];
    [instance selfSpeakSlowly:str];
}

- (void)selfSpeakImmediately:(NSString *)str {
    if ([self speakViceover:str]) {
        return;
    }
    if (_avSpeaker.speaking) {
        [_avSpeaker stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    AVSpeechUtterance *avUtterance = [[AVSpeechUtterance alloc] initWithString:str];
    [avUtterance setRate:AVSpeechUtteranceMaximumSpeechRate / _fastRatio];
    [avUtterance setVoice:_voice];
    [avUtterance setVolume:1.0];
    [avUtterance setPitchMultiplier:1.0];
    [_avSpeaker speakUtterance:avUtterance];
    NSLog(@"SpeakImmediately : %@", str);
}

- (void)selfSpeak:(NSString *)str {
    if ([self speakViceover:str]) {
        return;
    }
    AVSpeechUtterance *avUtterance = [[AVSpeechUtterance alloc] initWithString:str];
    [avUtterance setRate:AVSpeechUtteranceMaximumSpeechRate / _fastRatio];
    [avUtterance setVoice:_voice];
    [avUtterance setVolume:1.0];
    [avUtterance setPitchMultiplier:1.0];
    [_avSpeaker speakUtterance:avUtterance];
    NSLog(@"Speak : %@", str);
}

- (void)selfSpeakImmediatelyAndSlowly:(NSString *)str {
    if ([self speakViceover:str]) {
        return;
    }
    if (_avSpeaker.speaking) {
        [_avSpeaker stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    AVSpeechUtterance *avUtterance = [[AVSpeechUtterance alloc] initWithString:str];
    [avUtterance setRate:AVSpeechUtteranceMaximumSpeechRate / _slowRatio];
    [avUtterance setVoice:_voice];
    [avUtterance setVolume:1.0];
    [avUtterance setPitchMultiplier:1.0];
    [_avSpeaker speakUtterance:avUtterance];
    NSLog(@"SpeakImmediatelyAndSlowly : %@", str);
}

- (void)selfSpeakSlowly:(NSString *)str {
    if ([self speakViceover:str]) {
        return;
    }
    AVSpeechUtterance *avUtterance = [[AVSpeechUtterance alloc] initWithString:str];
    [avUtterance setRate:AVSpeechUtteranceMaximumSpeechRate / _slowRatio];
    [avUtterance setVoice:_voice];
    [avUtterance setVolume:1.0];
    [avUtterance setPitchMultiplier:1.0];
    [_avSpeaker speakUtterance:avUtterance];
    NSLog(@"SpeakSlowly : %@", str);
}

- (BOOL)speakViceover:(NSString *)str {
    if ([str length] == 0 || !UIAccessibilityIsVoiceOverRunning()) {
        return NO;
    }
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, str);
    NSLog(@"SpeakVoiceover : %@", str);
    return YES;
}

@end
