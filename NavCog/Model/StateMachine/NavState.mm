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



#import "NavState.h"
#import "NavCogFuncViewController.h"
#import "NavCogMainViewController.h"
#import "NavNotificationSpeaker.h"
#import "NavLog.h"
#import "NavUtil.h"

#define clipAngle2(angle) [NavUtil clipAngle2:(angle)]

@interface NavState ()

@property (nonatomic) Boolean bstarted;
@property (nonatomic) float preAnnounceDist;
@property (nonatomic) Boolean did40feet;
@property (nonatomic) Boolean didApproaching;
@property (nonatomic) Boolean didTrickyNotification;
@property (nonatomic) int longDistAnnounceCount;
@property (nonatomic) int targetLongDistAnnounceCount;
@property (strong, nonatomic) NSTimer *audioTimer;

@end

@implementation NavState

- (BOOL)isMeter {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"meter_preference"];
}

- (int)toMeter:(int) feet {
    return (int)(((float)feet * 0.3048) + 0.5f);
}

- (float)getStartDistance:(NavLocation*)pos {
    return (_ty > _sy ? 1 : -1) * (pos.yInEdge - _sy);
}

- (float)getTargetDistance:(NavLocation*)pos {
    return (_ty > _sy ? 1 : -1) * (_ty - pos.yInEdge);
}

- (float)getStartRatio:(NavLocation*)pos {
    return [self getStartDistance:pos] / ABS(_ty - _sy);
}

- (float)getTargetRatio:(NavLocation*)pos {
    return [self getTargetDistance:pos] / ABS(_ty - _sy);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _bstarted = false;
        _preAnnounceDist = INT_MAX;
        _did40feet = false;
        _didApproaching = false;
        _nextState = nil;
        _isTricky = false;
        _didTrickyNotification = false;
        _isFirst = NO;
        _closestDist = INT_MAX;
    }
    return self;
}

- (void)setWalkingEdge:(NavEdge *)walkingEdge {
    _walkingEdge = walkingEdge;
    _preAnnounceDist = walkingEdge.len;
    _longDistAnnounceCount = _preAnnounceDist / 30;
    if (ABS(walkingEdge.len - _longDistAnnounceCount * 30) <= 10) {
        _longDistAnnounceCount --;
    }
    _targetLongDistAnnounceCount = _longDistAnnounceCount;
}

