//
//  SCPlayer.h
//  AUPCMPlayer
//
//  Created by bobo on 2019/12/4.
//  Copyright © 2019年 seacenliu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    SCPlayerStatusUnknow,
    SCPlayerStatusPlay,
    SCPlayerStatusStop,
    SCPlayerStatusEnd,
} SCPlayerStatus;

@class SCPlayer;
@protocol SCPlayerDelegate <NSObject>

- (void)onPlayerRefreshStatus:(SCPlayer *)player status:(SCPlayerStatus)status;

@end

@interface SCPlayer : NSObject

@property (nonatomic, weak) id<SCPlayerDelegate> delegate;
@property (nonatomic, assign) SCPlayerStatus status;

- (instancetype)initWithFileURL:(NSURL *)fileURL;

- (void)play;
- (void)stop;
- (void)end;

@end
