//
//  CocoaRedis.m
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 20.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CocoaRedis.h"

#include "macosx.h"

NSString * const CocoaRedisMonitorNotification = @"CocoaRedisMonitorNotification";
NSString * const CocoaRedisMessageNotification = @"CocoaRedisMessageNotification";

static void connectCallback(redisAsyncContext *ctx, int status) {
    CocoaPromise* promise = CFBridgingRelease(ctx->data);
    ctx->data = NULL;

    if( status != REDIS_OK ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: ctx->errstr]
                                           code: ctx->err
                                       userInfo: nil];
        [promise reject: err];
    } else {
        [promise fulfill: nil];
    }
}

/*
    subscribe -> immediate close -> problems ???
    because ctx->data = subscribe promise
 */
static void disconnectCallback(redisAsyncContext *ctx, int status) {
    if( ctx->data ) {
        CocoaPromise* promise = CFBridgingRelease(ctx->data);

        if( status != REDIS_OK ) {
            NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: ctx->errstr]
                                               code: ctx->err
                                           userInfo: nil];
            [promise reject: err];
        } else {
            [promise fulfill: nil];
        }
    }
}

static id parseReply(redisReply* reply) {
    NSCAssert(reply != NULL, @"NULL reply");
    
    switch(reply->type) {
        case REDIS_REPLY_ERROR:
            return [NSError errorWithDomain: [NSString stringWithUTF8String: reply->str] code:0 userInfo:nil];
            
        case REDIS_REPLY_STATUS:
            return [NSString stringWithUTF8String: reply->str];
            
        case REDIS_REPLY_STRING: {
            NSData* data = [NSData dataWithBytes: reply->str length: reply->len];
            NSString* utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            return utf8 ? utf8 : data;
        }
            
        case REDIS_REPLY_ARRAY: {
            NSMutableArray* replies = [NSMutableArray arrayWithCapacity: reply->elements];
            for(int i = 0; i < reply->elements; ++i ) {
                if( reply->element[i] != NULL ) {
                    [replies addObject: parseReply(reply->element[i])];
                } else {
                    [replies addObject: [NSNull null]];
                }
            }
            return replies;
        }
            
        case REDIS_REPLY_INTEGER:
            return [NSNumber numberWithLongLong: reply->integer];
            
        case REDIS_REPLY_NIL:
            return [NSNull null];
            
        default: {
            NSCAssert(NO, @"Unknown server reply type");
            break;
        }
    }
    
    return nil;
}

static void commandCallback(redisAsyncContext *context, void *reply, void *privdata) {
    CocoaPromise* promise = CFBridgingRelease(privdata);

    if( context->err ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: context->errstr]
                                           code: context->err
                                       userInfo: nil];
        [promise reject: err];
        return;
    }
    
    if( reply != NULL  ) {
        id result = parseReply(reply);

        if( !result ) {
            [promise reject: [NSError errorWithDomain: @"Cannot parse reply" code:0 userInfo:nil]];
        } else {
            [promise fulfill: result];
        }
    }
}

inline static const char* skipUpToChar(const char* str, char ch) {
    while( *str && *str != ch ) ++str;
    NSCAssert(*str, @"Invalid input string");
    return str;
}

inline static const char* scanNSUInteger(const char* p, NSUInteger* result) {
    NSUInteger value = 0;
    
    while( isdigit(*p) ) {
        value = value * 10 + (*p++ - '0');
    }
    
    if(result) *result = value;
    
    return p;
}

inline static const char* scanCString(const char* p, id __autoreleasing *result) {
    NSCAssert(*p++ == '"', @"Invalid string");
    
    NSMutableData* buffer = [NSMutableData new];
    const char* hexDigits = "0123456789abcdef";
    
    while( *p && *p != '"' ) {
        if( *p++ != '\\' ) {
            [buffer appendBytes:(p - 1) length:1];
            continue;
        }
        
        switch( *p++ ) {
            case '"': case '\\':
                [buffer appendBytes:(p - 1) length:1];
            break;
                
            case 'x': case 'X': {
                unsigned char code = 0;
                
                while( isxdigit(*p) ) {
                    const char* digit = strchr(hexDigits, tolower(*p++));
                    NSCAssert(digit != NULL, @"Invalid hex number");
                    code = code * 16 + (unsigned char)(digit - hexDigits);
                }
                
                [buffer appendBytes: &code length:1];
            }
            break;
                
            default: break;
        }
    }
    
    NSCAssert(*p == '"', @"Unterminated string");
    
    if( result ) {
        NSString* utf8 = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
        *result = utf8 ? utf8 : [NSData dataWithData: buffer];
    }
    
    return p;
}

static const char* scanTimestamp(const char* p, NSDate* __autoreleasing *result) {
    NSUInteger seconds = 0;
    const char* q = scanNSUInteger(p, &seconds);
    NSCAssert(*q == '.', @"Invalid timestamp");
    
    NSUInteger millis = 0;
    q = scanNSUInteger(q + 1, &millis);
    
    if(result) {
        double timestamp = (double)seconds + (double) millis / 1000000.0;
        *result = [NSDate dateWithTimeIntervalSince1970: timestamp];
    }
    
    return q;
}

/* 
      Timestamp       Db      Address      Command  Arg0     Arg1...
   |+++++++++++++++|  |+| |+++++++++++++|  |++++++| |+++++| |++++++|
   1438808382.449497 [123 127.0.0.1:54710] "append" "Hello" " Wolrd" 

 */
static NSDictionary* parseMonitorString(NSString* string) {
    const char* cstr = [string cStringUsingEncoding: NSUTF8StringEncoding];
    NSData* data = [NSData dataWithBytes:cstr length: strlen(cstr) + 1];

    // timestamp
    const char* p = (char*) data.bytes;
    NSDate* timestamp = nil;
    const char* q = scanTimestamp(p, &timestamp);
 
    // db
    p = q + 1;
    NSCAssert(*p == '[', @"Invalid input");
    NSUInteger db = 0;
    q = scanNSUInteger(p + 1, &db);
    
    // address
    p = q + 1;
    q = skipUpToChar(p, ']');
    NSString* addr = [[NSString alloc] initWithBytes:p length:(q - p) encoding:NSUTF8StringEncoding];
    
    // command
    NSCAssert(*(q + 2) == '"', @"Invalid input");
    p = q + 3;
    q = skipUpToChar(p, '"');
    NSString* command = [[NSString alloc] initWithBytes:p length:(q - p) encoding:NSUTF8StringEncoding];
    
    NSMutableArray* args = [NSMutableArray new];
    
    // command with args?
    if( *(q + 1) == ' ') {
        do {
            id arg = nil;
            q = scanCString(q + 2, &arg);
            
            [args addObject: arg];
        } while( *(q + 1) == ' ');
    }

    return @{
        @"time": timestamp,
        @"db": [NSNumber numberWithUnsignedInteger: db],
        @"address": addr,
        @"command": command,
        @"arguments": args
    };
}

static void monitorCallback(redisAsyncContext *context, void *reply, void *privdata) {
    id result = nil;

    CocoaPromise* promise = nil;
    if( context->data != NULL ) {
        promise = CFBridgingRelease(context->data);
        context->data = NULL;
    }

    if( reply == nil ) {
        return;
    }

    if( (result = parseReply(reply)) == nil ) {
        [promise reject: [NSError errorWithDomain:@"Error getting monitor reply" code:0 userInfo:nil]];
    } else if( [result isEqualToString: @"OK"] ) {
        [promise fulfill: @YES];
    } else {
        NSDictionary* info = parseMonitorString( result );
        [[NSNotificationCenter defaultCenter] postNotificationName:CocoaRedisMonitorNotification object:nil userInfo:info];
    }
}

static void subscribeCallback(redisAsyncContext *context, void *reply, void *privdata) {
    id result = nil;
    
    CocoaPromise* promise = nil;
    if( context->data != NULL ) {
        promise = CFBridgingRelease(context->data);
        context->data = NULL;
    }

    if( reply == NULL ) {
        return;
    }

    if( (result = parseReply(reply)) == nil ) {
        [promise reject: [NSError errorWithDomain:@"Error getting subscribe reply" code:0 userInfo:nil]];
        return;
    }
    
    NSString* command = result[0];
    
    if( ([command isEqualToString:@"psubscribe"] || [command isEqualToString:@"punsubscribe"]) ) {
        NSDictionary* info = @{@"pattern": result[1], @"count": result[2]};
        [promise fulfill: info];
    } else
        
    if( ([command isEqualToString: @"subscribe"] || [command isEqualToString:@"unsubscribe"]) ) {
        NSDictionary* info = @{@"channel": result[1], @"count": result[2]};
        [promise fulfill: info];
    } else

    if( [command isEqualToString:@"message"] ) {
        NSDictionary* info = @{@"channel": result[1], @"message": result[2]};
        [[NSNotificationCenter defaultCenter] postNotificationName:CocoaRedisMessageNotification object:nil userInfo:info];
    } else

    if( [command isEqualToString:@"pmessage"] ) {
        NSDictionary* info = @{@"pattern": result[1], @"channel": result[2], @"message": result[3]};
        [[NSNotificationCenter defaultCenter] postNotificationName:CocoaRedisMessageNotification object:nil userInfo:info];
    }
    
    else {
        NSCAssert(NO, [@"Subscribe callback. Invalid command: " stringByAppendingString: command]);
    }
}

static inline CocoaPromise* PromiseNSDict(CocoaPromise* promise, id(^mutator)(id)) {
    return [promise then:^id(id value) {
        NSUInteger count = [value count];
        if( count == 0 ) return [NSDictionary new];
        
        NSMutableDictionary* result = [NSMutableDictionary new];
        for( int i = 0; i < count; i += 2 ) {
            id obj = mutator ? mutator(value[i+1]) : value[i+1];
            [result setObject:obj forKey:value[i]];
        }
        
        return result;
    }];
}

static id (^toDouble)(id) = ^id(id value) {
    if( value == [NSNull null] ) return value;
    double dv = [value doubleValue];
    return [NSNumber numberWithDouble: dv];
};

