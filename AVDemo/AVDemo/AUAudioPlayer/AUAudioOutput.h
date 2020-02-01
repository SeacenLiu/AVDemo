//
//  AUAudioOutput.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/31.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AUAudioOutputFillDataDelegate <NSObject>

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

@interface AUAudioOutput : NSObject

@property (nonatomic, assign) Float64 sampleRate;
@property (nonatomic, assign) Float64 channels;


- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger) bytePerSample
               filleDataDelegate:(id<AUAudioOutputFillDataDelegate>) fillAudioDataDelegate;

- (BOOL) play;
- (BOOL) stop;

@end


