//
//  PubSubCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 02.08.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface PubSubCommands : RedisTestCase
@end

@implementation PubSubCommands

#pragma mark PSUBSCRIBE
- (void) test_PSUBSCRIBE {
    [self test: @"PSUBCRIBE"];
    
    __block id observer = nil;
    __block NSInteger helloCount = 0;

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost: @"localhost"] then:^id(id value) {
        return [listener psubscribePatterns: @[@"test0.*", @"test1.*"]];
    }] then:^id(id value) {
        NSString* pat = value[@"pattern"];
        XCTAssertTrue( [pat isEqualToString:@"test0.*"] || [pat isEqualToString:@"test1.*"] );
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* message = notification.userInfo[@"message"];
                        if( [message isEqualToString:@"Hello"] ) ++helloCount;
                    }];

        return [self.redis publish:@"test0.a" message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        
        return [self.redis publish:@"test1.b" message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [listener punsubscribe];
    }] then:^id(id value) {
        return [listener close];
    }] then:^id(id value) {
        NSNotificationCenter *center;
        [center removeObserver: observer];

        XCTAssertEqual(helloCount, 2);
        return [self passed];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark PUBSUB
- (void) test_PUBSUB {
    [self test: @"PUBSUB"];
    
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[[listener connectWithHost:@"localhost"] then:^id(id value) {
        return [listener subscribe:@"test"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"channel"], @"test");
        return [listener psubscribe:@"news.*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], @"news.*");
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSArray* expected = @[@"test"];
        XCTAssertEqualObjects(value, expected);
        return [self.redis pubsubSubscribers: @[@"test"]];
    }] then:^id(id value) {
        NSDictionary* expected = @{@"test": @1};
        XCTAssertEqualObjects(value, expected);
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self passed];
    }] then:^id(id value) {
        // return [listener close];
        return nil;
    }];
    
    [self wait];
}

#pragma mark PUBLISH
- (void) test_PUBLISH {
    [self test: @"PUBLISH"];

    __block id observer = nil;
    __block NSInteger helloCount = 0;

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[listener connectWithHost:@"localhost"] then:^id(id value) {
        return [listener subscribe:@"test"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"channel"], @"test");

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* message = notification.userInfo[@"message"];
                        if( [message isEqualToString:@"Hello"] ) ++helloCount;
                    }];
     
        return [self.redis publish:@"test" message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis publish:@"test" message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSNotificationCenter *center;
            [center removeObserver: observer];
            
            XCTAssertEqual(helloCount, 2);
            [self passed];
        });

        // return [listener close];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

#pragma mark PUNSUBSCRIBE
- (void) test_PUNSUBSCRIBE {
    [self test: @"PUNSUBSCRIBE"];

    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost:@"localhost"] then:^id(id value) {
        return [listener psubscribe: @"news.*"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], @"news.*");
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [listener punsubscribe];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value[@"pattern"], @"news.*");
        return [self.redis pubsubPatternsCount];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }] then:^id(id value) {
        // return [listener close];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}


#pragma mark SUBSCRIBE
- (void) test_SUBSCRIBE {
    [self test: @"SUBCRIBE"];
    
    __block id observer = nil;
    __block NSInteger count = 0;
    
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[listener connectWithHost:@"localhost"] then:^id(id value) {
        return [listener subscribeChannels: @[@"test1", @"test2"]];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:@"test1"] || [ch isEqualToString:@"test2"] );

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        observer = [center addObserverForName: CocoaRedisMessageNotification
                                       object: nil
                                        queue: nil
                                   usingBlock: ^(NSNotification *notification)
                    {
                        NSString* chn = notification.userInfo[@"channel"];
                        NSString* msg = notification.userInfo[@"message"];
                   
                        if( [chn isEqualToString:@"test1"] && [msg isEqualToString:@"Hello"] ) ++count;
                        if( [chn isEqualToString:@"test2"] && [msg isEqualToString:@"World"] ) ++count;
                    }];
    
        return [self.redis publish:@"test1" message:@"Hello"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);

        return [self.redis publish:@"test2" message:@"World"];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            XCTAssertTrue(count == 2);

            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center removeObserver: observer];

            [self passed];
        });

        // return [listener close];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}


#pragma mark UNSUBSCRIBE
- (void) test_UNSUBSCRIBE {
    [self test: @"UNSUBSCRIBE"];
    
    CocoaRedis* listener = [CocoaRedis new];
    
    [[[[[[[listener connectWithHost:@"localhost"] then:^id(id value) {
        return [listener subscribeChannels: @[@"test1", @"test2"]];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:@"test1"] || [ch isEqualToString:@"test2"] );
        
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSSet* expected = [NSSet setWithArray: @[@"test1", @"test2"]];
        XCTAssertTrue( [expected isSubsetOfSet: [NSSet setWithArray:value]] );
        
        return [listener unsubscribe];
    }] then:^id(id value) {
        NSString* ch = value[@"channel"];
        XCTAssertTrue( [ch isEqualToString:@"test1"] || [ch isEqualToString:@"test2"] );
        
        return [self.redis pubsubActiveChannels];
    }] then:^id(id value) {
        NSArray* expected = @[];
        XCTAssertEqualObjects(value, expected);
        
        return [self passed];
    }] then:^id(id value) {
        return [listener close];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

@end