static id (^toLongLong)(id) = ^id(id value) {
    if( value == [NSNull null] ) return value;
    long long lv = [value longLongValue];
    return [NSNumber numberWithLongLong: lv];
};

static id (^toNSSet)(id) = ^id(id value) {
    if( value == [NSNull null] ) return value;
    return [NSSet setWithArray: value];
};

static id (^toGeoPos)(id) = ^id(id value) {
    if( value == [NSNull null] ) return value;

    NSMutableArray* result = [NSMutableArray new];
    if( [value count] == 0 ) return result;
    
    for( NSArray* row in value ) {
        if( (id)row == [NSNull null] ) {
            [result addObject: row];
        } else {
            double lon = [row[0] doubleValue];
            double lat = [row[1] doubleValue];
            [result addObject: @[[NSNumber numberWithDouble:lon], [NSNumber numberWithDouble:lat]]];
        }
    }
    
    return result;
};

static id (^parseServerInfo)(id) = ^id(NSString* info) {
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSMutableDictionary* values = nil;
    
    for(NSString* line in [info componentsSeparatedByString: @"\r\n"]) {
        if( line.length == 0 ) continue;
        
        if( [line hasPrefix: @"# "] ) {
            NSString* section = [line substringFromIndex:2];
            values = [NSMutableDictionary new];
            [result setObject:values forKey:section];
        } else {
            NSArray* kv = [line componentsSeparatedByString: @":"];
            [values setObject:kv[1] forKey:kv[0]];
        }
    }
    
    return result;
};

static id (^parseSlowLog)(id) = ^id(NSArray* data) {
    NSMutableArray* result = [NSMutableArray new];
    
    for( NSUInteger i = 0; i < [data count]; ++i ) {
        NSMutableDictionary* parsed = [NSMutableDictionary new];
        NSArray* log = data[i];
        
        parsed[@"id"] = log[0];
        
        NSTimeInterval timestamp = [log[1] integerValue];
        parsed[@"timestate"] = [NSDate dateWithTimeIntervalSince1970: timestamp];
        
        parsed[@"execution"] = log[2];
        parsed[@"command"] = log[3];
        
        [result addObject: parsed];
    }
    
    return result;
};

static NSDictionary* ParseMasterRole(NSArray* data) {
    NSMutableDictionary* result = [NSMutableDictionary new];
    
    result[@"role"] = data[0];
    
    long long offset = [data[1] longLongValue];
    result[@"offset"] = [NSNumber numberWithLongLong:offset];

    NSArray* slavesArray = data[2];
    NSMutableArray* parsedSlaves = [NSMutableArray new];
    
    for( NSUInteger i = 0; i < slavesArray.count; ++i ) {
        NSArray* slave = slavesArray[i];
        
        NSString* slaveAddr = [NSString stringWithFormat:@"%@:%@", slave[0], slave[1]];
        long long slaveOffset = [slave[2] longLongValue];
        
        [parsedSlaves addObject: @{ @"address": slaveAddr, @"offset": [NSNumber numberWithLongLong:slaveOffset] }];
    }

    result[@"slaves"] = parsedSlaves;
    
    return result;
}

static NSDictionary* ParseSlaveRole(NSArray* data) {
    NSMutableDictionary* result = [NSMutableDictionary new];
    
    result[@"role"] = data[0];
    result[@"address"] = [NSString stringWithFormat: @"%@:%@", data[1], data[2]];

    BOOL connected = [data[3] isEqualToString: @"connected"];
    result[@"connected"] = [NSNumber numberWithBool: connected];
    
    long long offset = [data[4] longLongValue];
    result[@"offset"] = [NSNumber numberWithLongLong: offset];
    
    return result;
}

static void _CollectKeys(NSString* scanCmd, CocoaRedis* redis, id key, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableArray* keys) {
    [cursorPromise onFulfill:^id(id value) {
        NSInteger cursor = [value[0] integerValue];
        [keys addObjectsFromArray: value[1]];
        
        if( cursor == 0 ) {
            [result fulfill: keys];
        } else {
            NSMutableArray* args = [NSMutableArray arrayWithObjects: scanCmd, key, nil];
            [args addObjectsFromArray: @[[NSNumber numberWithInteger:cursor], @"MATCH", pattern]];
            CocoaPromise* nextCursor = [redis command: args];
            _CollectKeys(scanCmd, redis, key, nextCursor, pattern, result, keys);
        }
        return nil;
    } onReject:^id(NSError *err) {
        [result reject: err];
        return nil;
    }];
}

static void CollectKeys(CocoaRedis* redis, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableArray* keys) {
    _CollectKeys(@"SCAN", redis, nil, cursorPromise, pattern, result, keys);
}

static void CollectSetKeys(CocoaRedis* redis, id key, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableArray* keys) {
    _CollectKeys(@"SSCAN", redis, key, cursorPromise, pattern, result, keys);
}

static void _CollectKeysToDict(NSString* scanCmd, CocoaRedis* redis, id key, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableDictionary* dict, id(^mutator)(id)) {
    [cursorPromise onFulfill:^id(id value) {
        NSInteger cursor = [value[0] integerValue];
        
        NSArray* data = value[1];
        const NSUInteger count = [data count];
        
        for(int i = 0; i < count; i += 2 ) {
            id obj = mutator ? mutator(data[i+1]) : data[i+1];
            [dict setObject: obj forKey: data[i]];
        }
        
        if( cursor == 0 ) {
            [result fulfill: dict];
        } else {
            CocoaPromise* nextCursor = [redis command: @[scanCmd, key, [NSNumber numberWithInteger:cursor], @"MATCH", pattern]];
            _CollectKeysToDict(scanCmd, redis, key, nextCursor, pattern, result, dict, mutator);
        }
        return nil;
    } onReject:^id(NSError *err) {
        [result reject: err];
        return nil;
    }];
}

static void CollectHashKeys(CocoaRedis* redis, id key, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableDictionary* dict) {
    _CollectKeysToDict(@"HSCAN", redis, key, cursorPromise, pattern, result, dict, nil);
}

static void CollectZSetKeys(CocoaRedis* redis, id key, CocoaPromise* cursorPromise, NSString* pattern, CocoaPromise* result, NSMutableDictionary* dict) {
    _CollectKeysToDict(@"ZSCAN", redis, key, cursorPromise, pattern, result, dict, toDouble);
}


@interface CocoaRedis ()
@property redisAsyncContext* ctx;
@end

@implementation CocoaRedis

- (instancetype)init {
    self = [super init];
    if( self ) {
        self.ctx = NULL;
    }
    return self;
}

- (CocoaPromise *)connectWithHost:(NSString *)serverHost {
    int serverPort = 6379;

    NSRange pos = [serverHost rangeOfString: @":"];
    if( pos.location != NSNotFound ) {
        serverPort = [[serverHost substringFromIndex: pos.location + 1] intValue];
        serverHost = [serverHost substringToIndex: pos.location];
    }
    
    return [self connectWithHost: serverHost port: serverPort];
}

- (CocoaPromise *)connectWithHost:(NSString *)serverHost port:(int)serverPort {
    NSAssert(!self.isConnected, @"Already connected");
    
    CocoaPromise* result = [CocoaPromise new];
    
    self.ctx = redisAsyncConnect(serverHost.UTF8String, serverPort);
    
    if( self.ctx == NULL || self.ctx->err ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: self.ctx->errstr]
                                           code: self.ctx->err
                                       userInfo: nil];
        [result reject: err];
    } else {
        self.ctx->data = (void*) CFBridgingRetain(result);
        
        redisAsyncSetConnectCallback(self.ctx, connectCallback);
        redisAsyncSetDisconnectCallback(self.ctx, disconnectCallback);
        
        redisMacOSAttach(self.ctx, CFRunLoopGetCurrent());
    }
    
    return result;
}

- (CocoaPromise*) close {
    NSAssert(self.isConnected, @"Not connected");
    CocoaPromise* result = [CocoaPromise new];

    redisAsyncContext* ac = self.ctx;
    ac->data = (void*) CFBridgingRetain(result);

    self.ctx = NULL;
    
    redisAsyncDisconnect(ac);

    return result;
}

- (NSString*) host {
    NSAssert(self.isConnected, @"Not connected");
    return [NSString stringWithUTF8String: self.ctx->c.tcp.host];
}

- (NSNumber*) port {
    NSAssert(self.isConnected, @"Not connected");
    return [NSNumber numberWithInt: self.ctx->c.tcp.port];
}

- (BOOL) isConnected {
    return self.ctx != NULL && self.ctx->c.flags & REDIS_CONNECTED;
}

typedef struct {
    char const** argv;
    size_t* argvlen;
} argvbuf;

static void freebuf(argvbuf* buf) {
    if(buf) {
        free((void*) buf->argv);
        free((void*) buf->argvlen);
    }
}

static CocoaPromise* reject(CocoaPromise* result, NSString* reason, argvbuf* buf) {
    freebuf(buf);
    NSError* err = [NSError errorWithDomain:reason code:0 userInfo:nil];
    [result reject:err];
    return result;
}

- (CocoaPromise *)command:(NSArray *)arguments {
    CocoaPromise* result = [CocoaPromise new];
    
    if( !self.isConnected ) return reject(result, @"Not connected", NULL);
        
    argvbuf buf = {NULL, NULL};
    const NSUInteger count = arguments.count;

    buf.argv = calloc(count, sizeof(char*));
    buf.argvlen = calloc(count, sizeof(size_t));
    
    if( !buf.argv || !buf.argvlen ) return reject(result, @"Out of memory", &buf);

    for( int i = 0; i < count; ++i ) {
        id arg = [arguments objectAtIndex: i];
        
        if( [arg isKindOfClass: [NSString class]] ) {
            buf.argv   [i] = [arg UTF8String];
            buf.argvlen[i] = strlen(buf.argv[i]);
        } else if( [arg isKindOfClass: [NSNumber class]] ) {
            buf.argv   [i] = [[arg stringValue] UTF8String];
            buf.argvlen[i] = strlen(buf.argv[i]);
        } else if( [arg isKindOfClass: [NSData class]] ) {
            buf.argv   [i] = [arg bytes];
            buf.argvlen[i] = [arg length];
        } else {
            return reject(result, @"Invalid command argument", &buf);
        }
    }
    
    int rc = redisAsyncCommandArgv(self.ctx,
                                   commandCallback,
                                   (void*) CFBridgingRetain(result),
                                   (int) count, buf.argv, buf.argvlen);
    
    if( rc != REDIS_OK ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: self.ctx->errstr]
                                           code: self.ctx->err
                                       userInfo: nil];
        [result reject: err];
    }
    
    freebuf(&buf);

    return result;
}

