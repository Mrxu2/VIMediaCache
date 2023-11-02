//
//  VICacheManager.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VICacheManager.h"
#import "VIMediaDownloader.h"
#import "NSString+VIMD5.h"

NSString *VICacheManagerDidUpdateCacheNotification = @"VICacheManagerDidUpdateCacheNotification";
NSString *VICacheManagerDidFinishCacheNotification = @"VICacheManagerDidFinishCacheNotification";

NSString *VICacheConfigurationKey = @"VICacheConfigurationKey";
NSString *VICacheFinishedErrorKey = @"VICacheFinishedErrorKey";

static NSString *kMCMediaCacheDirectory;
static NSTimeInterval kMCMediaCacheNotifyInterval;
static NSString *(^kMCFileNameRules)(NSURL *url);

@implementation VICacheManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setCacheDirectory:[NSTemporaryDirectory() stringByAppendingPathComponent:@"vimedia"]];
        [self setCacheUpdateNotifyInterval:0.1];
    });
}


+ (dispatch_queue_t)cacheCleanupQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.XYH_NZGO.cacheCleanupQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

+ (void)setCacheDirectory:(NSString *)cacheDirectory {
    kMCMediaCacheDirectory = cacheDirectory;
}

+ (NSString *)cacheDirectory {
    return kMCMediaCacheDirectory;
}

+ (void)setCacheUpdateNotifyInterval:(NSTimeInterval)interval {
    kMCMediaCacheNotifyInterval = interval;
}

+ (NSTimeInterval)cacheUpdateNotifyInterval {
    return kMCMediaCacheNotifyInterval;
}

+ (void)setFileNameRules:(NSString *(^)(NSURL *url))rules {
    kMCFileNameRules = rules;
}

+ (NSString *)cachedFilePathForURL:(NSURL *)url {
    NSString *pathComponent = nil;
    if (kMCFileNameRules) {
        pathComponent = kMCFileNameRules(url);
    } else {
        pathComponent = [url.absoluteString vi_md5];
        pathComponent = [pathComponent stringByAppendingPathExtension:url.pathExtension];
    }
    return [[self cacheDirectory] stringByAppendingPathComponent:pathComponent];
}

+ (VICacheConfiguration *)cacheConfigurationForURL:(NSURL *)url {
    NSString *filePath = [self cachedFilePathForURL:url];
    VICacheConfiguration *configuration = [VICacheConfiguration configurationWithFilePath:filePath];
    return configuration;
}

+ (unsigned long long)calculateCachedSizeWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self cacheDirectory];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];
    unsigned long long size = 0;
    if (files) {
        for (NSString *path in files) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:path];
            NSDictionary<NSFileAttributeKey, id> *attribute = [fileManager attributesOfItemAtPath:filePath error:error];
            if (!attribute) {
                size = -1;
                break;
            }
            
            size += [attribute fileSize];
        }
    }
    return size;
}

+ (void)cleanAllCacheWithError:(NSError **)error {
    // Find downloaing file
    NSMutableSet *downloadingFiles = [NSMutableSet set];
    [[[VIMediaDownloaderStatus shared] urls] enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *file = [self cachedFilePathForURL:obj];
        [downloadingFiles addObject:file];
        NSString *configurationPath = [VICacheConfiguration configurationFilePathForFilePath:file];
        [downloadingFiles addObject:configurationPath];
    }];
    
    // Remove files
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self cacheDirectory];
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];
    if (files) {
        for (NSString *path in files) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:path];
            if ([downloadingFiles containsObject:filePath]) {
                continue;
            }
            if (![fileManager removeItemAtPath:filePath error:error]) {
                break;
            }
        }
    }
}

