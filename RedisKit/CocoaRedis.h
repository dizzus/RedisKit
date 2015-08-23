//
//  CocoaRedis.h
//  RedisKit
//
//  Created by Дмитрий Бахвалов on 20.07.15.
//  Copyright (c) 2015 Dmitry Bakhvalov. All rights reserved.
//

#import "CocoaPromise.h"

extern NSString * const CocoaRedisMonitorNotification;
extern NSString * const CocoaRedisMessageNotification;

@interface CocoaRedis : NSObject

@property (readonly) NSString* host;
@property (readonly) int port;
@property (readonly) BOOL isConnected;

- (instancetype) init;
- (CocoaPromise*) connectWithHost: (NSString*)serverHost;
- (CocoaPromise*) connectWithHost: (NSString*)serverHost port: (int)serverPort;
- (CocoaPromise*) close;

- (CocoaPromise*) command: (NSArray*)arguments;
- (CocoaPromise*) command: (NSArray*)command arguments: (NSArray*)arguments;

- (CocoaPromise*) version;

#pragma mark - STRINGS

#pragma mark - APPEND
/** http://redis.io/commands/append */
- (CocoaPromise*) append: (id)key value: (id)value;

#pragma mark BITCOUNT
/** http://redis.io/commands/bitcount */
- (CocoaPromise*) bitcount: (id)key;
- (CocoaPromise*) bitcount: (id)key start: (NSInteger)start end: (NSInteger)end;
- (CocoaPromise*) bitcount: (id)key range: (NSRange)range;

#pragma mark BITOP
/** http://redis.io/commands/bitop */
- (CocoaPromise*) bitopAnd: (id)dest key: (id)key;
- (CocoaPromise*) bitopAnd: (id)dest keys: (NSArray*)keys;

- (CocoaPromise*) bitopOr: (id)dest key: (id)key;
- (CocoaPromise*) bitopOr: (id)dest keys: (NSArray*)keys;

- (CocoaPromise*) bitopXor: (id)dest key: (id)key;
- (CocoaPromise*) bitopXor: (id)dest keys: (NSArray*)keys;

- (CocoaPromise*) bitopNot: (id)dest key: (id)key;
- (CocoaPromise*) bitopNot: (id)dest keys: (NSArray*)keys;

#pragma mark BITPOS
/** http://redis.io/commands/bitpos */
- (CocoaPromise*) bitpos: (id)key value: (BOOL)bit;
- (CocoaPromise*) bitpos: (id)key value: (BOOL)bit start: (NSInteger)start;
- (CocoaPromise*) bitpos: (id)key value: (BOOL)bit start: (NSInteger)start end: (NSInteger)end;
- (CocoaPromise*) bitpos: (id)key value: (BOOL)bit range: (NSRange)range;

#pragma mark DECR
/** http://redis.io/commands/decr */
- (CocoaPromise*) decr: (id)key;

#pragma mark DECRBY
/** http://redis.io/commands/decrby */
- (CocoaPromise*) decrby: (id)key value: (int64_t)value;

#pragma mark GET
/** http://redis.io/commands/get */
- (CocoaPromise*) get: (id)key;

#pragma mark GETBIT
/** http://redis.io/commands/getbit */
- (CocoaPromise*) getbit: (id)key offset: (NSInteger)offset;

#pragma mark GETRANGE
/** http://redis.io/commands/getrange */
- (CocoaPromise*) getrange: (id)key start: (NSInteger)start end: (NSInteger)end;
- (CocoaPromise*) getrange: (id)key range: (NSRange)range;

#pragma mark GETSET
/** http://redis.io/commands/getset */
- (CocoaPromise*) getset: (id)key value: (id)value;

#pragma mark INCR
/** http://redis.io/commands/incr */
- (CocoaPromise*) incr: (id)key;

#pragma mark INCRBY
/** http://redis.io/commands/incrby */
- (CocoaPromise*) incrby: (id)key value: (int64_t)value;

#pragma mark INCRBYFLOAT
/** http://redis.io/commands/incrbyfloat */
- (CocoaPromise*) incrbyfloat: (id)key value: (double)value;

#pragma mark MGET
/** http://redis.io/commands/mget */
- (CocoaPromise*) mget: (NSArray*)values;

#pragma mark MSET
/** http://redis.io/commands/mset */
- (CocoaPromise*) mset: (id)key value: (id)value;
- (CocoaPromise*) mset: (NSArray*)values;

#pragma mark MSETNX
/** http://redis.io/commands/msetnx */
- (CocoaPromise*) msetnx: (id)key value: (id)value;
- (CocoaPromise*) msetnx: (NSArray*)values;

#pragma mark PSETEX
/** http://redis.io/commands/psetex */
- (CocoaPromise*) psetex: (id)key milliseconds: (NSInteger)ms value: (id)value;

