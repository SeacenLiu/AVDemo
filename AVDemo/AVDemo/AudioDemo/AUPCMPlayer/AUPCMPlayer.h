//
//  AUPCMPlayer.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    AUPCMPlayerStatusUnknow,
    AUPCMPlayerStatusPlay,
    AUPCMPlayerStatusStop,
    AUPCMPlayerStatusEnd,
} AUPCMPlayerStatus;

@class AUPCMPlayer;
@protocol AUPCMPlayerDelegate <NSObject>

- (void)onPlayerRefreshStatus:(AUPCMPlayer *)player status:(AUPCMPlayerStatus)status;

@end

@interface AUPCMPlayer : NSObject

@property (nonatomic, weak) id<AUPCMPlayerDelegate> delegate;
@property (nonatomic, assign) AUPCMPlayerStatus status;

- (instancetype)initWithFileURL:(NSURL *)fileURL;

- (void)play;
- (void)stop;
- (void)end;

@end