- (CocoaPromise*) command:(NSArray *)command arguments:(NSArray *)arguments {
    return [self command: [command arrayByAddingObjectsFromArray: (arguments ? arguments : @[])]];
}

- (NSArray*) parseClientList: (NSString*)reply {
    NSMutableArray* result = [NSMutableArray new];
    
    for(NSString* client in [reply componentsSeparatedByString: @"\n"]) {
        if( client.length == 0 ) continue;
        NSMutableDictionary* dict = [NSMutableDictionary new];
        
        for(NSString* element in [client componentsSeparatedByString: @" "]) {
            NSArray* kv = [element componentsSeparatedByString: @"="];
            [dict setValue: kv[1] forKey: kv[0]];
        }
        
        [result addObject: dict];
    }
    
    return result;
}

- (CocoaPromise*) version {
    return [[self info: @"Server"] then:^id(id value) {
        return value[@"redis_version"];
    }];
}

#pragma mark - STRINGS

#pragma mark - APPEND
- (CocoaPromise *)append:(id)key value:(id)value {
    return [self command: @[@"APPEND", key, value]];
}

#pragma mark BITCOUNT
- (CocoaPromise *)bitcount:(id)key {
    return [self command: @[@"BITCOUNT", key]];
}

- (CocoaPromise *)bitcount:(id)key start:(NSInteger)start end:(NSInteger)end {
    return [self command: @[@"BITCOUNT", key, [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:end]]];
}

- (CocoaPromise *)bitcount:(id)key range:(NSRange)range {
    return [self bitcount:key start:range.location end:(range.location + range.length)];
}

#pragma mark BITOP
- (CocoaPromise*) bitopAnd: (id)dest key: (id)key {
    return [self command: @[@"BITOP", @"AND", dest, key]];
}

- (CocoaPromise*) bitopAnd: (id)dest keys: (NSArray*)keys {
    return [self command:@[@"BITOP", @"AND", dest] arguments:keys];
}

- (CocoaPromise*) bitopOr: (id)dest key: (id)key {
    return [self command: @[@"BITOP", @"OR", dest, key]];
}

- (CocoaPromise*) bitopOr: (id)dest keys: (NSArray*)keys {
    return [self command:@[@"BITOP", @"OR", dest] arguments:keys];
}

- (CocoaPromise*) bitopXor: (id)dest key: (id)key {
    return [self command: @[@"BITOP", @"XOR", dest, key]];
}

- (CocoaPromise*) bitopXor: (id)dest keys: (NSArray*)keys {
    return [self command:@[@"BITOP", @"XOR", dest] arguments:keys];
}

- (CocoaPromise*) bitopNot: (id)dest key: (id)key {
    return [self command: @[@"BITOP", @"NOT", dest, key]];
}

- (CocoaPromise*) bitopNot: (id)dest keys: (NSArray*)keys {
    return [self command:@[@"BITOP", @"NOT", dest] arguments:keys];
}

#pragma mark BITPOS
- (CocoaPromise *)bitpos:(id)key value:(BOOL)bit {
    return [self command: @[@"BITPOS", key, [NSNumber numberWithBool:bit]]];
}

- (CocoaPromise *)bitpos:(id)key value:(BOOL)bit start:(NSInteger)start {
    return [self command: @[@"BITPOS", key, [NSNumber numberWithBool:bit], [NSNumber numberWithInteger:start]]];
}

- (CocoaPromise *)bitpos:(id)key value:(BOOL)bit start:(NSInteger)start end:(NSInteger)end {
    return [self command: @[@"BITPOS", key, [NSNumber numberWithBool:bit], [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:end]]];
}

- (CocoaPromise *)bitpos:(id)key value:(BOOL)bit range:(NSRange)range {
    return [self bitpos:key value:bit start:range.location end:(range.location + range.length)];
}

#pragma mark DECR
- (CocoaPromise *)decr:(id)key {
    return [[self command: @[@"DECR", key]] then: toLongLong];
}

#pragma mark DECRBY
- (CocoaPromise *)decrby:(id)key value:(int64_t)value {
    return [self command: @[@"DECRBY", key, [NSNumber numberWithLongLong:value]]];
}

#pragma mark GET
- (CocoaPromise *)get:(id)key {
    return [self command: @[@"GET", key]];
}

#pragma mark GETBIT
- (CocoaPromise*) getbit:(id)key offset:(NSInteger)offset {
    return [self command: @[@"GETBIT", key, [NSNumber numberWithInteger:offset]]];
}

#pragma mark GETRANGE
- (CocoaPromise *)getrange:(id)key start:(NSInteger)start end:(NSInteger)end {
    return [self command: @[@"GETRANGE", key, [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:end]]];
}

- (CocoaPromise *)getrange:(id)key range:(NSRange)range {
    return [self getrange:key start:range.location end:(range.location + range.length)];
}

#pragma mark GETSET
- (CocoaPromise *)getset:(id)key value:(id)value {
    return [self command: @[@"GETSET", key, value]];
}

#pragma mark INCR
- (CocoaPromise *)incr:(id)key {
    return [[self command: @[@"INCR", key]] then: toLongLong];
}

#pragma mark INCRBY
- (CocoaPromise *)incrby:(id)key value:(int64_t)value {
    return [self command: @[@"INCRBY", key, [NSNumber numberWithLongLong:value]]];
}

#pragma mark INCRBYFLOAT
- (CocoaPromise* )incrbyfloat:(id)key value:(double)value {
    return [[self command: @[@"INCRBYFLOAT", key, [NSNumber numberWithDouble:value]]] then: toDouble];
}

#pragma mark MGET
- (CocoaPromise *)mget:(NSArray *)values {
    return [self command:@[@"MGET"] arguments:values];
}

#pragma mark MSET
- (CocoaPromise *)mset:(id)key value:(id)value {
    return [self command: @[@"MSET", key, value]];
}

- (CocoaPromise *)mset:(NSArray *)values {
    return [self command:@[@"MSET"] arguments:values];
}

#pragma mark MSETNX
- (CocoaPromise*)msetnx:(id)key value:(id)value {
    return [self command: @[@"MSETNX", key, value]];
}

- (CocoaPromise *)msetnx:(NSArray*)values {
    return [self command:@[@"MSETNX"] arguments:values];
}

#pragma mark PSETEX
- (CocoaPromise *)psetex:(id)key milliseconds:(NSInteger)ms value:(id)value {
    return [self command: @[@"PSETEX", key, [NSNumber numberWithInteger:ms], value]];
}

#pragma mark SET
- (CocoaPromise*)set:(id)key value:(id)value {
    return [self command: @[@"SET", key, value]];
}

- (CocoaPromise *)set:(id)key value:(id)value ex:(NSInteger)sec {
    return [self command: @[@"SET", key, value, @"EX", [NSNumber numberWithInteger:sec]]];
}

- (CocoaPromise *)set:(id)key value:(id)value px:(NSInteger)ms {
    return [self command: @[@"SET", key, value, @"PX", [NSNumber numberWithInteger:ms]]];
}

- (CocoaPromise*) set:(id)key value:(id)value options:(NSArray *)options {
    return [self command: @[@"SET", key, value] arguments: options];
}

#pragma mark SETBIT
- (CocoaPromise *)setbit:(id)key offset:(NSInteger)offset value:(BOOL)bit {
    return [self command: @[@"SETBIT", key, [NSNumber numberWithInteger:offset], [NSNumber numberWithBool:bit]]];
}

#pragma mark SETEX
- (CocoaPromise *)setex:(id)key seconds:(NSInteger)sec value:(id)value {
    return [self command: @[@"SETEX", key, [NSNumber numberWithInteger:sec], value]];
}

#pragma mark SETNX
- (CocoaPromise *)setnx:(id)key value:(id)value {
    return [self command: @[@"SETNX", key, value]];
}

#pragma mark SETRANGE
- (CocoaPromise *)setrange:(id)key offset:(NSInteger)offset value:(id)value {
    return [self command: @[@"SETRANGE", key, [NSNumber numberWithInteger:offset], value]];
}

#pragma mark STRLEN
- (CocoaPromise *)strlen:(id)key {
    return [self command: @[@"STRLEN", key]];
}

#pragma mark - KEYS

#pragma mark - DEL
- (CocoaPromise *)del:(id)key {
    return [self command: @[@"DEL", key]];
}

- (CocoaPromise *)delKeys:(NSArray *)keys {
    return [self command:@[@"DEL"] arguments:keys];
}

#pragma mark DUMP
- (CocoaPromise *)dump:(id)key {
    return [self command: @[@"DUMP", key]];
}

#pragma mark EXISTS
- (CocoaPromise *)exists:(id)key {
    return [self command: @[@"EXISTS", key]];
}

- (CocoaPromise *)existsKeys:(NSArray *)keys {
    return [self command:@[@"EXISTS"] arguments:keys];
}

#pragma mark EXPIRE
- (CocoaPromise *)expire:(id)key seconds:(NSInteger)sec {
    return [self command: @[@"EXPIRE", key, [NSNumber numberWithInteger:sec]]];
}

#pragma mark EXPIREAT
- (CocoaPromise *)expireat:(id)key timestamp:(NSUInteger)ts {
    return [self command: @[@"EXPIREAT", key, [NSNumber numberWithUnsignedInteger:ts]]];
}

