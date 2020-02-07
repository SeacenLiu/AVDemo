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

- (instancetype)initWithPath:(NSString*)path;

- (void)startRecord;
- (void)stopRecord;

- (void)playMusicWithPath:(NSString *)path;
- (void)endPlayMusic;

@end

NS_ASSUME_NONNULL_END
