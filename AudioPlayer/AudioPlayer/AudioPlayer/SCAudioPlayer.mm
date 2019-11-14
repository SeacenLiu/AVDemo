//
//  SCAudioPlayer.m
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "SCAudioPlayer.h"
#import "SCAudioOutput.h"
#import "accompany_decoder_controller.h"

@interface SCAudioPlayer () <SCFillDataDelegate>

@end

@implementation SCAudioPlayer
{
    SCAudioOutput*                            _audioOutput;
    AccompanyDecoderController*             _decoderController;
}

- (instancetype)initWithFilePath:(NSString*)filePath {
    if (self = [super init]) {
        //初始化解码模块，并且从解码模块中取出原始数据
        _decoderController = new AccompanyDecoderController();
        _decoderController->init([filePath cStringUsingEncoding:NSUTF8StringEncoding], 0.2f);
        NSInteger channels = _decoderController->getChannels();
        NSInteger sampleRate = _decoderController->getAudioSampleRate();
        NSInteger bytesPersample = 2;
        _audioOutput = [[SCAudioOutput alloc] initWithChannels:channels sampleRate:sampleRate bytesPerSample:bytesPersample filleDataDelegate:self];
    }
    return self;
}

- (void) start {
    if(_audioOutput){
        [_audioOutput play];
    }
}

- (void) stop {
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

- (NSInteger) fillAudioData:(SInt16*)sampleBuffer
                  numFrames:(NSInteger)frameNum
                numChannels:(NSInteger)channels {
    // 默认填充空数据
    memset(sampleBuffer, 0, frameNum * channels * sizeof(SInt16));
    if(_decoderController) {
        // 从decoderController中取出数据，然后填充进去
        _decoderController->readSamples(sampleBuffer, (int)(frameNum * channels));
    }
    return 1;
}

@end