#pragma mark KEYS
- (CocoaPromise *)keys:(id)pattern {
    return [self command: @[@"KEYS", pattern]];
}

#pragma mark MIGRATE
- (CocoaPromise*) migrate: (NSString*)host port: (NSInteger)port key: (id)key db: (NSInteger)db timeout: (NSInteger)msec options: (NSArray*)options {
    return [self command: @[@"MIGRATE", host, [NSNumber numberWithInteger:port], key, [NSNumber numberWithInteger:db], [NSNumber numberWithInteger:msec]] arguments:options];
}

#pragma mark MOVE
- (CocoaPromise *)move:(id)key db:(NSInteger)db {
    return [self command: @[@"MOVE", key, [NSNumber numberWithInteger:db]]];
}

#pragma mark OBJECT
- (CocoaPromise *)object:(NSString *)subcommand key:(id)key {
    return [self command:@[@"OBJECT", subcommand, key]];
}

- (CocoaPromise *)object:(NSString *)subcommand keys:(NSArray *)keys {
    return [self command:@[@"OBJECT", subcommand] arguments:keys];
}

#pragma mark PERSIST
- (CocoaPromise *)persist:(id)key {
    return [self command: @[@"PERSIST", key]];
}

#pragma mark PEXPIRE
- (CocoaPromise *)pexpire:(id)key milliseconds:(NSInteger)ms {
    return [self command: @[@"PEXPIRE", key, [NSNumber numberWithInteger:ms]]];
}

#pragma mark PEXPIREAT
- (CocoaPromise *)pexpireat:(id)key timestamp:(uint64_t)ms {
    return [self command: @[@"PEXPIREAT", key, [NSNumber numberWithLongLong:ms]]];
}

#pragma mark PTTL
- (CocoaPromise *)pttl:(id)key {
    return [self command: @[@"PTTL", key]];
}

#pragma mark RANDOMKEY
- (CocoaPromise *)randomkey {
    return [self command: @[@"RANDOMKEY"]];
}

#pragma mark RENAME
- (CocoaPromise *)rename:(id)key newKey:(id)newKey {
    return [self command: @[@"RENAME", key, newKey]];
}

#pragma mark RENAMENX
- (CocoaPromise *)renamenx:(id)key newKey:(id)newKey {
    return [self command: @[@"RENAMENX", key, newKey]];
}

#pragma mark RESTORE
- (CocoaPromise *)restore:(id)key ttl:(NSInteger)ms value:(NSData *)value {
    return [self command: @[@"RESTORE", key, [NSNumber numberWithInteger:ms], value]];
}

- (CocoaPromise *)restore:(id)key ttl:(NSInteger)ms value:(NSData *)value restore:(BOOL)restore {
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"RESTORE", key, [NSNumber numberWithInteger:ms], value, nil];
    if(restore) [args addObject: @"RESTORE"];
    return [self command: args];
}

#pragma mark SORT
- (CocoaPromise *)sort:(id)key options:(NSArray *)options {
    return [self command: @[@"SORT", key] arguments:options];
}

#pragma mark TTL
- (CocoaPromise *)ttl:(id)key {
    return [self command: @[@"TTL", key]];
}

#pragma mark TYPE
- (CocoaPromise *)type:(id)key {
    return [self command: @[@"TYPE", key]];
}

#pragma mark SCAN
- (CocoaPromise *)scan:(NSString *)pattern {
    CocoaPromise* result = [CocoaPromise new];
    
    CocoaPromise* firstCursor = [self command: @[@"SCAN", [NSNumber numberWithInteger:0], @"MATCH", pattern]];
    CollectKeys(self, firstCursor, pattern, result, [NSMutableArray new]);
    
    return result;
}

#pragma mark - LISTS

#pragma mark - BLPOP
- (CocoaPromise *)blpop:(id)key timeout:(NSInteger)sec {
    return [self command: @[@"BLPOP", key, [NSNumber numberWithInteger:sec]]];
}

- (CocoaPromise *)blpopKeys:(NSArray *)keys timeout:(NSInteger)sec {
    NSMutableArray* args = [NSMutableArray arrayWithObject: @"BLPOP"];
    [args addObjectsFromArray: keys];
    [args addObject: [NSNumber numberWithInteger: sec]];
    return [self command: args];
}

#pragma mark BRPOP
- (CocoaPromise *)brpop:(id)key timeout:(NSInteger)sec {
    return [self command: @[@"BRPOP", key, [NSNumber numberWithInteger:sec]]];
}

- (CocoaPromise *)brpopKeys:(NSArray *)keys timeout:(NSInteger)sec {
    NSMutableArray* args = [NSMutableArray arrayWithObject: @"BRPOP"];
    [args addObjectsFromArray: keys];
    [args addObject: [NSNumber numberWithInteger: sec]];
    return [self command: args];
}

#pragma mark BRPOPLPUSH
- (CocoaPromise *)brpop:(id)src lpush:(id)dst timeout:(NSInteger)sec {
    return [self command: @[@"BRPOPLPUSH", src, dst, [NSNumber numberWithInteger:sec]]];
}

#pragma mark LINDEX
- (CocoaPromise *)lindex:(id)key value:(NSInteger)index {
    return [self command: @[@"LINDEX", key, [NSNumber numberWithInteger:index]]];
}

#pragma mark LINSERT
- (CocoaPromise *)linsert:(id)key before:(id)pivot value:(id)value {
    return [self command: @[@"LINSERT", key, @"BEFORE", pivot, value]];
}

- (CocoaPromise *)linsert:(id)key after:(id)pivot value:(id)value {
    return [self command: @[@"LINSERT", key, @"AFTER", pivot, value]];
}

#pragma mark LLEN
- (CocoaPromise *)llen:(id)key {
    return [self command: @[@"LLEN", key]];
}

#pragma mark LPOP
- (CocoaPromise *)lpop:(id)key {
    return [self command: @[@"LPOP", key]];
}

#pragma mark LPUSH
- (CocoaPromise *)lpush:(id)key value:(id)value {
    return [self command: @[@"LPUSH", key, value]];
}

- (CocoaPromise *)lpush:(id)key values:(NSArray *)values {
    return [self command:@[@"LPUSH", key] arguments:values];
}

#pragma mark LPUSHX
- (CocoaPromise *)lpushx:(id)key value:(id)value {
    return [self command: @[@"LPUSHX", key, value]];
}

#pragma mark LRANGE
- (CocoaPromise *)lrange:(id)key start:(NSInteger)start stop:(NSInteger)stop {
    return [self command: @[@"LRANGE", key, [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:stop]]];
}

- (CocoaPromise *)lrange:(id)key range:(NSRange)range {
    return [self lrange:key start:range.location stop:(range.location + range.length)];
}

#pragma mark LREM
- (CocoaPromise *)lrem:(id)key count:(NSInteger)count value:(id)value {
    return [self command: @[@"LREM", key, [NSNumber numberWithInteger:count], value]];
}

#pragma mark LSET
- (CocoaPromise *)lset:(id)key index:(NSInteger)index value:(id)value {
    return [self command: @[@"LSET", key, [NSNumber numberWithInteger:index], value]];
}

#pragma mark LTRIM
- (CocoaPromise *)ltrim:(id)key start:(NSInteger)start stop:(NSInteger)stop {
    return [self command: @[@"LTRIM", key, [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:stop]]];
}

- (CocoaPromise *)ltrim:(id)key range:(NSRange)range {
    return [self ltrim:key start:range.location stop:(range.location + range.length)];
}

#pragma mark RPOP
- (CocoaPromise *)rpop:(id)key {
    return [self command: @[@"RPOP", key]];
}

#pragma mark RPOPLPUSH
- (CocoaPromise *)rpop:(id)src lpush:(id)dst {
    return [self command: @[@"RPOPLPUSH", src, dst]];
}

#pragma mark RPUSH
- (CocoaPromise *)rpush:(id)key value:(id)value {
    return [self command: @[@"RPUSH", key, value]];
}

- (CocoaPromise *)rpush:(id)key values:(NSArray *)values {
    return [self command:@[@"RPUSH", key] arguments:values];
}

#pragma mark RPUSHX
- (CocoaPromise *)rpushx:(id)key value:(id)value {
    return [self command: @[@"RPUSHX", key, value]];
}

#pragma mark - SETS


#pragma mark - SADD
- (CocoaPromise *)sadd:(id)key value:(id)value {
    return [self command: @[@"SADD", key, value]];
}

- (CocoaPromise *)sadd:(id)key values:(NSArray *)values {
    return [self command:@[@"SADD", key] arguments:values];
}

#pragma mark SCARD
- (CocoaPromise *)scard:(id)key {
    return [self command: @[@"SCARD", key]];
}

#pragma mark SDIFF
- (CocoaPromise *)sdiff:(id)key1 with:(id)key2 {
    return [[self command: @[@"SDIFF", key1, key2]] then: toNSSet];
}

- (CocoaPromise *)sdiff:(id)key keys:(NSArray *)keys {
    return [[self command:@[@"SDIFF", key] arguments:keys] then: toNSSet];
}

#pragma mark SDIFFSTORE
- (CocoaPromise *)sdiffstore:(id)dst key:(id)key1 with:(id)key2 {
    return [self command: @[@"SDIFFSTORE", dst, key1, key2]];
}

- (CocoaPromise *)sdiffstore:(id)dst key:(id)key keys:(NSArray *)keys {
    return [self command:@[@"SDIFFSTORE", key] arguments:keys];
}

#pragma mark SINTER
- (CocoaPromise *)sinter:(id)key1 with:(id)key2 {
    return [[self command: @[@"SINTER", key1, key2]] then: toNSSet];
}

- (CocoaPromise *)sinter:(id)key keys:(NSArray *)keys {
    return [[self command:@[@"SINTER", key] arguments:keys] then: toNSSet];
}

#pragma mark SINTERSTORE
- (CocoaPromise *)sinterstore:(id)dst key:(id)key1 with:(id)key2 {
    return [self command: @[@"SINTERSTORE", dst, key1, key2]];
}