#pragma mark SET
/** http://redis.io/commands/set */
- (CocoaPromise*) set: (id)key value: (id)value;
- (CocoaPromise*) set: (id)key value: (id)value ex: (NSInteger)sec;
- (CocoaPromise*) set: (id)key value: (id)value px: (NSInteger)ms;
- (CocoaPromise*) set: (id)key value: (id)value options: (NSArray*)options;

#pragma mark SETBIT
/** http://redis.io/commands/setbit */
- (CocoaPromise*) setbit: (id)key offset: (NSInteger)offset value: (BOOL)bit;

#pragma mark SETEX
/** http://redis.io/commands/setex */
- (CocoaPromise*) setex: (id)key seconds: (NSInteger)sec value: (id)value;

#pragma mark SETNX
/** http://redis.io/commands/setnx */
- (CocoaPromise*) setnx: (id)key value: (id)value;

#pragma mark SETRANGE
/** http://redis.io/commands/setrange */
- (CocoaPromise*) setrange: (id)key offset: (NSInteger)offset value: (id)value;

#pragma mark STRLEN
/** http://redis.io/commands/strlen */
- (CocoaPromise*) strlen: (id)key;


#pragma mark - KEYS


#pragma mark - DEL
/** http://redis.io/commands/del */
- (CocoaPromise*) del: (id)key;
- (CocoaPromise*) delKeys: (NSArray*)keys;

#pragma mark DUMP
/** http://redis.io/commands/dump */
- (CocoaPromise*) dump: (id)key;

#pragma mark EXISTS
/** http://redis.io/commands/exists */
- (CocoaPromise*) exists: (id)key;
- (CocoaPromise*) existsKeys: (NSArray*)keys;

#pragma mark EXPIRE
/** http://redis.io/commands/expire */
- (CocoaPromise*) expire: (id)key seconds: (NSInteger)sec;

#pragma mark EXPIREAT
/** http://redis.io/commands/expireat */
- (CocoaPromise*) expireat: (id)key timestamp: (NSUInteger)ts;

#pragma mark KEYS
/** http://redis.io/commands/keys */
- (CocoaPromise*) keys: (id)pattern;

#pragma mark MIGRATE
/** http://redis.io/commands/migrate */
- (CocoaPromise*) migrate: (NSString*)host port: (NSInteger)port key: (id)key db: (NSInteger)db timeout: (NSInteger)msec options: (NSArray*)options;

#pragma mark MOVE
/** http://redis.io/commands/move */
- (CocoaPromise*) move: (id)key db: (NSInteger)db;

#pragma mark OBJECT
/** http://redis.io/commands/object */
- (CocoaPromise*) object: (NSString*)subcommand key: (id)key;
- (CocoaPromise*) object: (NSString*)subcommand keys: (NSArray*)keys;

#pragma mark PERSIST
/** http://redis.io/commands/persist */
- (CocoaPromise*) persist: (id)key;

#pragma mark PEXPIRE
/** http://redis.io/commands/pexpire */
- (CocoaPromise*) pexpire: (id)key milliseconds: (NSInteger)ms;

#pragma mark PEXPIREAT
/** http://redis.io/commands/pexpireat */
- (CocoaPromise*) pexpireat: (id)key timestamp: (uint64_t)ms;

#pragma mark PTTL
/** http://redis.io/commands/pttl */
- (CocoaPromise*) pttl: (id)key;

#pragma mark RANDOMKEY
/** http://redis.io/commands/randomkey */
- (CocoaPromise*) randomkey;

#pragma mark RENAME
/** http://redis.io/commands/rename */
- (CocoaPromise*) rename: (id)key newKey: (id)newKey;

#pragma mark RENAMENX
/** http://redis.io/commands/renamenx */
- (CocoaPromise*) renamenx: (id)key newKey: (id)newKey;

#pragma mark RESTORE
/** http://redis.io/commands/restore */
- (CocoaPromise*) restore: (id)key ttl: (NSInteger)ms value: (NSData*)value;
- (CocoaPromise*) restore: (id)key ttl: (NSInteger)ms value: (NSData*)value restore: (BOOL)restore;

#pragma mark SORT
/** http://redis.io/commands/sort */
- (CocoaPromise*) sort: (id)key options: (NSArray*)options;

#pragma mark TTL
/** http://redis.io/commands/ttl */
- (CocoaPromise*) ttl: (id)key;

#pragma mark TYPE
/** http://redis.io/commands/type */
- (CocoaPromise*) type: (id)key;

/* WAIT: not implemented */
/** http://redis.io/commands/wait */

#pragma mark SCAN
/** http://redis.io/commands/scan */
- (CocoaPromise*) scan: (NSString*)pattern;

#pragma mark - LISTS

#pragma mark - BLPOP
/** http://redis.io/commands/blpop */
- (CocoaPromise*) blpop: (id)key timeout: (NSInteger)sec;
- (CocoaPromise*) blpopKeys: (NSArray*)keys timeout: (NSInteger)sec;

