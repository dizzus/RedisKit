//
//  RedisTestCase.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 31.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RedisTestCase.h"


NSUInteger intVersion(NSString* strVer) {
    NSArray* items = [strVer componentsSeparatedByString:@"."];
    
    NSUInteger major = [items[0] integerValue];
    NSUInteger minor = [items[1] integerValue];
    NSUInteger patch = [items[2] integerValue];
    
    return (major << 24) | (minor << 16) | patch;
}

@implementation RedisTestCase

- (void) test: (NSString*)name {
    self.test = [self expectationWithDescription: name];
}

- (CocoaPromise*) test: (NSString*)name requires: (NSString*)ver {
    self.test = [self expectationWithDescription: name];
    
    CocoaPromise* promise = [CocoaPromise new];
    
    [[self.redis version] then:^id(id value) {
        NSUInteger serverVersion = intVersion(value);
        NSUInteger requiredVersion = intVersion(ver);
        
        if( serverVersion >= requiredVersion ) {
            [promise fulfill: [NSNumber numberWithInteger:serverVersion]];
        } else {
            [self.test fulfill];
            NSLog(@"Skipping %@: required v%@, server v%@", name, ver, value);
            [promise reject: [NSError errorWithDomain:@"Invalid server version" code:0 userInfo:@{@"Required version":ver, @"Server version":value}]];
        }
        
        return nil;
    }];
    
    return promise;
}

- (CocoaPromise*) passed {
    [self.test fulfill];
    return nil;
}

- (void) wait {
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        self.test = nil;
    }];
}

- (void)setUp {
    [super setUp];
    
    XCTestExpectation* exp = [self expectationWithDescription: @"Connecting"];
    self.redis = [CocoaRedis new];
    
    [[[[[self.redis connectWithHost: REDIS_ADDRESS] then:^id(id value) {
        return [self.redis select:15];
    }] then:^id(id value) {
        return [self.redis flushdb];
    }] then:^id(id value) {
        [exp fulfill];
        return nil;
    }] catch:^id(NSError *err) {
        XCTAssert(NO, @"setUp error: %@", err);
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError *error) {
        if(error) self.redis = nil;
    }];
    
    XCTAssertNotNil(self.redis, @"Cannection error");
}

- (void)tearDown {
    XCTestExpectation* exp = [self expectationWithDescription: @"Disconnecting"];

    [[[self.redis quit] then:^id(id value) {
        [exp fulfill];
        return nil;
    }] catch:^id(NSError *err) {
        [exp fulfill];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        self.redis = nil;
    }];

    [super tearDown];
}

- (NSString*)randomKey {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    return [@"__TestKey_" stringByAppendingString: uuid];
}

- (BOOL) isArray:(id)value {
    return [value isKindOfClass: [NSArray class]] || [value isKindOfClass:[NSMutableArray class]];
}

- (BOOL)isDictionary:(id)value {
    return [value isKindOfClass: [NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]];
}

- (BOOL)isBulkStringReply:(id)value {
    return [value isKindOfClass:[NSString class]] || value == [NSNull null];
}


@end
