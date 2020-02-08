//
//  AUAudioRecorder.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AUAudioRecorder;
@protocol AUAudioRecorderDelegate <NSObject>

- (void)audioRecorderDidLoadMusicFile:(AUAudioRecorder*)recoder;

- (void)audioRecorderDidPlayProgress:(AUAudioRecorder*)recoder
                            progress:(CGFloat)progress
                       currentSecond:(NSTimeInterval)currentSecond
                         totalSecond:(NSTimeInterval)totalSecond;

- (void)audioRecorderDidCompletePlay:(AUAudioRecorder*)recoder;

@end


@interface AUAudioRecorder : NSObject

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;
@property (nonatomic, assign, getter=isEnableBgm) BOOL enableBgm;
/** 背景音乐音量（范围0~1） */
@property (nonatomic, assign) CGFloat bgmVolume;
/** 录音音量（范围0~1） */
@property (nonatomic, assign) CGFloat voiceVolume;
- (instancetype)initWithPath:(NSString*)path;
- (void)startRecord;
- (void)stopRecord;

@property (nonatomic, weak) id<AUAudioRecorderDelegate> delegate;
@property (nonatomic, assign, readonly) NSTimeInterval currentSecond;
@property (nonatomic, assign, readonly) NSTimeInterval totalSecond;
- (void)playMusicWithPath:(NSString *)path;
- (void)endPlayMusic;

@end

NS_ASSUME_NONNULL_END
