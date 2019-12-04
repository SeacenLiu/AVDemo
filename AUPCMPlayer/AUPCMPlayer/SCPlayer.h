//
//  SCPlayer.h
//  AUPCMPlayer
//
//  Created by bobo on 2019/12/4.
//  Copyright © 2019年 seacenliu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SCPlayer;
@protocol SCPlayerDelegate <NSObject>

// 播放结束回调
- (void)onPlayToEnd:(SCPlayer *)player;

@end

@interface SCPlayer : NSObject

@property (nonatomic, weak) id<SCPlayerDelegate> delegate;

- (instancetype)initWithFileURL:(NSURL *)fileURL;

- (void)play;

- (double)getCurrentTime;

@end
