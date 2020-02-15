//
//  SCAudioSession.h
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/12.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

extern const NSTimeInterval AUSAudioSessionLatency_Background;
extern const NSTimeInterval AUSAudioSessionLatency_Default;
extern const NSTimeInterval AUSAudioSessionLatency_LowLatency;

NS_ASSUME_NONNULL_BEGIN

@interface SCAudioSession : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, assign) Float64 preferredSampleRate;
@property (nonatomic, assign, readonly) Float64 currentSampleRate;
/** 当前I/O缓冲区的持续时间，以秒为单位 */
@property (nonatomic, assign) NSTimeInterval preferredLatency;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, copy) AVAudioSessionCategory category;

- (void)addRouteChangeListener;

@end

NS_ASSUME_NONNULL_END