+ (void)cleanCacheForURL:(NSURL *)url error:(NSError **)error {
    if ([[VIMediaDownloaderStatus shared] containsURL:url]) {
        NSString *description = [NSString stringWithFormat:NSLocalizedString(@"Clean cache for url `%@` can't be done, because it's downloading", nil), url];
        if (error) {
            *error = [NSError errorWithDomain:@"com.mediadownload" code:2 userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [self cachedFilePathForURL:url];
    
    if ([fileManager fileExistsAtPath:filePath]) {
        if (![fileManager removeItemAtPath:filePath error:error]) {
            return;
        }
    }
    
    NSString *configurationPath = [VICacheConfiguration configurationFilePathForFilePath:filePath];
    if ([fileManager fileExistsAtPath:configurationPath]) {
        if (![fileManager removeItemAtPath:configurationPath error:error]) {
            return;
        }
    }
}


+ (void)cleanCacheWithMaxCache:(unsigned long long)maxCache Error:(NSError **)error {
    // 使用串行队列来处理清理请求
    dispatch_queue_t cleanupQueue = [self cacheCleanupQueue];
    
    dispatch_async(cleanupQueue, ^{

    // 获取文件夹大小
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self cacheDirectory];

    NSError *attributesError = nil;
    NSDictionary *cacheAttributes = [fileManager attributesOfItemAtPath:cacheDirectory error:&attributesError];

    if (attributesError) {
        // 处理获取属性时的错误
        if (error) {
            *error = attributesError;
        }
        return;
    }

    NSNumber *fileSizeNumber = cacheAttributes[NSFileSize];

    if (fileSizeNumber) {
        unsigned long long totalSize = [fileSizeNumber unsignedLongLongValue];

        if (totalSize > maxCache) {
            // Find downloading file
            NSMutableSet *downloadingFiles = [NSMutableSet set];
            [[[VIMediaDownloaderStatus shared] urls] enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, BOOL * _Nonnull stop) {
                NSString *file = [self cachedFilePathForURL:obj];
                [downloadingFiles addObject:file];
                NSString *configurationPath = [VICacheConfiguration configurationFilePathForFilePath:file];
                [downloadingFiles addObject:configurationPath];
            }];

            // Remove files
            NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];

            if (files) {
                NSArray *sortedFiles = [files sortedArrayUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
                    NSString *filePath1 = [cacheDirectory stringByAppendingPathComponent:file1];
                    NSString *filePath2 = [cacheDirectory stringByAppendingPathComponent:file2];

                    if ([downloadingFiles containsObject:filePath1]) {
                        return NSOrderedDescending;
                    } else if ([downloadingFiles containsObject:filePath2]) {
                        return NSOrderedAscending;
                    } else {
                        // 根据最后的访问时间
                        NSDate *lastAccessDate1 = [fileManager attributesOfItemAtPath:filePath1 error:nil][NSFileModificationDate];
                        NSDate *lastAccessDate2 = [fileManager attributesOfItemAtPath:filePath2 error:nil][NSFileModificationDate];
                        return [lastAccessDate1 compare:lastAccessDate2];

                    }
                }];

                for (NSString *fileName in sortedFiles) {
                    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:fileName];

                    if (![downloadingFiles containsObject:filePath]) {
                        // 查询删除文件的大小
                        NSDictionary<NSFileAttributeKey, id> *attribute = [fileManager attributesOfItemAtPath:filePath error:error];
                        unsigned long long attributeSize = attribute ? [attribute fileSize] : -1;
                        // 删除文件并检查删除结果
                        NSError *deleteError = nil;
                        if ([fileManager removeItemAtPath:filePath error:&deleteError]) {
                            totalSize -= attributeSize;
                            if (totalSize <= maxCache) {
                                break; // 停止删除文件，因为缓存大小已经在阈值内
                            }
                        } else {
                            // 处理删除文件时的错误
                            if (error) {
                                *error = deleteError;
                            }
                        }

                    }
                }
            }
        }
    }
    });
}

+ (BOOL)addCacheFile:(NSString *)filePath forURL:(NSURL *)url error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *cachePath = [VICacheManager cachedFilePathForURL:url];
    NSString *cacheFolder = [cachePath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:cacheFolder]) {
        if (![fileManager createDirectoryAtPath:cacheFolder
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:error]) {
            return NO;
        }
    }
    
    if (![fileManager copyItemAtPath:filePath toPath:cachePath error:error]) {
        return NO;
    }
    
    if (![VICacheConfiguration createAndSaveDownloadedConfigurationForURL:url error:error]) {
        [fileManager removeItemAtPath:cachePath error:nil]; // if remove failed, there is nothing we can do.
        return NO;
    }
    
    return YES;
}

@end
