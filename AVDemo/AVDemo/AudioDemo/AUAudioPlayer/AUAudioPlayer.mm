//
//  AUAudioPlayer.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioPlayer.h"
#import "AUAudioOutput.h"
// FFmpeg: AVMediaType -> FFAVMediaType
#import "accompany_decoder_controller.h"

@interface AUAudioPlayer () <AUAudioOutputFillDataDelegate>

@end

@implementation AUAudioPlayer
{
    AccompanyDecoderController*             _decoderController;
    AUAudioOutput*                          _audioOutput;
}

- (instancetype)initWithFilePath:(NSString*)filePath {
    if (self = [super init]) {
        // 初始化解码模块，并且从解码模块中取出原始数据
        _decoderController = new AccompanyDecoderController();
        _decoderController->init([filePath cStringUsingEncoding:NSUTF8StringEncoding], 0.2f);
        NSInteger channels = _decoderController->getChannels();
        NSInteger sampleRate = _decoderController->getAudioSampleRate();
        NSInteger bytesPersample = 2;
        
        // 初始化音频输出
        _audioOutput = [[AUAudioOutput alloc] initWithChannels:channels
                                                    sampleRate:sampleRate
                                                bytesPerSample:bytesPersample
                                             filleDataDelegate:self];
    }
    return self;
}

- (void)start {
    if(_audioOutput){
        [_audioOutput play];
    }
}

- (void)stop {
    // 停止AudioOutput
    if(_audioOutput){
        [_audioOutput stop];
        _audioOutput = nil;
    }
    // 停止解码模块
    if (_decoderController != NULL) {
        _decoderController->destroy();
        delete _decoderController;
        _decoderController = NULL;
    }
}

- (NSInteger)fillAudioData:(SInt16*)sampleBuffer
                 numFrames:(NSInteger)frameNum
               numChannels:(NSInteger)channels {
    // sizeof(SInt16) -> 一个采样有两个字节
    // frameNum * channels * sizeof(SInt16) = 帧数 * 声道数 * 字节数
    int size = (int)(frameNum * channels);
    
    // 默认填充空数据
    memset(sampleBuffer, 0, size * sizeof(SInt16));
    
    if (_decoderController) {
        // 从 decoderController 中取出数据，然后填充进去
        _decoderController->readSamples(sampleBuffer, size);
    }
    return 1;
}


@end
