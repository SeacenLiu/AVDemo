//
//  SCVideoPlayerViewController.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/2.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVSynchronizer.h"
#import "SCVideoOutput.h"
#import "SCAudioOutput.h"

@interface SCVideoPlayerViewController : UIViewController

@property(nonatomic, retain) AVSynchronizer*                synchronizer;
@property(nonatomic, retain) NSString*                      videoFilePath;
@property(nonatomic, assign) BOOL                           usingHWCodec;
@property(nonatomic, weak) id<PlayerStateDelegate>          playerStateDelegate;


+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                          playerStateDelegate:(id)playerStateDelegate
                                   parameters:(NSDictionary *)parameters;

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL) usingHWCodec
                          playerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate
                                   parameters: (NSDictionary *)parameters
                  outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL) usingHWCodec
                playerStateDelegate:(id) playerStateDelegate
                         parameters:(NSDictionary *)parameters;

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL) usingHWCodec
                playerStateDelegate:(id) playerStateDelegate
                         parameters:(NSDictionary *)parameters
        outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

- (void)play;

- (void)pause;

- (void)stop;

- (void)restart;

- (BOOL)isPlaying;

- (UIImage *)movieSnapshot;

- (SCVideoOutput*)createVideoOutputInstance;
- (SCVideoOutput*)getVideoOutputInstance;

@end
