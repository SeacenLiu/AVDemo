//
//  SCAudioOutput.h
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SCFillDataDelegate <NSObject>

/// 填充音频数据
/// @discuss 需要通过该代理方法设置sampleBuffer，用于音频频渲染，注意该方法并不在主线程中调用
/// @param sampleBuffer 音频数据
/// @param frameNum 帧数
/// @param channels 声道数
/// @return 暂定1为成功，0为失败
- (NSInteger)fillAudioData:(SInt16*)sampleBuffer
                 numFrames:(NSInteger)frameNum
               numChannels:(NSInteger)channels;

@end

/**
 * 音频输出模块
 * 职责:
 * 1. 在单独线程中进行音频渲染代理回调
 */
@interface SCAudioOutput : NSObject

@property (nonatomic, assign) Float64 sampleRate;    // 采集率
@property (nonatomic, assign) Float64 channels;      // 声道数

- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger)bytePerSample
               filleDataDelegate:(id<SCFillDataDelegate>)fillAudioDataDelegate;

- (BOOL)play;
- (BOOL)stop;

@end