- (CocoaPromise *)sinterstore:(id)dst key:(id)key keys:(NSArray *)keys {
    return [self command:@[@"SINTERSTORE", key] arguments:keys];
}

#pragma mark SISMEMBER
- (CocoaPromise *)sismember:(id)key value:(id)value {
    return [self command: @[@"SISMEMBER", key, value]];
}

#pragma mark SMEMBERS
- (CocoaPromise *)smembers:(id)key {
    return [[self command: @[@"SMEMBERS", key]] then: toNSSet];
}

#pragma mark SMOVE
- (CocoaPromise *)smove:(id)src destination:(id)dst value:(id)value {
    return [self command: @[@"SMOVE", src, dst, value]];
}

#pragma mark SPOP
- (CocoaPromise *)spop:(id)key {
    return [self command: @[@"SPOP", key]];
}

- (CocoaPromise *)spop:(id)key count:(NSInteger)count {
    return [[self command: @[@"SPOP", key, [NSNumber numberWithInteger:count]]] then: toNSSet];
}

#pragma mark SRANDMEMBER
- (CocoaPromise *)srandmember:(id)key {
    return [self command: @[@"SRANDMEMBER", key]];
}

- (CocoaPromise *)srandmember:(id)key count:(NSInteger)count {
    return [[self command: @[@"SRANDMEMBER", key, [NSNumber numberWithInteger:count]]] then: toNSSet];
}

#pragma mark SREM
- (CocoaPromise *)srem:(id)key value:(id)value {
    return [self command: @[@"SREM", key, value]];
}

- (CocoaPromise *)srem:(id)key values:(NSArray *)values {
    return [self command:@[@"SREM", key] arguments:values];
}

#pragma mark SUNION
- (CocoaPromise *)sunion:(id)key1 with:(id)key2 {
    return [[self command: @[@"SUNION", key1, key2]] then: toNSSet];
}

- (CocoaPromise *)sunion:(id)key keys:(NSArray *)keys {
    return [[self command:@[@"SUNION", key] arguments:keys] then: toNSSet];
}

#pragma mark SUNIONSTORE
- (CocoaPromise *)sunionstore:(id)dst key:(id)key1 with:(id)key2 {
    return [self command: @[@"SUNIONSTORE", dst, key1, key2]];
}

- (CocoaPromise *)sunionstore:(id)dst key:(id)key keys:(NSArray *)keys {
    return [self command:@[@"SUNIONSTORE", key] arguments:keys];
}

#pragma mark SSCAN

- (CocoaPromise *)sscan: (id)key match: (NSString *)pattern {
    CocoaPromise* result = [CocoaPromise new];
    
    CocoaPromise* firstCursor = [self command: @[@"SSCAN", key, [NSNumber numberWithInteger:0], @"MATCH", pattern]];
    CollectSetKeys(self, key, firstCursor, pattern, result, [NSMutableArray new]);
    
    return [result then: toNSSet];
}

#pragma mark - HASHES

#pragma mark - HDEL
- (CocoaPromise*) hdel: (id)key field:  (id)field {
    return [self command: @[@"HDEL", key, field]];
}

- (CocoaPromise*) hdel: (id)key fields: (NSArray*)fields {
    return [self command:@[@"HDEL", key] arguments:fields];
}

#pragma mark HEXISTS
- (CocoaPromise *)hexists:(id)key field:(id)field {
    return [self command: @[@"HEXISTS", key, field]];
}

#pragma mark HGET
- (CocoaPromise *)hget:(id)key field:(id)field {
    return [self command: @[@"HGET", key, field]];
}


#pragma mark HGETALL
- (CocoaPromise *)hgetall:(id)key {
    return PromiseNSDict( [self command: @[@"HGETALL", key]], nil );
}

#pragma mark HINCRBY
- (CocoaPromise *)hincrby:(id)key field:(id)field value:(uint64_t)value {
    return [self command: @[@"HINCRBY", key, field, [NSNumber numberWithLongLong:value]]];
}

#pragma mark HINCRBYFLOAT
- (CocoaPromise *)hincrbyfloat:(id)key field:(id)field value:(double)value {
    return [[self command: @[@"HINCRBYFLOAT", key, field, [NSNumber numberWithDouble:value]]] then: toDouble];
}

#pragma mark HKEYS
- (CocoaPromise *)hkeys:(id)key {
    return [[self command: @[@"HKEYS", key]] then: toNSSet];
}

#pragma mark HLEN
- (CocoaPromise *)hlen:(id)key {
    return [self command: @[@"HLEN", key]];
}

#pragma mark HMGET
- (CocoaPromise *)hmget:(id)key field:(id)field {
    return [self command: @[@"HMGET", key, field]];
}

- (CocoaPromise *)hmget:(id)key fields:(NSArray *)fields {
    return [self command:@[@"HMGET", key] arguments:fields];
}

#pragma mark HMSET
- (CocoaPromise *)hmset:(id)key field:(id)field value:(id)value {
    return [self command: @[@"HMSET", key, field, value]];
}

- (CocoaPromise *)hmset:(id)key values:(NSArray *)values {
    return [self command:@[@"HMSET", key] arguments:values];
}

- (CocoaPromise *)hmset:(id)key dictionary:(NSDictionary *)dict {
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"HMSET", key, nil];
    for( id key in dict ) {
        [args addObject: key];
        [args addObject: dict[key]];
    }
    return [self command: args];
}

#pragma mark HSET
- (CocoaPromise *)hset:(id)key field:(id)field value:(id)value {
    return [self command: @[@"HSET", key, field, value]];
}

#pragma mark HSETNX
- (CocoaPromise *)hsetnx:(id)key field:(id)field value:(id)value {
    return [self command: @[@"HSETNX", key, field, value]];
}

#pragma mark HSTRLEN
- (CocoaPromise *)hstrlen:(id)key field:(id)field {
    return [self command: @[@"HSTRLEN", key, field]];
}

#pragma mark HVALS
- (CocoaPromise *)hvals:(id)key {
    return [self command: @[@"HVALS", key]];
}

#pragma mark HSCAN

- (CocoaPromise *)hscan: (id)key match: (NSString *)pattern {
    CocoaPromise* result = [CocoaPromise new];
    
    CocoaPromise* firstCursor = [self command: @[@"HSCAN", key, [NSNumber numberWithInteger:0], @"MATCH", pattern]];
    CollectHashKeys(self, key, firstCursor, pattern, result, [NSMutableDictionary new]);
    
    return result;
}

#pragma mark - SORTED SETS

#pragma mark - ZADD
- (CocoaPromise *)zadd:(id)key score:(double)score member:(id)member {
    return [self command: @[@"ZADD", key, [NSNumber numberWithDouble:score], member]];
}

-(CocoaPromise *)zadd:(id)key values:(NSArray *)values {
    return [self command:@[@"ZADD", key] arguments:values];
}


#pragma mark ZCARD
- (CocoaPromise *)zcard:(id)key {
    return [self command: @[@"ZCARD", key]];
}

#pragma mark ZCOUNT
- (CocoaPromise *)zcount:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZCOUNT", key, min, max]];
}

#pragma mark ZINCRBY
- (CocoaPromise *)zincrby:(id)key value:(double)value member:(id)member {
    return [[self command: @[@"ZINCRBY", key, [NSNumber numberWithDouble:value], member]] then: toDouble];
}

#pragma mark ZINTERSTORE
- (NSMutableArray*) zinterstoreArgs: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights {
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"ZINTERSTORE", dst, [NSNumber numberWithInteger:keys.count], nil];
    [args addObjectsFromArray: keys];
    [args addObject: @"WEIGHTS"];
    [args addObjectsFromArray: weights];
    return args;
}

- (CocoaPromise *)zinterstore:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    return [self command: [self zinterstoreArgs:dst keys:keys weights:weights]];
}

- (CocoaPromise *)zinterstoreSum:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zinterstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"SUM"]];
    return [self command: args];
}

- (CocoaPromise *)zinterstoreMin:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zinterstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"MIN"]];
    return [self command: args];
}

- (CocoaPromise *)zinterstoreMax:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zinterstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"MAX"]];
    return [self command: args];
}

#pragma mark ZLEXCOUNT
- (CocoaPromise *)zlexcount:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZLEXCOUNT", key, min, max]];
}

#pragma mark ZRANGE
- (CocoaPromise *)zrange:(id)key start:(double)start stop:(double)stop {
    return [self command: @[@"ZRANGE", key, [NSNumber numberWithDouble:start], [NSNumber numberWithDouble:stop]]];
}

- (CocoaPromise *)zrangeWithScores:(id)key start:(double)start stop:(double)stop {
    return PromiseNSDict( [self command: @[@"ZRANGE", key, [NSNumber numberWithDouble:start], [NSNumber numberWithDouble:stop], @"WITHSCORES"]], toDouble);
}

#pragma mark ZRANGEBYLEX
- (CocoaPromise *)zrangebylex:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZRANGEBYLEX", key, min, max]];
}

- (CocoaPromise *)zrangebylex:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZRANGEBYLEX", key, min, max, @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise *)zrangebylex:(id)key min:(id)min max:(id)max range:(NSRange)range {
    return [self zrangebylex:key min:min max:max offset:range.location count:range.length];
}

#pragma mark ZREVRANGEBYLEX
- (CocoaPromise *)zrevrangebylex:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZREVRANGEBYLEX", key, min, max]];
}

- (CocoaPromise *)zrevrangebylex:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZREVRANGEBYLEX", key, min, max, @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise*) zrevrangebylex: (id)key min: (id)min max: (id)max range: (NSRange)range {
    return [self zrevrangebylex:key min:min max:max offset:range.location count:range.length];
}

#pragma mark ZRANGEBYSCORE
- (CocoaPromise *)zrangebyscore:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZRANGEBYSCORE", key, min, max]];
}

