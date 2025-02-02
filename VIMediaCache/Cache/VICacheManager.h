//
//  VICacheManager.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VICacheConfiguration.h"

extern NSString *VICacheManagerDidUpdateCacheNotification;
extern NSString *VICacheManagerDidFinishCacheNotification;

extern NSString *VICacheConfigurationKey;
extern NSString *VICacheFinishedErrorKey;

@interface VICacheManager : NSObject

+ (void)setCacheDirectory:(NSString *)cacheDirectory;
+ (NSString *)cacheDirectory;


/**
 How often trigger `VICacheManagerDidUpdateCacheNotification` notification

 @param interval Minimum interval
 */
+ (void)setCacheUpdateNotifyInterval:(NSTimeInterval)interval;
+ (NSTimeInterval)cacheUpdateNotifyInterval;

+ (NSString *)cachedFilePathForURL:(NSURL *)url;
+ (VICacheConfiguration *)cacheConfigurationForURL:(NSURL *)url;

+ (void)setFileNameRules:(NSString *(^)(NSURL *url))rules;


/**
 Calculate cached files size

 @param error If error not empty, calculate failed
 @return files size, respresent by `byte`, if error occurs, return -1
 */
+ (unsigned long long)calculateCachedSizeWithError:(NSError **)error;
+ (void)cleanAllCacheWithError:(NSError **)error;
+ (void)cleanCacheForURL:(NSURL *)url error:(NSError **)error;
/// xyh 增量清理 - 超出阀值maxCache 则根据最后访问时间依次清理内存.
+ (void)cleanCacheWithMaxCache:(unsigned long long)maxCache Error:(NSError **)error;
/// 删除错误的缓存文件
+ (void)cleanErrorCachedWithError:(NSError **)error;

/**
 Useful when you upload a local file to the server

 @param filePath local file path
 @param url remote resource url
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.
 */
+ (BOOL)addCacheFile:(NSString *)filePath forURL:(NSURL *)url error:(NSError **)error;

@end
