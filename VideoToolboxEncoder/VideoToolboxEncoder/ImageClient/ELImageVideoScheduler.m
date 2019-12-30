//
//  ELImageVideoScheduler.m
//  liveDemo
//
//  Created by apple on 16/3/4.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageVideoScheduler.h"
#import "ELImageVideoCamera.h"
#import "ELImageView.h"

#define ASYNC_CONTRAST_ENHANCE 1

@implementation ELImageVideoScheduler
{
    ELImageVideoCamera*                 _videoCamera;   // 摄像头管理类
    ELImageVideoEncoder*                _videoEncoder;  // 视频编码器
    ELImageView*                        _previewView;   // 视频预览视图
}

#pragma mark - init method
- (instancetype)initWithFrame:(CGRect)bounds videoFrameRate:(int)frameRate {
    return [self initWithFrame:bounds videoFrameRate:frameRate disableAutoContrast:NO];;
}

- (instancetype)initWithFrame:(CGRect)bounds
               videoFrameRate:(int)frameRate
          disableAutoContrast:(BOOL)disableAutoContrast {
    if (self = [super init]) {
        _videoCamera = [[ELImageVideoCamera alloc] initWithFPS:frameRate];
        _previewView = [[ELImageView alloc] initWithFrame:bounds];
        [_videoCamera startCapture];
    }
    return self;
}

- (void)startEncodeWithFPS:(float)fps
                maxBitRate:(int)maxBitRate
                avgBitRate:(int)avgBitRate
              encoderWidth:(int)encoderWidth
             encoderHeight:(int)encoderHeight
     encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>)encoderStatusDelegate {
    _videoEncoder = [[ELImageVideoEncoder alloc] initWithFPS:fps
                                                  maxBitRate:maxBitRate
                                                  avgBitRate:avgBitRate
                                                encoderWidth:encoderWidth
                                               encoderHeight:encoderHeight
                                       encoderStatusDelegate:encoderStatusDelegate];
    [_videoCamera addTarget:_videoEncoder];
}

- (void)stopEncode {
    if (_videoEncoder) {
        [_videoCamera removeTarget:_videoEncoder];
        [_videoEncoder stopEncode];
        _videoEncoder = nil;
    }
}

- (UIView*)previewView {
    return _previewView;
}

- (void)startPreview {
    [_videoCamera addTarget:_previewView];
}

- (void)stopPreview {
    [_videoCamera removeTarget:_previewView];
}

- (int)switchFrontBackCamera {
    return [_videoCamera switchFrontBackCamera];
}

@end