- (CocoaPromise *)zrangebyscoreWithScores:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZRANGEBYSCORE", key, min, max, @"WITHSCORES"]];
}

- (CocoaPromise *)zrangebyscore:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZRANGEBYSCORE", key, min, max, @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise *)zrangebyscoreWithScores:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZRANGEBYSCORE", key, min, max, @"WITHSCORES", @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise *)zrangebyscore:(id)key min:(id)min max:(id)max range:(NSRange)range {
    return [self zrangebyscore:key min:min max:max offset:range.location count:range.length];
}

- (CocoaPromise *)zrangebyscoreWithScores:(id)key min:(id)min max:(id)max range:(NSRange)range {
    return [self zrangebyscoreWithScores:key min:min max:max offset:range.location count:range.length];
}

#pragma mark ZRANK
- (CocoaPromise *)zrank:(id)key member:(id)member {
    return [self command: @[@"ZRANK", key, member]];
}

#pragma mark ZREM
- (CocoaPromise *)zrem:(id)key member:(id)member {
    return [self command: @[@"ZREM", key, member]];
}

- (CocoaPromise *)zrem:(id)key members:(NSArray *)members {
    return [self command:@[@"ZREM", key] arguments:members];
}

#pragma mark ZREMRANGEBYLEX
- (CocoaPromise*) zremrangebylex: (id)key min: (id)min max: (id)max {
    return [self command: @[@"ZREMRANGEBYLEX", key, min, max]];
}

#pragma mark ZREMRANGEBYRANK
- (CocoaPromise *)zremrangebyrank:(id)key start:(NSInteger)start stop:(NSInteger)stop {
    return [self command: @[@"ZREMRANGEBYRANK", key, [NSNumber numberWithInteger:start], [NSNumber numberWithInteger:stop]]];
}

- (CocoaPromise *)zremrangebyrank:(id)key range:(NSRange)range {
    return [self zremrangebyrank:key start:range.location stop:(range.location + range.length)];
}

#pragma mark ZREMRANGEBYSCORE
- (CocoaPromise *)zremrangebyscore:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZREMRANGEBYSCORE", key, min, max]];
}

#pragma mark ZREVRANGE
- (CocoaPromise *)zrevrange:(id)key start:(double)start stop:(double)stop {
    return [self command: @[@"ZREVRANGE", key, [NSNumber numberWithDouble:start], [NSNumber numberWithDouble:stop]]];
}

- (CocoaPromise *)zrevrangeWithScores:(id)key start:(double)start stop:(double)stop {
    return PromiseNSDict( [self command: @[@"ZREVRANGE", key, [NSNumber numberWithDouble:start], [NSNumber numberWithDouble:stop], @"WITHSCORES"]], toDouble);
}

#pragma mark ZREVRANGEBYSCORE
- (CocoaPromise *)zrevrangebyscore:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZREVRANGEBYSCORE", key, min, max]];
}

- (CocoaPromise *)zrevrangebyscoreWithScores:(id)key min:(id)min max:(id)max {
    return [self command: @[@"ZREVRANGEBYSCORE", key, min, max, @"WITHSCORES"]];
}

- (CocoaPromise *)zrevrangebyscore:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZREVRANGEBYSCORE", key, min, max, @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise *)zrevrangebyscoreWithScores:(id)key min:(id)min max:(id)max offset:(NSInteger)offset count:(NSInteger)count {
    return [self command: @[@"ZREVRANGEBYSCORE", key, min, max, @"WITHSCORES", @"LIMIT", [NSNumber numberWithInteger:offset], [NSNumber numberWithInteger:count]]];
}

- (CocoaPromise *)zrevrangebyscore:(id)key min:(id)min max:(id)max range: (NSRange)range {
    return [self zrevrangebyscore:key min:min max:max offset:range.location count:range.length];
}

- (CocoaPromise *)zrevrangebyscoreWithScores:(id)key min:(id)min max:(id)max range:(NSRange)range {
    return [self zrevrangebyscoreWithScores:key min:min max:max offset:range.location count:range.length];
}

#pragma mark ZREVRANK
- (CocoaPromise *)zrevrank:(id)key member:(id)member {
    return [self command: @[@"ZREVRANK", key, member]];
}

#pragma mark ZSCORE
- (CocoaPromise *)zscore:(id)key member:(id)member {
    return [[self command: @[@"ZSCORE", key, member]] then: toDouble];
}

#pragma mark ZUNIONSTORE
- (NSMutableArray*) zunionstoreArgs: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights {
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"ZUNIONSTORE", dst, [NSNumber numberWithInteger:keys.count], nil];
    [args addObjectsFromArray: keys];
    [args addObject: @"WEIGHTS"];
    [args addObjectsFromArray: weights];
    return args;
}

- (CocoaPromise *)zunionstore:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    return [self command: [self zunionstoreArgs:dst keys:keys weights:weights]];
}

- (CocoaPromise *)zunionstoreSum:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zunionstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"SUM"]];
    return [self command: args];
}

- (CocoaPromise *)zunionstoreMin:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zunionstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"MIN"]];
    return [self command: args];
}

- (CocoaPromise *)zunionstoreMax:(id)dst keys:(NSArray *)keys weights:(NSArray *)weights {
    NSMutableArray* args = [self zunionstoreArgs:dst keys:keys weights:weights];
    [args addObjectsFromArray: @[@"AGGREGATE", @"MAX"]];
    return [self command: args];
}

#pragma mark ZSCAN

- (CocoaPromise *)zscan: (id)key match: (NSString *)pattern {
    CocoaPromise* result = [CocoaPromise new];
    
    CocoaPromise* firstCursor = [self command: @[@"ZSCAN", key, [NSNumber numberWithInteger:0], @"MATCH", pattern]];
    CollectZSetKeys(self, key, firstCursor, pattern, result, [NSMutableDictionary new]);
    
    return result;
}

#pragma mark - CONNECTION

#pragma mark - AUTH
- (CocoaPromise *)auth:(id)password {
    return [self command: @[@"AUTH", password]];
}

#pragma mark ECHO
- (CocoaPromise *)echo:(id)message {
    return [self command: @[@"ECHO", message]];
}

#pragma mark PING
- (CocoaPromise *)ping {
    return [self command: @[@"PING"]];
}

#pragma mark QUIT
- (CocoaPromise *)quit {
    return [self command: @[@"QUIT"]];
}

#pragma mark SELECT
- (CocoaPromise *)select: (NSInteger)index {
    return [self command: @[@"SELECT", [NSNumber numberWithInteger:index]]];
}

#pragma mark - GEO

#pragma mark - GEOADD
- (CocoaPromise *)geoadd:(id)key longitude:(double)lon latitude:(double)lat member:(id)member {
    return [self command: @[@"GEOADD", key, [NSNumber numberWithDouble:lon], [NSNumber numberWithDouble:lat], member]];
}

- (CocoaPromise *)geoadd:(id)key values:(NSArray *)values {
    return [self command:@[@"GEOADD", key] arguments:values];
}

#pragma mark GEOHASH
- (CocoaPromise *)geohash:(id)key member:(id)member {
    return [self command: @[@"GEOHASH", key, member]];
}

- (CocoaPromise *)geohash:(id)key members:(NSArray *)members {
    return [self command:@[@"GEOHASH", key] arguments:members];
}

#pragma mark GEOPOS
- (CocoaPromise *)geopos:(id)key member:(id)member {
    return [[self command: @[@"GEOPOS", key, member]] then: toGeoPos];
}

- (CocoaPromise *)geopos:(id)key members:(NSArray *)members {
    return [[self command:@[@"GEOPOS", key] arguments:members] then: toGeoPos];
}

#pragma mark GEODIST
- (CocoaPromise*) geodist: (id)key from: (id)from to: (id)to {
    return [[self command: @[@"GEODIST", key, from, to]] then:toDouble];
}

- (CocoaPromise*) geodist: (id)key from: (id)from to: (id)to unit: (NSString*)unit {
    return [[self command: @[@"GEODIST", key, from, to, unit]] then:toDouble];
}

#pragma mark GEORADIUS
- (CocoaPromise *)georadius:(id)key longitude:(double)lon latitude:(double)lat radius:(double)r unit:(NSString *)unit {
    return [self command: @[@"GEORADIUS", key, [NSNumber numberWithDouble:lon], [NSNumber numberWithDouble:lat], [NSNumber numberWithDouble:r], unit]];
}

- (CocoaPromise *)georadius:(id)key longitude:(double)lon latitude:(double)lat radius:(double)r unit:(NSString *)unit options:(NSArray *)options {
    return [self command:@[@"GEORADIUS", key, [NSNumber numberWithDouble:lon], [NSNumber numberWithDouble:lat], [NSNumber numberWithDouble:r], unit] arguments:options];
}

#pragma mark GEORADIUSBYMEMBER
- (CocoaPromise *)georadiusbymember:(id)key member: (id)member radius:(double)r unit:(NSString *)unit {
    return [self command: @[@"GEORADIUSBYMEMBER", key, member, [NSNumber numberWithDouble:r], unit]];
}

- (CocoaPromise *)georadiusbymember:(id)key member: (id)member radius:(double)r unit:(NSString *)unit options:(NSArray *)options {
    return [self command:@[@"GEORADIUSBYMEMBER", key, member, [NSNumber numberWithDouble:r], unit] arguments:options];
}

#pragma mark - HYPERLOGLOG

#pragma mark - PFADD
- (CocoaPromise *)pfadd:(id)key element:(id)element {
    return [self command: @[@"PFADD", key, element]];
}

- (CocoaPromise *)pfadd:(id)key elements:(NSArray *)elements {
    return [self command:@[@"PFADD", key] arguments:elements];
}

#pragma mark PFCOUNT
- (CocoaPromise *)pfcount:(id)key {
    return [self command: @[@"PFCOUNT", key]];
}

- (CocoaPromise *)pfcountKeys:(NSArray *)keys {
    return [self command:@[@"PFCOUNT"] arguments:keys];
}

