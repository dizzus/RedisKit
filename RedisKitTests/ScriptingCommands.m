//
//  ScriptingCommands.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 02.08.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "RedisTestCase.h"

@interface ScriptingCommands : RedisTestCase
@end

@implementation ScriptingCommands

/*
 > eval "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second
 1) "key1"
 2) "key2"
 3) "first"
 4) "second"
 */
#pragma mark EVAL
- (void) test_EVAL {
    [self test: @"EVAL"];
    
    [[self.redis eval:@"return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" keys: @[@"key1", @"key2"] arguments: @[@"first", @"second"]] then:^id(id value) {
        NSArray* expected = @[@"key1", @"key2", @"first", @"second"];
        XCTAssertEqualObjects(value, expected);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark EVALSHA
- (void) test_EVALSHA {
    [self test: @"EVALSHA"];

    [[[self.redis scriptLoad:@"return \"Hello \" .. KEYS[1]"] then:^id(id value) {
        XCTAssertEqualObjects(value, @"9b21ca0cdbfcc6d54261391b4ab0808d4b068f05");
        return [self.redis evalsha:value keys:@[@"World"] arguments:@[]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello World");
        return [self passed];
    }];
    
    [self wait];
}



#pragma mark SCRIPT EXISTS
- (void) test_SCRIPT_EXISTS {
    [self test: @"SCRIPT EXISTS"];
    NSString* script = @"local msg=\"Hello World\"\r\nreturn msg";
    
    [[[[self.redis scriptExists: @"InvalidSHA"] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self.redis scriptLoad: script];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"a50c2366b7b1bc1c5f3b956c034e9710b805d05e");
        return [self.redis scriptExists: value];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SCRIPT FLUSH
- (void) test_SCRIPT_FLUSH {
    [self test: @"SCRIPT FLUSH"];
    NSString* script = @"local msg=\"Hello World\"\r\nreturn msg";
    __block NSString* sha = nil;
    
    [[[[[self.redis scriptLoad: script] then:^id(id value) {
        XCTAssertEqualObjects(value, @"a50c2366b7b1bc1c5f3b956c034e9710b805d05e");
        sha = value;
        return [self.redis scriptExists:value];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @1);
        return [self.redis scriptFlush];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"OK");
        return [self.redis scriptExists:sha];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @0);
        return [self passed];
    }];
    
    [self wait];
}

#pragma mark SCRIPT KILL
- (void) test_SCRIPT_KILL {
    [self test: @"SCRIPT FLUSH"];
    [self passed];
    [self wait];
}

#pragma mark SCRIPT LOAD
- (void) test_SCRIPT_LOAD {
    [self test: @"SCRIPT LOAD"];
    NSString* script = @"local msg=\"Hello World\"\r\nreturn msg";
    
    [[[self.redis scriptLoad: script] then:^id(id value) {
        XCTAssertEqualObjects(value, @"a50c2366b7b1bc1c5f3b956c034e9710b805d05e");
        return [self.redis evalsha:value keys:@[] arguments:@[]];
    }] then:^id(id value) {
        XCTAssertEqualObjects(value, @"Hello World");
        return [self passed];
    }];
    
    [self wait];
}


@end
