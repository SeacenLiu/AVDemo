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

// TODO
- (void)audioRecorderDidLoadMusicFile:(AUAudioRecorder*)recoder;
- (void)audioRecorderDidCompletePlay:(AUAudioRecorder*)recoder;

@end


@interface AUAudioRecorder : NSObject

@property (nonatomic, weak) id<AUAudioRecorderDelegate> delegate;

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;
@property (nonatomic, assign, getter=isEnableBgm) BOOL enableBgm;
/** 背景音乐音量（范围0~1） */
@property (nonatomic, assign) CGFloat bgmVolume;
/** 录音音量（范围0~1） */
@property (nonatomic, assign) CGFloat voiceVolume;

@property (nonatomic, assign, readonly) NSTimeInterval curTime;
@property (nonatomic, assign, readonly) NSTimeInterval allTime;

- (instancetype)initWithPath:(NSString*)path;

- (void)startRecord;
- (void)stopRecord;

- (void)playMusicWithPath:(NSString *)path;
- (void)endPlayMusic;

@end

NS_ASSUME_NONNULL_END