#pragma mark PFMERGE
- (CocoaPromise *)pfmerge:(id)dst source:(id)src {
    return [self command: @[@"PFMERGE", dst, src]];
}

- (CocoaPromise *)pfmerge:(id)dst sources:(NSArray *)srcs {
    return [self command:@[@"PFMERGE", dst] arguments:srcs];
}

#pragma mark - TRANSACTIONS

#pragma mark - DISCARD
- (CocoaPromise*) discard {
    return [self command: @[@"DISCARD"]];
}

#pragma mark EXEC
- (CocoaPromise*) exec {
    return [self command: @[@"EXEC"]];
}

#pragma mark MULTI
- (CocoaPromise*) multi {
    return [self command: @[@"MULTI"]];
}

#pragma mark UNWATCH
- (CocoaPromise*) unwatch {
    return [self command: @[@"UNWATCH"]];
}

#pragma mark WATCH
- (CocoaPromise *)watch:(id)key {
    return [self command: @[@"WATCH"]];
}

- (CocoaPromise *)watchKeys:(NSArray *)keys {
    return [self command:@[@"WATCH"] arguments:keys];
}

#pragma mark - BGREWRITEAOF
- (CocoaPromise*) bgrewriteaof {
    return [self command:@[@"BGREWRITEAOF"]];
}

#pragma mark BGSAVE
- (CocoaPromise*) bgsave {
    return [self command:@[@"BGSAVE"]];
}

#pragma mark CLIENT KILL
- (CocoaPromise *)clientKillByAddress:(NSString *)ipaddr {
    return [self command:@[@"CLIENT", @"KILL", @"ADDR", ipaddr]];
}

- (CocoaPromise *)clientKillByID:(NSString *)clientId {
    return [self command:@[@"CLIENT", @"KILL", @"ID", clientId]];
}

- (CocoaPromise *)clientKillByAddress:(NSString *)ipaddr options: (NSArray*)options {
    return [self command:@[@"CLIENT", @"KILL", @"ADDR", ipaddr] arguments:options];
}

- (CocoaPromise *)clientKillByID:(NSString *)clientId options:(NSArray *)options {
    return [self command:@[@"CLIENT", @"KILL", @"ID", clientId] arguments:options];
}

#pragma mark CLIENT LIST
- (CocoaPromise *)clientList {
    return [[self command: @[@"CLIENT", @"LIST"]] then:^id(id value) {
        return [self parseClientList:value];
    }];
}

#pragma mark CLIENT GETNAME
- (CocoaPromise *)clientGetName {
    return [self command:@[@"CLIENT", @"GETNAME"]];
}

#pragma mark CLIENT PAUSE
- (CocoaPromise *)clientPause:(NSInteger)ms {
    return [self command:@[@"CLIENT", @"PAUSE", [NSNumber numberWithInteger:ms]]];
}

#pragma mark CLIENT SETNAME 
- (CocoaPromise *)clientSetName:(id)name {
    return [self command:@[@"CLIENT", @"SETNAME", name]];
}

#pragma mark COMMAND
- (CocoaPromise *)commandList {
    return [self command:@[@"COMMAND"]];
}

#pragma mark COMMAND COUNT
- (CocoaPromise *)commandCount {
    return [self command:@[@"COMMAND", @"COUNT"]];
}

#pragma mark COMMAND GETKEYS
- (CocoaPromise*) commandGetKeys: (NSArray*)values {
    return [self command:@[@"COMMAND", @"GETKEYS"] arguments:values];
}

#pragma mark COMMAND INFO
- (CocoaPromise*) commandInfo:(NSString *)name {
    return [self command:@[@"COMMAND", @"INFO", name]];
}

- (CocoaPromise *)commandInfoForNames:(NSArray *)names {
    return [self command:@[@"COMMAND", @"INFO"] arguments:names];
}

#pragma mark CONFIG GET
- (CocoaPromise *)configGet:(NSString *)parameter {
    return PromiseNSDict( [self command:@[@"CONFIG", @"GET", parameter]], nil );
}

#pragma mark CONFIG REWRITE
- (CocoaPromise *)configRewrite {
    return [self command:@[@"CONFIG", @"REWRITE"]];
}

#pragma mark CONFIG SET
- (CocoaPromise *)configSet:(NSString *)parameter value:(NSString *)value {
    return [self command:@[@"CONFIG", @"SET", parameter, value]];
}

#pragma mark CONFIG RESETSTAT
- (CocoaPromise *)configResetStat {
    return [self command:@[@"CONFIG", @"RESETSTAT"]];
}

#pragma mark DBSIZE
- (CocoaPromise *)dbsize {
    return [self command:@[@"DBSIZE"]];
}

#pragma mark FLUSHALL
- (CocoaPromise *)flushall {
    return [self command:@[@"FLUSHALL"]];
}

#pragma mark FLUSHDB
- (CocoaPromise *)flushdb {
    return [self command:@[@"FLUSHDB"]];
}

#pragma mark INFO
- (CocoaPromise *)info {
    return [[self command:@[@"INFO"]] then: parseServerInfo];
}

- (CocoaPromise *)info: (NSString*)section {
    return [[self command:@[@"INFO", section]] then:^id(id value) {
        NSDictionary* dict = parseServerInfo(value);
        return dict[section];
    }];
}

#pragma mark LASTSAVE
- (CocoaPromise *)lastsave {
    return [[self command:@[@"LASTSAVE"]] then:^id(id value) {
        return [NSDate dateWithTimeIntervalSince1970: [value integerValue]];
    }];
}

#pragma mark MONITOR
- (CocoaPromise*) monitor {
    CocoaPromise* result = [CocoaPromise new];

    self.ctx->data = (void*) CFBridgingRetain(result);
    
    int rc = redisAsyncCommand(self.ctx,
                               monitorCallback,
                               NULL,
                               "MONITOR");
    
    if( rc != REDIS_OK ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: self.ctx->errstr]
                                           code: self.ctx->err
                                       userInfo: nil];
        [result reject: err];
    }
    
    return result;
}

#pragma mark ROLE
- (CocoaPromise*) role {
    return [[self command:@[@"ROLE"]] then:^id(id value) {
        if( [value[0] isEqualToString: @"master"] ) {
            return ParseMasterRole(value);
        } else {
            return ParseSlaveRole(value);
        }
    }];
}

#pragma mark SAVE
- (CocoaPromise *)save {
    return [self command:@[@"SAVE"]];
}

#pragma mark SHUTDOWN
- (CocoaPromise *)shutdown {
    return [self command:@[@"SHUTDOWN"]];
}

- (CocoaPromise *)shutdownAndSave:(BOOL)save {
    return [self command: @[@"SHUTDOWN", save ? @"SAVE" : @"NOSAVE"]];
}

#pragma mark SLAVEOF
- (CocoaPromise *)slaveof:(NSString *)address {
    int port = 6379;
    NSRange pos = [address rangeOfString: @":"];

    if( pos.location != NSNotFound ) {
        port = [[address substringFromIndex: pos.location + 1] intValue];
        address = [address substringToIndex: pos.location];
    }

    return [self slaveofHost:address port:port];
}

- (CocoaPromise *)slaveofHost:(NSString *)host port:(NSInteger)port {
    return [self command:@[@"SAVEOF", host, [NSNumber numberWithInteger:port]]];
}

#pragma mark SLOWLOG
- (CocoaPromise *)slowlog:(NSString *)subcommand {
    return [[self command: @[@"SLOWLOG", subcommand]] then: parseSlowLog];
}

- (CocoaPromise *)slowlog:(NSString *)subcommand argument:(NSString *)argument {
    return [[self command: @[@"SLOWLOG", subcommand, argument]] then: parseSlowLog];
}

#pragma mark SYNC
- (CocoaPromise*) sync {
    return [self command:@[@"SYNC"]];
}

#pragma mark TIME
- (CocoaPromise*) time {
    return [[self command:@[@"TIME"]] then:^id(id value) {
        NSInteger timestamp = [value[0] integerValue];
        return [NSDate dateWithTimeIntervalSince1970: timestamp];
    }];
}

#pragma mark - SCRIPTING

#pragma mark - EVAL
- (CocoaPromise *)_eval: (NSString*)cmd script: (NSString *)script keys:(NSArray *)keys arguments:(NSArray *)arguments {
    NSMutableArray* args = [NSMutableArray arrayWithObjects: cmd, script, [NSNumber numberWithInteger:keys.count], nil];
    [args addObjectsFromArray: keys];
    [args addObjectsFromArray: arguments];
    return [self command: args];
}

- (CocoaPromise *)eval:(NSString *)script keys:(NSArray *)keys arguments:(NSArray *)arguments {
    return [self _eval:@"EVAL" script:script keys:keys arguments:arguments];
}

#pragma mark - EVAL
- (CocoaPromise *)evalsha:(NSString *)sha keys:(NSArray *)keys arguments:(NSArray *)arguments {
    return [self _eval:@"EVALSHA" script:sha keys:keys arguments:arguments];
}

#pragma mark SCRIPT EXISTS
- (CocoaPromise *)scriptExists:(NSString *)sha {
    return [[self command:@[@"SCRIPT", @"EXISTS", sha]] then:^id(id value) {
        return value[0];
    }];
}

- (CocoaPromise *)scriptListExists:(NSArray *)shaList {
    return [self command:@[@"SCRIPT", @"EXISTS"] arguments:shaList];
}

#pragma mark SCRIPT FLUSH
- (CocoaPromise *)scriptFlush {
    return [self command:@[@"SCRIPT", @"FLUSH"]];
}

#pragma mark SCRIPT KILL
- (CocoaPromise *)scriptKill {
    return [self command:@[@"SCRIPT", @"KILL"]];
}

#pragma mark SCRIPT LOAD
- (CocoaPromise *)scriptLoad:(NSString *)script {
    return [self command:@[@"SCRIPT", @"LOAD", script]];
}

#pragma mark - PUB/SUB

#pragma mark - PSUBSCRIBE
- (CocoaPromise*) psubscribe: (NSString*)pattern {
    return [self psubscribePatterns: @[pattern]];
}

