//
//  VideoToolboxDecoder.h
//  video_player
//
//  Created by apple on 16/9/6.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <VideoToolbox/VideoToolbox.h>
#import "VideoDecoder.h"

@protocol H264DecoderDelegate <NSObject>
@optional
- (void) getDecodeImageData:(CVImageBufferRef) imageBuffer;
@end

@interface VideoToolboxDecoder : VideoDecoder

@property (nonatomic, weak) id <H264DecoderDelegate> delegate;

// 视频格式描述
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
// 解码会话
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;

@end
