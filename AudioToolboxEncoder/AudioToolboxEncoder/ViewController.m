//
//  ViewController.m
//  AudioToolboxEncoder
//
//  Created by SeacenLiu on 2019/12/16.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AudioToolboxEncoder.h"

@interface ViewController ()<AudioToolboxEncoderFillDataDelegate>
{
    AudioToolboxEncoder*            _encoder;
    
    NSString*                       _pcmFilePath;
    NSFileHandle*                   _pcmFileHandle;
    NSString*                       _aacFilePath;
    NSFileHandle*                   _aacFileHandle;
    
    double                          _startEncodeTimeMills; // 精确到毫秒
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)encode:(id)sender {
    NSLog(@"AudioToolbox Encoder Test...");
    _pcmFilePath = [CommonUtil bundlePath:@"vocal.pcm"];
//    _pcmFilePath = [CommonUtil bundlePath:@"problem.pcm"];
    _pcmFileHandle = [NSFileHandle fileHandleForReadingAtPath:_pcmFilePath];
    _aacFilePath = [CommonUtil documentsPath:@"vocal.aac"];
    NSLog(@"%@", _aacFilePath);
    
    // 重新创建文件路径
    [[NSFileManager defaultManager] removeItemAtPath:_aacFilePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:_aacFilePath contents:nil attributes:nil];
    _aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:_aacFilePath];
    
    // 初始化编码器
    NSInteger sampleRate = 44100; // 采样率
    int channels = 2; // 声道数
    int bitRate = 128 * 1024; // 比特率
    _startEncodeTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
    _encoder = [[AudioToolboxEncoder alloc] initWithSampleRate:sampleRate
                                                      channels:channels
                                                       bitRate:bitRate
                                                withADTSHeader:YES
                                             filleDataDelegate:self];
}

// 音频数据读取代理方式
- (UInt32)fillAudioData:(uint8_t*)sampleBuffer
             bufferSize:(UInt32)bufferSize {
    UInt32 ret = 0;
    NSData* data = [_pcmFileHandle readDataOfLength:bufferSize];
    if(data && data.length > 0) {
        memcpy(sampleBuffer, data.bytes, data.length);
        ret = (UInt32)data.length;
    }
    return ret;
}

// 编码器出包代理回调
- (void)outputAACPakcet:(NSData*)data
  presentationTimeMills:(int64_t)presentationTimeMills
                  error:(NSError*)error {
    if (error == nil) { // 将编码好的数据写进文件
        [_aacFileHandle writeData:data];
    } else {
        NSLog(@"Output AAC Packet return Error:%@", error);
    }
}

// 编码完成回调
- (void)onCompletion {
    int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - _startEncodeTimeMills;
    NSLog(@"Encode AAC Waste TimeMills is %d", wasteTimeMills);
    [_aacFileHandle closeFile];
    _aacFileHandle = NULL;
}

@end