- (CocoaPromise*) _subscribeCommand: (NSString*)cmd arguments: (NSArray*)args {
    CocoaPromise* result = [CocoaPromise new];
    
    if( !self.isConnected ) {
        NSError* err = [NSError errorWithDomain: @"Not connected" code:0 userInfo:nil];
        [result reject: err];
        return result;
    }
    
    NSMutableArray* command = [NSMutableArray arrayWithObject: cmd];
    [command addObjectsFromArray: args];
    
    const NSUInteger count = command.count;
    const char* argv[count];
    size_t argvlen[count];
    
    for( NSUInteger i = 0; i < count; ++i ) {
        NSAssert([command[i] isKindOfClass:[NSString class]], @"Invalid pub/sub parameter");
        argv   [i] = [command[i] UTF8String];
        argvlen[i] = strlen(argv[i]);
    }
    
    self.ctx->data = (void*) CFBridgingRetain(result);
    
    int rc = redisAsyncCommandArgv(self.ctx,
                                   subscribeCallback,
                                   NULL,
                                   (int) count, argv, argvlen);
    
    if( rc != REDIS_OK ) {
        NSError* err = [NSError errorWithDomain: [NSString stringWithUTF8String: self.ctx->errstr]
                                           code: self.ctx->err
                                       userInfo: nil];
        [result reject: err];
    }
    
    return result;
}

- (CocoaPromise*) psubscribePatterns: (NSArray*)patterns {
    return [self _subscribeCommand: @"PSUBSCRIBE" arguments: patterns];
}

#pragma mark PUBSUB
- (CocoaPromise*) pubsubActiveChannels {
    return [self command:@[@"PUBSUB", @"CHANNELS"]];
}

- (CocoaPromise*) pubsubActiveChannels: (NSString*)pattern {
    return [self command:@[@"PUBSUB", @"CHANNELS", pattern]];
}

- (CocoaPromise*) pubsubSubscribers: (NSArray*)channels {
    return PromiseNSDict( [self command: @[@"PUBSUB", @"NUMSUB"] arguments: channels], toLongLong );
}

- (CocoaPromise*) pubsubPatternsCount {
    return [self command:@[@"PUBSUB", @"NUMPAT"]];
}

#pragma mark PUBLISH
- (CocoaPromise *)publish:(NSString *)channel message:(NSString *)message {
    return [self command:@[@"PUBLISH", channel, message]];
}

#pragma mark PUNSUBSCRIBE
- (CocoaPromise *)punsubscribe {
    return [self punsubscribe: @[]];
}

- (CocoaPromise *)punsubscribe:(NSArray *)patterns {
    return [self _subscribeCommand: @"PUNSUBSCRIBE" arguments: patterns];
}

#pragma mark - SUBSCRIBE
- (CocoaPromise*) subscribe: (NSString*)channel {
    return [self subscribeChannels: @[channel]];
}

- (CocoaPromise*) subscribeChannels: (NSArray*)channels {
    return [self _subscribeCommand: @"SUBSCRIBE" arguments: channels];
}

#pragma mark UNSUBSCRIBE
- (CocoaPromise *)unsubscribe {
    return [self unsubscribe: @[]];
}

- (CocoaPromise *)unsubscribe:(NSArray *)channels {
    return [self _subscribeCommand: @"UNSUBSCRIBE" arguments: channels];
}

#pragma mark - CLUSTER

#pragma mark - CLUSTER ADDSLOTS
- (CocoaPromise*) clusterAddSlot: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"ADDSLOTS", [NSNumber numberWithInteger:slot]]];
}

- (CocoaPromise*) clusterAddSlots: (NSArray*)slots {
    return [self command:@[@"CLUSTER", @"ADDSLOTS"] arguments:slots];
}

#pragma mark CLUSTER COUNT-FAILURE-REPORTS
- (CocoaPromise*) clusterCountFailureReports: (id)nodeId {
    return [self command:@[@"CLUSTER", @"COUNT-FAILURE-REPORTS"]];
}

#pragma mark CLUSTER COUNTKEYSINSLOT
- (CocoaPromise*) clusterCountKeysInSlot: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"COUNTKEYSINSLOT", [NSNumber numberWithInteger:slot]]];
}

#pragma mark - CLUSTER DELSLOTS
- (CocoaPromise*) clusterDelSlot: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"DELSLOTS", [NSNumber numberWithInteger:slot]]];
}

- (CocoaPromise*) clusterDelSlots: (NSArray*)slots {
    return [self command:@[@"CLUSTER", @"DELSLOTS"] arguments:slots];
}

#pragma mark CLUSTER FAILOVER
- (CocoaPromise*) clusterFailoverForce {
    return [self command:@[@"CLUSTER", @"FAILOVER", @"FORCE"]];
}

- (CocoaPromise*) clusterFailoverTakeover {
    return [self command:@[@"CLUSTER", @"FAILOVER", @"TAKEOVER"]];
}

#pragma mark CLUSTER FORGET
- (CocoaPromise*) clusterForget: (NSString*)nodeId {
    return [self command:@[@"CLUSTER", @"FORGET", nodeId]];
}

#pragma mark CLUSTER GETKEYSINSLOT
- (CocoaPromise*) clusterGetKeysInSlot: (NSInteger)slot count:(NSInteger)count {
    return [self command:@[@"CLUSTER", @"GETKEYSINSLOT", [NSNumber numberWithInteger:slot], [NSNumber numberWithInteger:count]]];
}

#pragma mark CLUSTER INFO
- (CocoaPromise *)clusterInfo {
    return PromiseNSDict( [self command:@[@"CLUSTER", @"INFO"]], nil );
}

#pragma mark CLUSTER KEYSLOT
- (CocoaPromise*) clusterKeyslot: (id)key {
    return [self command:@[@"CLUSTER", @"KEYSLOT", key]];
}

#pragma mark CLUSTER MEET
- (CocoaPromise*) clusterMeetIP: (NSString*)ip port: (NSInteger)port {
    return [self command:@[@"CLUSTER", @"MEET", ip, [NSNumber numberWithInteger:port]]];
}

#pragma mark CLUSTER NODES
- (CocoaPromise*) clusterNodes {
    return [[self command: @[@"CLUSTER", @"NODES"]] then:^id(id value) {

        NSMutableArray *result = [NSMutableArray new];
        
        for( NSString* line in [value componentsSeparatedByString: @"\r\n"] ) {
            if( line.length == 0 ) continue;
            NSArray* items = [line componentsSeparatedByString: @" "];
            
            NSDictionary* node = @{
                @"id": items[0],
                @"address": items[1],
                @"flags": items[2],
                @"master": items[3],
                @"ping-sent": [NSDate dateWithTimeIntervalSince1970: [items[4] integerValue]],
                @"ping-recv": [NSDate dateWithTimeIntervalSince1970: [items[5] integerValue]],
                @"config-epoch": items[6],
                @"link-state": items[7],
                @"slot": [items subarrayWithRange: NSMakeRange(8, items.count)]
            };
            
            [result addObject: node];
        }
        
        return result;

    }];
}

#pragma mark CLUSTER REPLICATE
- (CocoaPromise*) clusterReplicate: (NSString*)nodeId {
    return [self command:@[@"CLUSTER", @"REPLICATE", nodeId]];
}

#pragma mark CLUSTER RESET
- (CocoaPromise*) clusterResetHard {
    return [self command:@[@"CLUSTER", @"RESET", @"HARD"]];
}

- (CocoaPromise*) clusterResetSoft {
    return [self command:@[@"CLUSTER", @"RESET", @"SOFT"]];
}

#pragma mark CLUSTER SAVECONFIG
- (CocoaPromise*) clusterSaveConfig {
    return [self command:@[@"CLUSTER", @"SAVECONFIG"]];
}

#pragma mark CLUSTER SET-CONFIG-EPOCH
- (CocoaPromise*) clusterSetConfigEpoch: (NSInteger)epoch {
    return [self command:@[@"CLUSTER", @"SET-CONFIG-EPOCH", [NSNumber numberWithInteger:epoch]]];
}

#pragma mark CLUSTER SETSLOT
- (CocoaPromise*) clusterSetSlotImporting: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"SETSLOT", [NSNumber numberWithInteger:slot], @"IMPORTING"]];
}

- (CocoaPromise*) clusterSetSlotMigrating: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"SETSLOT", [NSNumber numberWithInteger:slot], @"MIGRATING"]];
}

- (CocoaPromise*) clusterSetSlotStable: (NSInteger)slot {
    return [self command:@[@"CLUSTER", @"SETSLOT", [NSNumber numberWithInteger:slot], @"STABLE"]];
}

- (CocoaPromise*) clusterSetSlot: (NSInteger)slot node: (NSString*)nodeId {
    return [self command:@[@"CLUSTER", @"SETSLOT", [NSNumber numberWithInteger:slot], @"NODE", nodeId]];
}

#pragma mark CLUSTER SLAVES
- (CocoaPromise*) clusterSlaves: (NSString*)nodeId {
    return [self command:@[@"CLUSTER", @"SLAVES", nodeId]];
}

#pragma mark CLUSTER SLOTS
- (CocoaPromise*) clusterSlots {
    return [[self command:@[@"CLUSTER", @"SLOTS"]] then:^id(id value) {
        
        NSMutableArray* result = [NSMutableArray new];

        for( NSArray* item in value ) {
            NSMutableArray* replicas = [NSMutableArray new];

            NSDictionary* slotInfo = @{
                @"start-slot": item[0],
                @"end-slot": item[1],
                @"master": [NSString stringWithFormat:@"%@:%@", item[2][0], item[2][1]],
                @"replicas": replicas
            };
            
            for( NSUInteger i = 3; i < item.count; ++i ) {
                NSString* replicaAddr = [NSString stringWithFormat: @"%@:%@", item[i][0], item[i][1]];
                [replicas addObject: replicaAddr];
            }
        
            [result addObject: slotInfo];
        }
        
        return result;
    }];
}


@end

