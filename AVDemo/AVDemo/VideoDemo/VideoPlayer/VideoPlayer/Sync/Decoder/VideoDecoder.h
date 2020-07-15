//
//  VideoDecoder.h
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CVImageBuffer.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/pixdesc.h"

typedef enum {
    AudioFrameType,        // 音频帧
    VideoFrameType,        // 视频帧
    iOSCVVideoFrameType,   // CVImageBufferRef 画面帧
} FrameType;

// 埋点对象
@interface BuriedPoint : NSObject
@property (readwrite, nonatomic) long long beginOpen;                 // 开始试图去打开一个直播流的绝对时间
@property (readwrite, nonatomic) float successOpen;                   // 成功打开流花费时间
@property (readwrite, nonatomic) float firstScreenTimeMills;          // 首屏时间
@property (readwrite, nonatomic) float failOpen;                      // 流打开失败花费时间
@property (readwrite, nonatomic) float failOpenType;                  // 流打开失败类型
@property (readwrite, nonatomic) int retryTimes;                      // 打开流重试次数
@property (readwrite, nonatomic) float duration;                      // 拉流时长
@property (readwrite, nonatomic) NSMutableArray* bufferStatusRecords; // 拉流状态
@end

@interface Frame : NSObject
@property (readwrite, nonatomic) FrameType type;     // 类型
@property (readwrite, nonatomic) CGFloat position;   // 当前位置（时间戳）
@property (readwrite, nonatomic) CGFloat duration;   // 当前时长（时间戳）
@end

@interface AudioFrame : Frame
@property (readwrite, nonatomic, strong) NSData *samples;  // 音频数据
@end

@interface VideoFrame : Frame
@property (readwrite, nonatomic) NSUInteger width;          // 视频宽度
@property (readwrite, nonatomic) NSUInteger height;         // 视频高度
@property (readwrite, nonatomic) NSUInteger linesize;       // 每一行的字节数（可能比width大）
// 视频画面数据
@property (readwrite, nonatomic, strong) NSData *luma;      //
@property (readwrite, nonatomic, strong) NSData *chromaB;   //
@property (readwrite, nonatomic, strong) NSData *chromaR;   //
@property (readwrite, nonatomic, strong) id imageBuffer;    // 图像缓冲区
@end

#ifndef SUBSCRIBE_VIDEO_DATA_TIME_OUT
#define SUBSCRIBE_VIDEO_DATA_TIME_OUT               20
#endif
#ifndef NET_WORK_STREAM_RETRY_TIME
#define NET_WORK_STREAM_RETRY_TIME                  3
#endif
#ifndef RTMP_TCURL_KEY
#define RTMP_TCURL_KEY                              @"RTMP_TCURL_KEY"
#endif

#ifndef FPS_PROBE_SIZE_CONFIGURED
#define FPS_PROBE_SIZE_CONFIGURED                   @"FPS_PROBE_SIZE_CONFIGURED"
#endif
#ifndef PROBE_SIZE
#define PROBE_SIZE                                  @"PROBE_SIZE"
#endif
#ifndef MAX_ANALYZE_DURATION_ARRAY
#define MAX_ANALYZE_DURATION_ARRAY                  @"MAX_ANALYZE_DURATION_ARRAY"
#endif

@interface VideoDecoder : NSObject
{
    AVFormatContext*            _formatCtx;
    BOOL                        _isOpenInputSuccess;
    
    BuriedPoint*                _buriedPoint;         // 埋点对象
    
    int                         totalVideoFramecount; // 视频总帧数
    long long                   decodeVideoFrameWasteTimeMills; // 解码视频帧耗时
    
    NSArray*                    _videoStreams;        // 视频流
    NSArray*                    _audioStreams;        // 音频流
    NSInteger                   _videoStreamIndex;    // 视频流索引
    NSInteger                   _audioStreamIndex;    // 音频流索引
    AVCodecContext*             _videoCodecCtx;       // 视频编码上下文
    AVCodecContext*             _audioCodecCtx;       // 音频编码上下文
    CGFloat                     _videoTimeBase;       // 视频时间基线
    CGFloat                     _audioTimeBase;       // 音频时间基线
}

/**
 * 打开音视频文件
 * - 主要负责建立与媒体资源的连接通道
 * - 读取资源中流的格式信息
 */
- (BOOL)openFile:(NSString *)path
       parameter:(NSDictionary*)parameters
           error:(NSError **)perror;

/** 解码方法 */
- (NSArray *)decodeFrames:(CGFloat)minDuration
    decodeVideoErrorState:(int *)decodeVideoErrorState;

/** 子类重写这两个方法 **/
/// 打开视频流
- (BOOL)openVideoStream;
/// 关闭视频流
- (void)closeVideoStream;

- (VideoFrame*)decodeVideo:(AVPacket)packet
                packetSize:(int)pktSize
     decodeVideoErrorState:(int *)decodeVideoErrorState;
    
- (void)closeFile;

- (void)interrupt;

- (BOOL)isOpenInputSuccess;

- (void)triggerFirstScreen;
- (void)addBufferStatusRecord:(NSString*)statusFlag;

- (BuriedPoint*)getBuriedPoint;

- (BOOL)detectInterrupted;
- (BOOL)isEOF;
- (BOOL)isSubscribed;
- (NSUInteger)frameWidth;
- (NSUInteger)frameHeight;
- (CGFloat)sampleRate;
- (NSUInteger)channels;
- (BOOL)validVideo;
- (BOOL)validAudio;
- (CGFloat)getVideoFPS;
- (CGFloat)getDuration;

@end
