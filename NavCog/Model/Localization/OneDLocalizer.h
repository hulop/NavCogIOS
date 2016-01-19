//
//  OneDLocalizer.h
//  NavCog
//
//  Created by Daisuke Sato on 12/17/15.
//  Copyright © 2015 HULOP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NavLocalizer.h"
#include <bleloc/StreamParticleFilter.hpp>

#define Meter2Feet(meter) (meter/0.3048)
#define Feet2Meter(feet) (feet*0.3048)

@interface OneDLocalizer : NavLocalizer

@property loc::StreamParticleFilter *localizer;

- (void) initializeWithFile:(NSString*) path;
- (void) setBeacons:(NSDictionary*) beacons;

@end