- (Boolean)checkStateStatusUsingLocationManager:(NavCurrentLocationManager *)man withSpeechOn:(Boolean)isSpeechEnabled withClickOn:(Boolean)isClickEnabled {
    if (!_bstarted) {
        _bstarted = true;
        if (_type == STATE_TYPE_WALKING && _walkingEdge.len < 40) {
            _did40feet = true;
        }
        
        // if the distance is less than 30, then it's not necessary to announce 20
        if (_type == STATE_TYPE_WALKING && _walkingEdge.len <= 20) {
            _didApproaching = true;
        }

        
        float oridiff = clipAngle2(_ori - man.currentOrientation);
        NSMutableDictionary *options = [@{@"sx": @(_sx), @"sy": @(_sy), @"tx": @(_tx), @"ty": @(_ty), @"first": @(_isFirst), @"oridiff": @(oridiff)} mutableCopy];
        if (_type == STATE_TYPE_TRANSITION) {
            options[@"type"] = @"transition";
            [man initLocalizationOnEdge:_targetEdge.edgeID withOptions:options];
        } else {
            [man initLocalizationOnEdge:_walkingEdge.edgeID withOptions:options];
        }
        
        [self speakInstructionImmediately:_stateStartInfo];
        if (_type == STATE_TYPE_TRANSITION || isClickEnabled) {
            _audioTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(playClickSound) userInfo:nil repeats:YES];
            [_audioTimer fire];
        }
        return false;
    }
    // get position and push to visual map

    NavLocation *pos;
    if (_type == STATE_TYPE_WALKING) {
        pos = [man getLocationOnEdge:_walkingEdge.edgeID];
        float cx = pos.xInEdge;
        float cy = pos.yInEdge;
        float slat = _startNode.lat;
        float slng = _startNode.lng;
        float tlat = _targetNode.lat;
        float tlng = _targetNode.lng;
        
        /*
        float dlat = tlat - slat;
        float dlng = tlng - slng;
        float dx = _tx - _sx;
        float dy = _ty - _sy;
        
        float px = cx - _sx;
        float py = cy - _sy;
        */
        
        float distStartTarget = sqrtf(powf(_tx-_sx,2)+powf(_ty-_sy, 2));
        float distStartCurrent = sqrtf(powf(cx-_sx,2)+powf(cy-_sy,2));
        //float ratio = (cy - _sy) / (_ty - _sy); //1D
        float ratio = distStartCurrent/distStartTarget; //2D
        printf("ratio=%f\n",ratio);
        ratio = ratio < 0 ? 0 : ratio;
        ratio = ratio > 1 ? 1 : ratio;
        float lat = slat + ratio * (tlat - slat);
        float lng = slng + ratio * (tlng - slng);
        NSString *cmd = [NSString stringWithFormat:@"updateBlueDot({lat:%f, lng:%f})", lat, lng];
        [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
    }else {
        pos = [man getLocationOnEdge:_targetEdge.edgeID];
    }
    
    NSMutableArray *data = [[NSMutableArray alloc] init];
    NavEdge *edge = _type == STATE_TYPE_WALKING ? _walkingEdge : _targetEdge;
    [data addObject:[NSNumber numberWithFloat:ABS(pos.yInEdge - _ty)]];
    [data addObject:[NSNumber numberWithFloat:edge.len]];
    [data addObject:edge.edgeID];
    [data addObject:[NSNumber numberWithFloat:pos.xInEdge]];
    [data addObject:[NSNumber numberWithFloat:pos.yInEdge]];
    [data addObject:[NSNumber numberWithFloat:pos.knndist]];
    [NavLog logArray:data withType:@"CurrentPosition"];
    
    
    float dist = sqrtf((pos.xInEdge - _tx) * (pos.xInEdge - _tx) + (pos.yInEdge - _ty) * (pos.yInEdge - _ty)); // use this if you use 2d
    //float dist = ABS(pos.y - _ty); // use this if you use 1d, x has no affects
    if (dist < 50 && _isTricky && !_didTrickyNotification) {
        _didTrickyNotification = true;
        [NavNotificationSpeaker speakImmediatelyAndSlowly:NSLocalizedString(@"accessNotif", @"Alert that an accessibility notification is available")];
    }
    float threshold = 5;
    if (_type == STATE_TYPE_WALKING) {
        // snap y within edge
        float targetDist = [self getTargetDistance:pos];
        if (targetDist < 0) {
            NSLog(@"SnapDistance,%f",targetDist);
            dist = 0;
        }
        
        _closestDist = MIN(dist, _closestDist);
        if(dist > 0 && _didApproaching && _nextState != nil && _nextState.type == STATE_TYPE_WALKING) {
            // check if we already on the next edge
            NavEdge *nextEdge = _nextState.walkingEdge;
            NavLocation *nextPos = [man getLocationOnEdge:nextEdge.edgeID];

            double norm_dist = (nextPos.knndist - nextEdge.minKnnDist) / (nextEdge.maxKnnDist - nextEdge.minKnnDist);
            
            float nextStartDist = [_nextState getStartDistance:nextPos];
            float nextStartRatio = [_nextState getStartRatio:nextPos];
            if (norm_dist <= 1 && (nextStartDist > 25 || (nextStartDist > 10 && nextStartRatio > 0.25))) {
                NSLog(@"ForceNextState,%f,%f,%f,%f",_closestDist, pos.knndist, nextStartDist, nextPos.knndist);
                dist = 0;
            }
        }
        
        NSString *distFormat = NSLocalizedString([self isMeter]?@"meterFormat":@"feetFormat", @"Use to express a distance in feet");
        // if you're walking, check distance to target node
        if (dist < _preAnnounceDist) {
            if (dist > 40.0) { // announce every 30 feet
                if (dist <= 30 * _longDistAnnounceCount + threshold) {
                    NSString *ann = [NSString stringWithFormat:distFormat,[self isMeter]?[self toMeter:_longDistAnnounceCount * 30]:_longDistAnnounceCount * 30];
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:ann];
                    } else {
                        _previousInstruction = ann;
                    }
                    _preAnnounceDist = _longDistAnnounceCount * 30;
                    _longDistAnnounceCount --;
                    return false;
                }
            } else if (!_did40feet && dist <= 40 + threshold) {
                NSString *ann = [NSString stringWithFormat:distFormat,[self isMeter]?[self toMeter:40]:40];
                if (isSpeechEnabled) {
                    [self speakInstructionImmediately:ann];
                } else {
                    _previousInstruction = ann;
                }
                _preAnnounceDist = 40;
                _did40feet = true;
                return false;
            } else if (!_didApproaching && dist <= MIN(20 + threshold, _walkingEdge.len / 2)) {
                if (isClickEnabled) {
                    [self stopAudios];
                    _audioTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(playClickSound) userInfo:nil repeats:YES];
                    [_audioTimer fire];
                }
                if (_approachingInfo != nil) {
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:_approachingInfo];
                    } else {
                        _previousInstruction = _approachingInfo;
                    }
                } else {
                    NSString *approaching = NSLocalizedString(@"approaching", @"Spoken when approaching specific nodes");
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:approaching];
                    } else {
                        _previousInstruction = approaching;
                    }
                }
                _didApproaching = true;
                return false;
            } else if (dist <= 2 + threshold) {
                _bstarted = false;
                _longDistAnnounceCount = _targetLongDistAnnounceCount;
                _did40feet = _walkingEdge.len < 40 ? true : false;
                _didApproaching = _walkingEdge.len < 20 ? true : false;
                [self stopAudios];
                if (_arrivedInfo != nil) {
                    [self speakInstructionImmediately:_arrivedInfo];
                }
                NSString *cmd = [NSString stringWithFormat:@"updateBlueDot({lat:%f, lng:%f})", _targetNode.lat, _targetNode.lng];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                return true;
            }
        }
    } else if (_type == STATE_TYPE_TRANSITION) {
        pos.knndist = (pos.knndist - _targetEdge.minKnnDist) / (_targetEdge.maxKnnDist - _targetEdge.minKnnDist);
/*        if (_prevState != nil && _prevState.type == STATE_TYPE_WALKING) {
            float nextKnndist = pos.knndist;
            // compare knn distance to previous and next edge
            NavEdge *prevEdge = _prevState.walkingEdge;
            struct NavPoint prevPos = [prevEdge getCurrentPositionInEdgeUsingBeacons:beacons];
            float prevKnndist = (prevPos.knndist - prevEdge.minKnnDist) / (prevEdge.maxKnnDist - prevEdge.minKnnDist);
            float nearRatio = MAX(0.25, nextKnndist / prevKnndist);
            if (nearRatio < 1.0) {
                // Adjust dist and knndist
                float orgDist = dist, orgKnndist = pos.knndist;
                dist *= (nearRatio * 1.0);
                pos.knndist *= (nearRatio * 1.0);
                NSLog(@"BoostTransition,%f,%f,%f,%f,%f,%f,%f)",nearRatio, prevKnndist, nextKnndist, orgDist, orgKnndist ,dist, pos.knndist);
            }
        }*/
//        pos.knndist = pos.knndist < 0 ? 0 : pos.knndist;
//        pos.knndist = pos.knndist > 1 ? 1 : pos.knndist;
        
        NSLog(@"type=%d pos(%f, %f) target(%f, %f) likelihood=%f threth=%f dist=%f threth=%f", _type, pos.xInEdge, pos.yInEdge, _tx, _ty, pos.knndist, _targetNode.transitKnnDistThres, dist, _targetNode.transitPosThres);

        if (_targetNode.type == NODE_TYPE_DOOR_TRANSIT || _targetNode.type == NODE_TYPE_STAIR_TRANSIT) {
            if (pos.knndist < _targetNode.transitKnnDistThres && dist < _targetNode.transitPosThres) {
                NSString *cmd = [NSString stringWithFormat:@"switchToLayerWithID('%@')", _targetNode.layerZIndex];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                [self stopAudios];
                return true;
            }
            return false;
        } else if (_targetNode.type == NODE_TYPE_ELEVATOR_TRANSIT) {
            if (pos.knndist < _targetNode.transitKnnDistThres) {
                NSString *cmd = [NSString stringWithFormat:@"switchToLayerWithID('%@')", _targetNode.layerZIndex];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                [self stopAudios];
                return true;
            }
            return false;
        }
    }
    return false;
}