#pragma mark BRPOP
/** http://redis.io/commands/brpop */
- (CocoaPromise*) brpop: (id)key timeout: (NSInteger)sec;
- (CocoaPromise*) brpopKeys: (NSArray*)keys timeout: (NSInteger)sec;

#pragma mark BRPOPLPUSH
/** http://redis.io/commands/brpoplpush */
- (CocoaPromise*) brpop: (id)src lpush: (id)dst timeout: (NSInteger)sec;

#pragma mark LINDEX
/** http://redis.io/commands/lindex */
- (CocoaPromise*) lindex: (id)key value: (NSInteger)index;

#pragma mark LINSERT
/** http://redis.io/commands/linsert */
- (CocoaPromise*) linsert: (id)key before: (id)pivot value: (id)value;
- (CocoaPromise*) linsert: (id)key after:  (id)pivot value: (id)value;

#pragma mark LLEN
/** http://redis.io/commands/llen */
- (CocoaPromise*) llen: (id)key;

#pragma mark LPOP
/** http://redis.io/commands/lpop */
- (CocoaPromise*) lpop: (id)key;

#pragma mark LPUSH
/** http://redis.io/commands/lpush */
- (CocoaPromise*) lpush: (id)key value: (id)value;
- (CocoaPromise*) lpush: (id)key values: (NSArray*)values;

#pragma mark LPUSHX
/** http://redis.io/commands/lpushx */
- (CocoaPromise*) lpushx: (id)key value: (id)value;

#pragma mark LRANGE
/** http://redis.io/commands/lrange */
- (CocoaPromise*) lrange: (id)key start: (NSInteger)start stop: (NSInteger)stop;
- (CocoaPromise*) lrange: (id)key range: (NSRange)range;

#pragma mark LREM
/** http://redis.io/commands/lrem */
- (CocoaPromise*) lrem: (id)key count: (NSInteger)count value: (id)value;

#pragma mark LSET
/** http://redis.io/commands/lset */
- (CocoaPromise*) lset: (id)key index: (NSInteger)index value: (id)value;

#pragma mark LTRIM
/** http://redis.io/commands/ltrim */
- (CocoaPromise*) ltrim: (id)key start: (NSInteger)start stop: (NSInteger)stop;
- (CocoaPromise*) ltrim: (id)key range: (NSRange)range;

#pragma mark RPOP
/** http://redis.io/commands/rpop */
- (CocoaPromise*) rpop: (id)key;

#pragma mark RPOPLPUSH
/** http://redis.io/commands/rpoplpush */
- (CocoaPromise*) rpop: (id)src lpush: (id)dst;

#pragma mark RPUSH
/** http://redis.io/commands/rpush */
- (CocoaPromise*) rpush: (id)key value: (id)value;
- (CocoaPromise*) rpush: (id)key values: (NSArray*)values;

#pragma mark RPUSHX
/** http://redis.io/commands/rpushx */
- (CocoaPromise*) rpushx: (id)key value: (id)value;

#pragma mark - SETS

#pragma mark - SADD
/** http://redis.io/commands/sadd */
- (CocoaPromise*) sadd: (id)key value: (id)value;
- (CocoaPromise*) sadd: (id)key values: (NSArray*)values;

#pragma mark SCARD
/** http://redis.io/commands/scard */
- (CocoaPromise*) scard: (id)key;

#pragma mark SDIFF
/** http://redis.io/commands/sdiff */
- (CocoaPromise*) sdiff: (id)key1 with: (id)key2;
- (CocoaPromise*) sdiff: (id)key keys: (NSArray*)keys;

#pragma mark SDIFFSTORE
/** http://redis.io/commands/sdiffstore */
- (CocoaPromise*) sdiffstore: (id)dst key: (id)key1 with: (id)key2;
- (CocoaPromise*) sdiffstore: (id)dst key: (id)key  keys: (NSArray*)keys;

#pragma mark SINTER
/** http://redis.io/commands/sinter */
- (CocoaPromise*) sinter: (id)key1 with: (id)key2;
- (CocoaPromise*) sinter: (id)key  keys: (NSArray*)keys;

#pragma mark SINTERSTORE
/** http://redis.io/commands/sinterstore */
- (CocoaPromise*) sinterstore: (id)dst key: (id)key1 with: (id)key2;
- (CocoaPromise*) sinterstore: (id)dst key: (id)key  keys: (NSArray*)keys;

#pragma mark SISMEMBER
/** http://redis.io/commands/sismember */
- (CocoaPromise*) sismember: (id)key value: (id)value;

#pragma mark SMEMBERS
/** http://redis.io/commands/smembers */
- (CocoaPromise*) smembers: (id)key;

#pragma mark SMOVE
/** http://redis.io/commands/smove */
- (CocoaPromise*) smove: (id)src destination: (id)dst value: (id)value;

