//
//  GeoCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 30.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

NSString* roundNumber(NSNumber* num, NSUInteger digits) {
    NSNumberFormatter *fmt = [NSNumberFormatter new];
    [fmt setNumberStyle: NSNumberFormatterDecimalStyle];
    [fmt setUsesGroupingSeparator: NO];
    [fmt setMaximumFractionDigits: digits];
    [fmt setMinimumFractionDigits: 0];
    return [fmt stringFromNumber: num];
}

NSString* rounded(double value) {
    return roundNumber( [NSNumber numberWithDouble: value], 5 );
}

BOOL isEqualGeopos(NSArray* p1, NSArray* p2) {
    if( [p1 isKindOfClass:[NSNull class]] && [p2 isKindOfClass:[NSNull class]] ) return YES;
    
    NSString* lon1 = roundNumber(p1[0], 5);
    NSString* lat1 = roundNumber(p1[1], 5);

    NSString* lon2 = roundNumber(p2[0], 5);
    NSString* lat2 = roundNumber(p2[1], 5);
    
    return [lon1 isEqualToString:lon2] && [lat1 isEqualToString:lat2];
}

@interface GeoCommands : RedisTestCase
@end

@implementation GeoCommands

/*
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEODIST Sicily Palermo Catania
 "166274.15156960039"
 redis> GEORADIUS Sicily 15 37 100 km
 1) "Catania"
 redis> GEORADIUS Sicily 15 37 200 km
 1) "Palermo"
 2) "Catania"
 redis>
 */
#pragma mark GEOADD
- (void) test_GEOADD {
    [[self test:@"GEOADD" requires:@"3.1.999"] then:^id(id unused) {

        const NSString* key = [self randomKey];
       
        return
        [[[[[self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis geodist:key from:@"Palermo" to:@"Catania"];
        }] then:^id(id value) {
            XCTAssertEqualObjects( roundNumber(value, 5), rounded(166274.15156960039) );
            return [self.redis georadius:key longitude:15 latitude:37 radius:100 unit:@"km"];
        }] then:^id(id value) {
            NSArray* expected = @[@"Catania"];
            XCTAssertEqualObjects(value, expected);
            return [self.redis georadius:key longitude:15 latitude:37 radius:200 unit:@"km"];
        }] then:^id(id value) {
            NSArray* expected = @[@"Palermo", @"Catania"];
            XCTAssertEqualObjects(value, expected);
            return [self passed];
        }];

    }];
    
    [self wait];
}

/*
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEOHASH Sicily Palermo Catania
 1) "sqc8b49rny0"
 2) "sqdtr74hyu0"
 redis>
 */
#pragma mark GEOHASH
- (void) test_GEOHASH {
    [[self test:@"GEOHASH" requires:@"3.1.999"] then:^id(id unused) {

        const NSString* key = [self randomKey];
        
        return
        [[[self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis geohash:key members:@[@"Palermo", @"Catania"]];
        }] then:^id(id value) {
            NSArray* expected = @[@"sqc8b49rny0", @"sqdtr74hyu0"];
            XCTAssertEqualObjects(value, expected);
            return [self passed];
        }];

    }];
    
    [self wait];
}

/*
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEOPOS Sicily Palermo Catania NonExisting
 1) 1) "13.361389338970184"
 2) "38.115556395496299"
 2) 1) "15.087267458438873"
 2) "37.50266842333162"
 3) (nil)
 redis>
 */
#pragma mark GEOPOS
- (void) test_GEOPOS {
    [[self test:@"GEOPOS" requires:@"3.1.999"] then:^id(id unused) {

        const NSString* key = [self randomKey];

        return
        [[[self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis geopos:key members:@[@"Palermo", @"Catania", @"NonExisting"]];
        }] then:^id(id value) {
            NSArray* expected = @[
                @[[NSNumber numberWithDouble:13.361389338970184], [NSNumber numberWithDouble:38.115556395496299]],
                @[[NSNumber numberWithDouble:15.087267458438873], [NSNumber numberWithDouble:37.50266842333162]],
                [NSNull null]
            ];
            for( NSUInteger i = 0; i < [value count]; ++i ) {
                XCTAssertTrue( isEqualGeopos(value[i], expected[i]) );
            }
            
            return [self passed];
        }];

    }];
    
    [self wait];
}