- (void)repeatPreviousInstruction {
    if (_previousInstruction != nil) {
        [self speakInstructionImmediately:[self getPreviousInstruction]];
    }
}

- (void)announceSurroundInfo {
    [NavNotificationSpeaker speakImmediatelyAndSlowly:[self getSurroundInfo]];
}

- (void)announceAccessibilityInfo {
    if (_trickyInfo != nil) {
        [NavNotificationSpeaker speakImmediatelyAndSlowly:[self getAccessibilityInfo]];
    }
}

- (NSString*)getPreviousInstruction {
    if (_previousInstruction != nil) {
        NSString *unit = NSLocalizedString([self isMeter]?@"meter":@"feet", @"A unit of distance in feet");
        NSUInteger numLen = [_previousInstruction length] - [unit length] - 1;
        if ([_previousInstruction containsString:unit] && (numLen == 1 || numLen == 2 || numLen == 3)) {
            return [NSString stringWithFormat:NSLocalizedString(@"andFormat", @"Used to join two instructions"), _previousInstruction, _nextActionInfo];
        }
    }
    return _previousInstruction;
}

- (NSString*)getSurroundInfo {
    if ([_surroundInfo isEqualToString:@""]) {
        return NSLocalizedString(@"noInformation", @"Spoken when no information is available");
    }
    return _surroundInfo;
}

- (NSString*)getAccessibilityInfo {
    return _trickyInfo;
}

- (void)playClickSound {
    [NavSoundEffects playClickSound];
}

- (void)stopAudios {
    if (_audioTimer != nil) {
        [_audioTimer invalidate];
        _audioTimer = nil;
    }
}

- (void)speakInstruction:(NSString *)str {
    _previousInstruction = str;
    [NavNotificationSpeaker speakWithCustomizedSpeed:str];
}

- (void)speakInstructionImmediately:(NSString *)str {
    _previousInstruction = str;
    [NavNotificationSpeaker speakWithCustomizedSpeedImmediately:str];
}

@end
