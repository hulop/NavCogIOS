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
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "HULOPSetting.h"

@implementation HULOPSetting

- (id) init
{
    self = [super init];
    self.visible = true;
    return self;
}

- (void) save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (self.isList) {
        NSString *selected_key = [NSString stringWithFormat:@"selected_%@", self.name];
        NSString *list_key = [NSString stringWithFormat:@"%@_list", self.name];
        [ud setObject:self.selectedValue forKey: selected_key];
        [ud setObject:self.currentValue forKey: list_key];
    } else {
        [ud setObject:self.currentValue forKey: self.name];
    }
    [ud synchronize];
}

- (void)setHandler:(NSObject *(^)(NSObject *))_handler
{
    handler = _handler;
}

- (NSObject *)checkValue:(NSObject *)text
{
    if (!handler) {
        return text;
    }
    return handler(text);
}

- (NSInteger)numberOfRows
{
    if (self.isList) {
        return [((NSArray *) self.currentValue) count];
    }
    return 0;
}

- (NSInteger) selectedRow
{
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        for(int i = 0; i < [array count]; i++) {
            if ([[array objectAtIndex:i] isEqual:self.selectedValue]) {
                return i;
            }
        }
    }
    return -1;
}

-(NSString *)titleForRow: (NSInteger) row
{
    return [((NSArray *) self.currentValue) objectAtIndex: row];
}

- (void)addObject:(NSObject *)object
{
    if (self.isList) {
        self.currentValue = [((NSArray *) self.currentValue) arrayByAddingObject:object];
        self.selectedValue = object;
    }
}

- (void)removeSelected
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        if ([array count] <= 1) {
            return;
        }
        
        NSObject *select = nil, *last = nil;
        for(NSObject *obj in array) {
            if (![obj isEqual:self.selectedValue]) {
                [newArray addObject:obj];
            } else {
                if (last) {
                    select = last;
                }
            }
            last = obj;
        }
        if (!select) {
            select = [newArray firstObject];
        }
        self.selectedValue = select;
        self.currentValue = newArray;
    }
}

- (void)select:(NSInteger)row
{
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        self.selectedValue = [array objectAtIndex:row];
    }
}

- (float) floatValue
{
    if ([self.currentValue isKindOfClass:[NSNumber class]]) {
        return [(NSNumber*) self.currentValue floatValue];
    }
    return 0;
}

- (BOOL)boolValue
{
    if ([self.currentValue isKindOfClass:[NSNumber class]]) {
        return [(NSNumber*) self.currentValue boolValue];
    }
    return false;
}

- (NSString *)stringValue
{
    if ([self.currentValue isKindOfClass:[NSString class]]) {
        return (NSString*) self.currentValue;
    }
    return nil;
}


@end