#pragma mark SPOP
/** http://redis.io/commands/spop */
- (CocoaPromise*) spop: (id)key;
- (CocoaPromise*) spop: (id)key count: (NSInteger)count;

#pragma mark SRANDMEMBER
/** http://redis.io/commands/srandmember */
- (CocoaPromise*) srandmember: (id)key;
- (CocoaPromise*) srandmember: (id)key count: (NSInteger)count;

#pragma mark SREM
/** http://redis.io/commands/srem */
- (CocoaPromise*) srem: (id)key value:  (id)value;
- (CocoaPromise*) srem: (id)key values: (NSArray*)values;

#pragma mark SUNION
/** http://redis.io/commands/sunion */
- (CocoaPromise*) sunion: (id)key1 with: (id)key2;
- (CocoaPromise*) sunion: (id)key  keys: (NSArray*)keys;

#pragma mark SUNIONSTORE
/** http://redis.io/commands/sunionstore */
- (CocoaPromise*) sunionstore: (id)dst key: (id)key1 with: (id)key2;
- (CocoaPromise*) sunionstore: (id)dst key: (id)key  keys: (NSArray*)keys;

#pragma mark SSCAN
/** http://redis.io/commands/sscan */
- (CocoaPromise*) sscan: (id)key match: (NSString*)pattern;

#pragma mark - HASHES

#pragma mark - HDEL
/** http://redis.io/commands/hdel */
- (CocoaPromise*) hdel: (id)key field:  (id)field;
- (CocoaPromise*) hdel: (id)key fields: (NSArray*)fields;

#pragma mark HEXISTS
/** http://redis.io/commands/hexists */
- (CocoaPromise*) hexists: (id)key field: (id)field;

#pragma mark HGET
/** http://redis.io/commands/hget */
- (CocoaPromise*) hget: (id)key field: (id)field;

#pragma mark HGETALL
/** http://redis.io/commands/hgetall */
- (CocoaPromise*) hgetall: (id)key;

#pragma mark HINCRBY
/** http://redis.io/commands/hincrby */
- (CocoaPromise*) hincrby: (id)key field: (id)field value: (uint64_t)value;

#pragma mark HINCRBYFLOAT
/** http://redis.io/commands/hincrbyfloat */
- (CocoaPromise*) hincrbyfloat: (id)key field: (id)field value: (double)value;

#pragma mark HKEYS
/** http://redis.io/commands/hkeys */
- (CocoaPromise*) hkeys: (id)key;

#pragma mark HLEN
/** http://redis.io/commands/hlen */
- (CocoaPromise*) hlen: (id)key;

#pragma mark HMGET
/** http://redis.io/commands/hmget */
- (CocoaPromise*) hmget: (id)key field:  (id)field;
- (CocoaPromise*) hmget: (id)key fields: (NSArray*)fields;

#pragma mark HMSET
/** http://redis.io/commands/hmset */
- (CocoaPromise*) hmset: (id)key field: (id)field value: (id)value;
- (CocoaPromise*) hmset: (id)key values: (NSArray*)values;
- (CocoaPromise*) hmset: (id)key dictionary: (NSDictionary*)dict;

#pragma mark HSET
/** http://redis.io/commands/hset */
- (CocoaPromise*) hset: (id)key field: (id)field value: (id)value;

#pragma mark HSETNX
/** http://redis.io/commands/hsetnx */
- (CocoaPromise*) hsetnx: (id)key field: (id)field value: (id)value;

#pragma mark HSTRLEN
/** http://redis.io/commands/hstrlen */
- (CocoaPromise*) hstrlen: (id)key field: (id)field;

#pragma mark HVALS
/** http://redis.io/commands/hvals */
- (CocoaPromise*) hvals: (id)key;

#pragma mark HSCAN
/** http://redis.io/commands/hscan */
- (CocoaPromise*) hscan: (id)key match: (NSString*)pattern;

#pragma mark - SORTED SETS

#pragma mark - ZADD
/** http://redis.io/commands/zadd */
- (CocoaPromise*) zadd: (id)key score: (double)score member: (id)member;
- (CocoaPromise*) zadd: (id)key values: (NSArray*)values;

#pragma mark ZCARD
/** http://redis.io/commands/zcard */
- (CocoaPromise*) zcard: (id)key;

#pragma mark ZCOUNT
/** http://redis.io/commands/zcount */
- (CocoaPromise*) zcount: (id)key min: (id)min max: (id)max;

#pragma mark ZINCRBY
/** http://redis.io/commands/zincrby */
- (CocoaPromise*) zincrby: (id)key value: (double)value member: (id)member;

