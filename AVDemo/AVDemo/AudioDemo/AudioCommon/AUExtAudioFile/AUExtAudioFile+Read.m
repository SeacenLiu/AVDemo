//
//  AUExtAudioFile+Read.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/2.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUExtAudioFile+Read.h"


@implementation AUExtAudioFile (Read)

// 用于读文件
- (instancetype)initWithReadPath:(NSString*)path
                            adsb:(AudioStreamBasicDescription)outabsd
                       canrepeat:(BOOL)repeat {
    if (self = [super init]) {
        _filePath = path;
        
        NSURL *fileUrl = [NSURL fileURLWithPath:_filePath];
        
        // 打开指定的音频文件，并且创建一个ExtAudioFileRef对象，用于读取音频数据
        OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)fileUrl, &_audioFile);
        if (status != noErr) {
            NSLog(@"ExtAudioFileOpenURL faile %d",status);
            return nil;
        }
        
        /** 通过ExtAudioFileGetProperty()函数获取文件有关属性，比如编码格式，总共的音频frames数目等等；
         *  这些步骤对于读取数据不是必须的，主要用于打印和分析
         */
        UInt32 size = sizeof(_fileDataabsdForReader);
        status = ExtAudioFileGetProperty(_audioFile,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &size,
                                         &_fileDataabsdForReader);
        if (status != noErr) {
            NSLog(@"ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat fail %d",status);
            return nil;
        }
        size = sizeof(_packetSize);
        ExtAudioFileGetProperty(_audioFile,
                                kExtAudioFileProperty_ClientMaxPacketSize,
                                &size,
                                &_packetSize);
        NSLog(@"每次读取的packet的大小: %u",(unsigned int)_packetSize);
        
        // 备注：_totalFrames一定要是SInt64类型的，否则会出错。
        size = sizeof(_totalFrames);
        ExtAudioFileGetProperty(_audioFile,
                                kExtAudioFileProperty_FileLengthFrames,
                                &size,
                                &_totalFrames);
        NSLog(@"文件中包含的frame数目: %lld",_totalFrames);
        
        // 对于从文件中读数据，app属于客户端。对于向文件中写入数据，app也属于客户端
        // 设置从文件中读取数据后经过解码等步骤后最终输出的数据格式
        _clientabsdForReader = linearPCMStreamDes(outabsd.mFormatFlags,
                                                  _fileDataabsdForReader.mSampleRate,
                                                  _fileDataabsdForReader.mChannelsPerFrame,
                                                  outabsd.mBitsPerChannel/8);
        
        size = sizeof(_clientabsdForReader);
        status = ExtAudioFileSetProperty(_audioFile,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         size,
                                         &_clientabsdForReader);
        if (status != noErr) {
            NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat fail %d",status);
            return nil;
        }
    }
    
    return self;
}


// 从文件中读取音频数据
- (OSStatus)readFrames:(UInt32*)framesNum toBufferData:(AudioBufferList*)bufferlist
{
    if (_canrepeat) {
        SInt64 curFramesOffset = 0;
        // 目前读取指针的postion
        if (ExtAudioFileTell(_audioFile, &curFramesOffset) == noErr) {
            if (curFramesOffset >= _totalFrames) {   // 已经读取完毕
                ExtAudioFileSeek(_audioFile, 0);
                curFramesOffset = 0;
            }
        }
    }
    
    OSStatus status = ExtAudioFileRead(_audioFile, framesNum, bufferlist);
    
    return status;
}

@end