/*
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEODIST Sicily Palermo Catania
 "166274.15156960039"
 redis> GEODIST Sicily Palermo Catania km
 "166.27415156960038"
 redis> GEODIST Sicily Palermo Catania mi
 "103.31822459492736"
 redis> GEODIST Sicily Foo Bar
 (nil)
 redis>
 */
#pragma mark GEODIST
- (void) test_GEODIST {
    [[self test:@"GEODIST" requires:@"3.1.999"] then:^id(id unused) {
        
        const NSString* key = [self randomKey];

        return
        [[[[[[self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis geodist:key from:@"Palermo" to:@"Catania"];
        }] then:^id(id value) {
            XCTAssertEqualObjects( roundNumber(value, 5), rounded(166274.15156960039) );
            return [self.redis geodist:key from:@"Palermo" to:@"Catania" unit: @"km"];
        }] then:^id(id value) {
            XCTAssertEqualObjects( roundNumber(value, 5), rounded(166.27415156960038) );
            return [self.redis geodist:key from:@"Palermo" to:@"Catania" unit: @"mi"];
        }] then:^id(id value) {
            XCTAssertEqualObjects( roundNumber(value, 5), rounded(103.31822459492736) );
            return [self.redis geodist:key from:@"Foo" to:@"Bar"];
        }] then:^id(id value) {
            XCTAssertTrue( [value isKindOfClass:[NSNull class]] );
            return [self passed];
        }];
        
    }];
    
    [self wait];
}

/*
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEORADIUS Sicily 15 37 200 km WITHDIST
 1) 1) "Palermo"
 2) "190.4424"
 2) 1) "Catania"
 2) "56.4413"
 redis> GEORADIUS Sicily 15 37 200 km WITHCOORD
 1) 1) "Palermo"
 2) 1) "13.361389338970184"
 2) "38.115556395496299"
 2) 1) "Catania"
 2) 1) "15.087267458438873"
 2) "37.50266842333162"
 redis> GEORADIUS Sicily 15 37 200 km WITHDIST WITHCOORD
 1) 1) "Palermo"
 2) "190.4424"
 3) 1) "13.361389338970184"
 2) "38.115556395496299"
 2) 1) "Catania"
 2) "56.4413"
 3) 1) "15.087267458438873"
 2) "37.50266842333162"
 redis>
 */
#pragma mark GEORADIUS
- (void) test_GEORADIUS {
    [[self test:@"GEORADIUS" requires:@"3.1.999"] then:^id(id unused) {
        
        const NSString* key = [self randomKey];

        return
        [[[self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis georadius:key longitude:15 latitude:37 radius:200 unit: @"km" options:@[@"WITHDIST"]];
        }] then:^id(id value) {
            return [self passed];
        }];
     
    }];
    
    [self wait];
}

/*
 redis> GEOADD Sicily 13.583333 37.316667 "Agrigento"
 (integer) 1
 redis> GEOADD Sicily 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
 (integer) 2
 redis> GEORADIUSBYMEMBER Sicily Agrigento 100 km
 1) "Agrigento"
 2) "Palermo"
 redis>
 */
#pragma mark GEORADIUSBYMEMBER
- (void) test_GEORADIUSBYMEMBER {
    [[self test:@"GEORADIUSBYMEMBER" requires:@"3.1.999"] then:^id(id unused) {
        
        const NSString* key = [self randomKey];

        return
        [[[[self.redis geoadd:key longitude:13.583333 latitude:37.316667 member:@"Agrigento"] then:^id(id value) {
            XCTAssertEqualObjects(value, @1);
            return [self.redis geoadd:key values:@[@13.361389, @38.115556, @"Palermo", @15.087269, @37.502669, @"Catania"]];
        }] then:^id(id value) {
            XCTAssertEqualObjects(value, @2);
            return [self.redis georadiusbymember:key member:@"Agrigento" radius:100 unit: @"km"];
        }] then:^id(id value) {
            NSArray* expected = @[@"Agrigento", @"Palermo"];
            XCTAssertEqualObjects(value, expected);
            return [self passed];
        }];

    }];
        
    [self wait];
}


@end