#pragma mark ZINTERSTORE
/** http://redis.io/commands/zinterstore */
- (CocoaPromise*) zinterstore:    (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zinterstoreSum: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zinterstoreMin: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zinterstoreMax: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;

#pragma mark ZLEXCOUNT
/** http://redis.io/commands/zlexcount */
- (CocoaPromise*) zlexcount: (id)key min: (id)min max: (id)max;

#pragma mark ZRANGE
/** http://redis.io/commands/zrange */
- (CocoaPromise*) zrange: (id)key start: (double)start stop: (double)stop;
- (CocoaPromise*) zrangeWithScores: (id)key start: (double)start stop: (double)stop;

#pragma mark ZRANGEBYLEX
/** http://redis.io/commands/zrangebylex */
- (CocoaPromise*) zrangebylex: (id)key min: (id)min max: (id)max;
- (CocoaPromise*) zrangebylex: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;
- (CocoaPromise*) zrangebylex: (id)key min: (id)min max: (id)max range: (NSRange)range;

#pragma mark ZREVRANGEBYLEX
/** http://redis.io/commands/zrevrangebylex */
- (CocoaPromise*) zrevrangebylex: (id)key min: (id)min max: (id)max;
- (CocoaPromise*) zrevrangebylex: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;
- (CocoaPromise*) zrevrangebylex: (id)key min: (id)min max: (id)max range: (NSRange)range;

#pragma mark ZRANGEBYSCORE
/** http://redis.io/commands/zrangebyscore */
- (CocoaPromise*) zrangebyscore: (id)key min: (id)min max: (id)max;
- (CocoaPromise*) zrangebyscoreWithScores: (id)key min: (id)min max: (id)max;

- (CocoaPromise*) zrangebyscore: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;
- (CocoaPromise*) zrangebyscoreWithScores: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;

- (CocoaPromise*) zrangebyscore: (id)key min: (id)min max: (id)max range: (NSRange)range;
- (CocoaPromise*) zrangebyscoreWithScores: (id)key min: (id)min max: (id)max range: (NSRange)range;

#pragma mark ZRANK
/** http://redis.io/commands/zrank */
- (CocoaPromise*) zrank: (id)key member: (id)member;

#pragma mark ZREM
/** http://redis.io/commands/zrem */
- (CocoaPromise*) zrem: (id)key member:  (id)member;
- (CocoaPromise*) zrem: (id)key members: (NSArray*)members;

#pragma mark ZREMRANGEBYLEX
/** http://redis.io/commands/zremrangebylex */
- (CocoaPromise*) zremrangebylex: (id)key min: (id)min max: (id)max;

#pragma mark ZREMRANGEBYRANK
/** http://redis.io/commands/zremrangebyrank */
- (CocoaPromise*) zremrangebyrank: (id)key start: (NSInteger)start stop: (NSInteger)stop;
- (CocoaPromise*) zremrangebyrank: (id)key range: (NSRange)range;

#pragma mark ZREMRANGEBYSCORE
/** http://redis.io/commands/zremrangebyscore */
- (CocoaPromise*) zremrangebyscore: (id)key min: (id)min max: (id)max;

#pragma mark ZREVRANGE
/** http://redis.io/commands/zrevrage */
- (CocoaPromise*) zrevrange: (id)key start: (double)start stop: (double)stop;
- (CocoaPromise*) zrevrangeWithScores: (id)key start: (double)start stop: (double)stop;

#pragma mark ZREVRANGEBYSCORE
/** http://redis.io/commands/zrevrangebyscore */
- (CocoaPromise*) zrevrangebyscore: (id)key min: (id)min max: (id)max;
- (CocoaPromise*) zrevrangebyscoreWithScores: (id)key min: (id)min max: (id)max;

- (CocoaPromise*) zrevrangebyscore: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;
- (CocoaPromise*) zrevrangebyscoreWithScores: (id)key min: (id)min max: (id)max offset: (NSInteger)offset count: (NSInteger)count;

- (CocoaPromise*) zrevrangebyscore: (id)key min: (id)min max: (id)max range: (NSRange)range;
- (CocoaPromise*) zrevrangebyscoreWithScores: (id)key min: (id)min max: (id)max range: (NSRange)range;

#pragma mark ZREVRANK
/** http://redis.io/commands/zrevrank */
- (CocoaPromise*) zrevrank: (id)key member: (id)member;

#pragma mark ZSCORE
/** http://redis.io/commands/zscore */
- (CocoaPromise*) zscore: (id)key member: (id)member;

#pragma mark ZUNIONSTORE
/** http://redis.io/commands/zunionstore */
- (CocoaPromise*) zunionstore:    (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zunionstoreSum: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zunionstoreMin: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;
- (CocoaPromise*) zunionstoreMax: (id)dst keys: (NSArray*)keys weights: (NSArray*)weights;

#pragma mark ZSCAN
/** http://redis.io/commands/zscan */
- (CocoaPromise*) zscan: (id)key match: (NSString*)pattern;

#pragma mark - CONNECTION

#pragma mark - AUTH
/** http://redis.io/commands/auth */
- (CocoaPromise*) auth: (id)password;

#pragma mark ECHO
/** http://redis.io/commands/echo */
- (CocoaPromise*) echo: (id)message;

#pragma mark PING
/** http://redis.io/commands/ping */
- (CocoaPromise*) ping;

#pragma mark QUIT
/** http://redis.io/commands/quit */
- (CocoaPromise*) quit;

#pragma mark SELECT
/** http://redis.io/commands/select */
- (CocoaPromise*) select: (NSInteger)index;

#pragma mark - GEO

#pragma mark - GEOADD
/** http://redis.io/commands/geoadd */
- (CocoaPromise*) geoadd: (id)key longitude: (double)lon latitude: (double)lat member: (id)member;
- (CocoaPromise*) geoadd: (id)key values: (NSArray*)values;

#pragma mark GEOHASH
/** http://redis.io/commands/geohash */
- (CocoaPromise*) geohash: (id)key member: (id)member;
- (CocoaPromise*) geohash: (id)key members: (NSArray*)members;

#pragma mark GEOPOS
/** http://redis.io/commands/geopos */
- (CocoaPromise*) geopos: (id)key member: (id)member;
- (CocoaPromise*) geopos: (id)key members: (NSArray*)members;

#pragma mark GEODIST
/** http://redis.io/commands/geodist */
- (CocoaPromise*) geodist: (id)key from: (id)from to: (id)to;
- (CocoaPromise*) geodist: (id)key from: (id)from to: (id)to unit: (NSString*)unit;

#pragma mark GEORADIUS
/** http://redis.io/commands/georadius */
- (CocoaPromise*) georadius: (id)key longitude: (double)lon latitude: (double)lat radius: (double)r unit: (NSString*)unit;
- (CocoaPromise*) georadius: (id)key longitude: (double)lon latitude: (double)lat radius: (double)r unit: (NSString*)unit options: (NSArray*)options;

#pragma mark GEORADIUSBYMEMBER
/** http://redis.io/commands/georadiusbymember */
- (CocoaPromise*) georadiusbymember: (id)key member: (id)member radius: (double)r unit: (NSString*)unit;
- (CocoaPromise*) georadiusbymember: (id)key member: (id)member radius: (double)r unit: (NSString*)unit options: (NSArray*)options;


#pragma mark - HYPERLOGLOG

#pragma mark - PFADD
/** http://redis.io/commands/pfadd */
- (CocoaPromise*) pfadd: (id)key element: (id)element;
- (CocoaPromise*) pfadd: (id)key elements: (NSArray*)elements;

#pragma mark PFCOUNT
/** http://redis.io/commands/pcount */
- (CocoaPromise*) pfcount: (id)key;
- (CocoaPromise*) pfcountKeys: (NSArray*)keys;

#pragma mark PFMERGE
/** http://redis.io/commands/pfmerge */
- (CocoaPromise*) pfmerge: (id)dst source: (id)src;
- (CocoaPromise*) pfmerge: (id)dst sources: (NSArray*)srcs;

#pragma mark - TRANSACTIONS

#pragma mark - DISCARD
/** http://redis.io/commands/discard */
- (CocoaPromise*) discard;

#pragma mark - EXEC
/** http://redis.io/commands/exec */
- (CocoaPromise*) exec;

#pragma mark MULTI
/** http://redis.io/commands/multi */
- (CocoaPromise*) multi;

#pragma mark UNWATCH
/** http://redis.io/commands/unwatch */
- (CocoaPromise*) unwatch;

#pragma mark WATCH
/** http://redis.io/commands/watch */
- (CocoaPromise*) watch: (id)key;
- (CocoaPromise*) watchKeys: (NSArray*)keys;

#pragma mark - SERVER

#pragma mark - BGREWRITEAOF
/** http://redis.io/commands/bgrewriteaof */
- (CocoaPromise*) bgrewriteaof;

#pragma mark BGSAVE
/** http://redis.io/commands/bgsave */
- (CocoaPromise*) bgsave;

#pragma mark CLIENT KILL
/** http://redis.io/commands/client-kill */
- (CocoaPromise*) clientKillByAddress: (NSString*)ipaddr;
- (CocoaPromise*) clientKillByID: (NSString*)clientId;
- (CocoaPromise*) clientKillByAddress: (NSString*)ipaddr options: (NSArray*)options;
- (CocoaPromise*) clientKillByID: (NSString*)clientId options: (NSArray*)options;

#pragma mark CLIENT LIST
/** http://redis.io/commands/client-list */
- (CocoaPromise*) clientList;

#pragma mark CLIENT GETNAME
/** http://redis.io/commands/client-getname */
- (CocoaPromise*) clientGetName;

#pragma mark CLIENT SETNAME
/** http://redis.io/commands/client-setname */
- (CocoaPromise*) clientSetName: (id)name;

#pragma mark CLIENT PAUSE
/** http://redis.io/commands/client-pause */
- (CocoaPromise*) clientPause: (NSInteger)ms;

#pragma mark COMMAND
/** http://redis.io/commands/command */
- (CocoaPromise*) commandList;

#pragma mark COMMAND COUNT
/** http://redis.io/commands/command-count */
- (CocoaPromise*) commandCount;

#pragma mark COMMAND GETKEYS
/** http://redis.io/commands/command-getkeys */
- (CocoaPromise*) commandGetKeys: (NSArray*)values;

#pragma mark COMMAND INFO
/** http://redis.io/commands/command-info */
- (CocoaPromise*) commandInfo: (NSString*)name;
- (CocoaPromise*) commandInfoForNames: (NSArray*)names;

#pragma mark CONFIG GET
/** http://redis.io/commands/config-get */
- (CocoaPromise*) configGet: (NSString*)parameter;

#pragma mark CONFIG REWRITE
/** http://redis.io/commands/config-rewrite */
- (CocoaPromise*) configRewrite;

#pragma mark CONFIG SET
/** http://redis.io/commands/config-set */
- (CocoaPromise*) configSet: (NSString*)parameter value: (NSString*)value;

#pragma mark CONFIG RESETSTAT
/** http://redis.io/commands/config-resetstat */
- (CocoaPromise*) configResetStat;

#pragma mark DBSIZE
/** http://redis.io/commands/dbsize */
- (CocoaPromise*) dbsize;

/* DEBUG OBJECT: not implemented */
/** http://redis.io/commands/debug-object */

/* DEBUG SEGFAULT: not implemented */
/** http://redis.io/commands/debug-segfault */

#pragma mark FLUSHALL
/** http://redis.io/commands/flushall */
- (CocoaPromise*) flushall;

#pragma mark FLUSHDB
/** http://redis.io/commands/flushdb */
- (CocoaPromise*) flushdb;

#pragma mark INFO
/** http://redis.io/commands/info */
- (CocoaPromise*) info;
- (CocoaPromise*) info: (NSString*)section;

#pragma mark LASTSAVE
/** http://redis.io/commands/lastsave */
- (CocoaPromise*) lastsave;

#pragma mark MONITOR
/** http://redis.io/commands/monitor */
- (CocoaPromise*) monitor;

#pragma mark ROLE
/** http://redis.io/commands/role */
- (CocoaPromise*) role;

#pragma mark SAVE
/** http://redis.io/commands/save */
- (CocoaPromise*) save;

#pragma mark SHUTDOWN
/** http://redis.io/commands/shutdown */
- (CocoaPromise*) shutdown;
- (CocoaPromise*) shutdownAndSave: (BOOL)save;

#pragma mark SLAVEOF
/** http://redis.io/commands/slaveof */
- (CocoaPromise*) slaveof: (NSString*)address;
- (CocoaPromise*) slaveofHost: (NSString*)host port: (NSInteger)port;

#pragma mark SLOWLOG
/** http://redis.io/commands/slowlog */
- (CocoaPromise*) slowlog: (NSString*)subcommand;
- (CocoaPromise*) slowlog: (NSString*)subcommand argument: (NSString*)argument;

#pragma mark SYNC
/** http://redis.io/commands/sync */
- (CocoaPromise*) sync;

#pragma mark TIME
/** http://redis.io/commands/time */
- (CocoaPromise*) time;

#pragma mark - SCRIPTING

#pragma mark - EVAL
/** http://redis.io/commands/eval */
- (CocoaPromise*) eval: (NSString*)script keys: (NSArray*)keys arguments: (NSArray*)arguments;

#pragma mark EVALSHA
/** http://redis.io/commands/evalsha */
- (CocoaPromise*) evalsha: (NSString*)sha keys: (NSArray*)keys arguments: (NSArray*)arguments;

#pragma mark SCRIPT EXISTS
/** http://redis.io/commands/script-exists */
- (CocoaPromise*) scriptExists: (NSString*)sha;
- (CocoaPromise*) scriptListExists: (NSArray*)shaList;

#pragma mark SCRIPT FLUSH
/** http://redis.io/commands/script-flush */
- (CocoaPromise*) scriptFlush;

#pragma mark SCRIPT KILL
/** http://redis.io/commands/script-kill */
- (CocoaPromise*) scriptKill;

#pragma mark SCRIPT LOAD
/** http://redis.io/commands/script-load */
- (CocoaPromise*) scriptLoad: (NSString*)script;

#pragma mark - PUB/SUB

#pragma mark - PSUBSCRIBE
/** http://redis.io/commands/psubscribe */
- (CocoaPromise*) psubscribe: (NSString*)pattern;
- (CocoaPromise*) psubscribePatterns: (NSArray*)pattern;

#pragma mark PUBSUB
/** http://redis.io/commands/pubsub */
- (CocoaPromise*) pubsubActiveChannels;
- (CocoaPromise*) pubsubActiveChannels: (NSString*)pattern;
- (CocoaPromise*) pubsubSubscribers: (NSArray*)channels;
- (CocoaPromise*) pubsubPatternsCount;

#pragma mark PUBLISH
/** http://redis.io/commands/publish */
- (CocoaPromise*) publish: (NSString*)channel message: (NSString*)message;

#pragma mark PUNSUBSCRIBE
/** http://redis.io/commands/punsubscribe */
- (CocoaPromise*) punsubscribe;
- (CocoaPromise*) punsubscribe: (NSArray*)patterns;

#pragma mark SUBSCRIBE
/** http://redis.io/commands/subscribe */
- (CocoaPromise*) subscribe: (NSString*)channel;
- (CocoaPromise*) subscribeChannels: (NSArray*)channels;

#pragma mark UNSUBSCRIBE
/** http://redis.io/commands/unsubscribe */
- (CocoaPromise*) unsubscribe;
- (CocoaPromise*) unsubscribe: (NSArray*)channels;

#pragma mark - CLUSTER

#pragma mark - CLUSTER ADDSLOTS
/** http://redis.io/commands/cluster-addslots */
- (CocoaPromise*) clusterAddSlot: (NSInteger)slot;
- (CocoaPromise*) clusterAddSlots: (NSArray*)slots;

#pragma mark CLUSTER COUNT-FAILURE-REPORTS
/** http://redis.io/commands/cluster-count-failure-reports */
- (CocoaPromise*) clusterCountFailureReports: (id)nodeId;

#pragma mark CLUSTER COUNTKEYSINSLOT
/** http://redis.io/commands/cluster-countkeysinslot */
- (CocoaPromise*) clusterCountKeysInSlot: (NSInteger)slot;

#pragma mark CLUSTER DELSLOTS
/** http://redis.io/commands/cluster-delslots */
- (CocoaPromise*) clusterDelSlot: (NSInteger)slot;
- (CocoaPromise*) clusterDelSlots: (NSArray*)slots;

#pragma mark CLUSTER FAILOVER
/** http://redis.io/commands/cluster-failover */
- (CocoaPromise*) clusterFailoverForce;
- (CocoaPromise*) clusterFailoverTakeover;

#pragma mark CLUSTER FORGET
/** http://redis.io/commands/cluster-forget */
- (CocoaPromise*) clusterForget: (NSString*)nodeId;

#pragma mark CLUSTER GETKEYSINSLOT
/** http://redis.io/commands/cluster-getkeysinslot */
- (CocoaPromise*) clusterGetKeysInSlot: (NSInteger)slot count: (NSInteger)count;

#pragma mark CLUSTER INFO
/** http://redis.io/commands/cluster-info */
- (CocoaPromise*) clusterInfo;

#pragma mark CLUSTER KEYSLOT
/** http://redis.io/commands/cluster-keyslot */
- (CocoaPromise*) clusterKeyslot: (id)key;

#pragma mark CLUSTER MEET
/** http://redis.io/commands/cluster-meet */
- (CocoaPromise*) clusterMeetIP: (NSString*)ip port: (NSInteger)port;

#pragma mark CLUSTER NODES
/** http://redis.io/commands/cluster-nodes */
- (CocoaPromise*) clusterNodes;

#pragma mark CLUSTER REPLICATE
/** http://redis.io/commands/cluster-replicate */
- (CocoaPromise*) clusterReplicate: (NSString*)nodeId;

#pragma mark CLUSTER RESET
/** http://redis.io/commands/cluster-reset */
- (CocoaPromise*) clusterResetHard;
- (CocoaPromise*) clusterResetSoft;

#pragma mark CLUSTER SAVECONFIG
/** http://redis.io/commands/cluster-saveconfig */
- (CocoaPromise*) clusterSaveConfig;

#pragma mark CLUSTER SET-CONFIG-EPOCH
/** http://redis.io/commands/cluster-set-config-epoch */
- (CocoaPromise*) clusterSetConfigEpoch: (NSInteger)epoch;

#pragma mark CLUSTER SETSLOT
/** http://redis.io/commands/cluster-setslot */
- (CocoaPromise*) clusterSetSlotImporting: (NSInteger)slot;
- (CocoaPromise*) clusterSetSlotMigrating: (NSInteger)slot;
- (CocoaPromise*) clusterSetSlotStable: (NSInteger)slot;
- (CocoaPromise*) clusterSetSlot: (NSInteger)slot node: (NSString*)nodeId;

#pragma mark CLUSTER SLAVES
/** http://redis.io/commands/cluster-slaves */
- (CocoaPromise*) clusterSlaves: (NSString*)nodeId;

#pragma mark CLUSTER SLOTS
/** http://redis.io/commands/cluster-slots */
- (CocoaPromise*) clusterSlots;

@end
