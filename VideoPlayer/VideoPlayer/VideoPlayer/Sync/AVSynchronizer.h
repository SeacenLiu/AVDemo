//
//  AVSynchronizer.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/2.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#define TIMEOUT_DECODE_ERROR            20
#define TIMEOUT_BUFFER                  10

extern NSString * const kMIN_BUFFERED_DURATION;
extern NSString * const kMAX_BUFFERED_DURATION;

// 状态
typedef enum OpenState{
    OPEN_SUCCESS,
    OPEN_FAILED,
    CLIENT_CANCEL,
} OpenState;

@class BuriedPoint;
// 播放器状态代理
@protocol PlayerStateDelegate <NSObject>
// 成功打开
- (void)openSucceed;
// 链接失败
- (void)connectFailed;
// 展示加载态
- (void)showLoading;
// 隐藏加载态
- (void)hideLoading;
// 使用完成
- (void)onCompletion;
// 埋点回调
- (void)buriedPointCallback:(BuriedPoint*)buriedPoint;
// 重启
- (void)restart;

@end

@class VideoFrame;
/** 音视频同步模块
 * 1. 组合输入模块(解码模块)、音频队列和视频队列
 * 2. 获取音频数据和对应时间戳的视频帧
 * 3. 维护一个解码线程
 * 4. 根据音频数据和视频数据的数量控制解码器工作
 */
@interface AVSynchronizer : NSObject

@property (nonatomic, weak) id<PlayerStateDelegate> playerStateDelegate;

- (instancetype)initWithPlayerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate;

- (OpenState)openFile:(NSString *)path usingHWCodec:(BOOL)usingHWCodec
            parameters:(NSDictionary*)parameters error:(NSError **)perror;
- (OpenState)openFile:(NSString *)path usingHWCodec:(BOOL)usingHWCodec
                 error:(NSError **)perror;

- (void)closeFile;

- (void)audioCallbackFillData:(SInt16 *)outData
                     numFrames:(UInt32)numFrames
                   numChannels:(UInt32)numChannels;

- (VideoFrame*)getCorrectVideoFrame;

- (void)run;
- (BOOL)isOpenInputSuccess;
- (void)interrupt;

- (BOOL)usingHWCodec;

- (BOOL)isPlayCompleted;
- (BOOL)isValid;

- (NSInteger)getAudioSampleRate;
- (NSInteger)getAudioChannels;
- (CGFloat)getVideoFPS;
- (NSInteger)getVideoFrameHeight;
- (NSInteger)getVideoFrameWidth;
- (CGFloat)getDuration;

@end
