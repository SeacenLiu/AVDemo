//
//  SCAudioRecorder.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/8.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SCAudioRecorder;
@protocol SCAudioRecorderDelegate <NSObject>

- (void)audioRecorderDidLoadMusicFile:(SCAudioRecorder*)recoder;

- (void)audioRecorderDidPlayProgress:(SCAudioRecorder*)recoder
                            progress:(CGFloat)progress
                       currentSecond:(NSTimeInterval)currentSecond
                         totalSecond:(NSTimeInterval)totalSecond;

- (void)audioRecorderDidCompletePlay:(SCAudioRecorder*)recoder;

@end


@interface SCAudioRecorder : NSObject

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;
/** 音乐音量（范围0~1） */
@property (nonatomic, assign) CGFloat musicVolume;
/** 录音音量（范围0~1） */
@property (nonatomic, assign) CGFloat voiceVolume;

- (instancetype)initWithPath:(NSString*)path;
- (void)startRecord;
- (void)stopRecord;

#pragma mark - 播放器部分
@property (nonatomic, assign, getter=isEnableMusic) BOOL enableMusic;
@property (nonatomic, assign, readonly) NSTimeInterval currentSecond;
@property (nonatomic, assign, readonly) NSTimeInterval totalSecond;
@property (nonatomic, weak) id<SCAudioRecorderDelegate> delegate;

- (void)playMusicWithPath:(NSString *)path;
- (void)endPlayMusic;

@end

NS_ASSUME_NONNULL_END
