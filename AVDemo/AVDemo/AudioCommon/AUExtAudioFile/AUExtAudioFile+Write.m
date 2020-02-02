//
//  AUExtAudioFile+Write.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/2.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUExtAudioFile+Write.h"

@implementation AUExtAudioFile (Write)

/** 用于写文件 */
- (instancetype)initWithWritePath:(NSString*)path
                             adsb:(AudioStreamBasicDescription)clientabsd
                       fileTypeId:(AUAudioFileType)typeId {
    if (self = [super init]) {
        if (path.length == 0 || clientabsd.mBitsPerChannel == 0 || typeId == 0) {
            return nil;
        }
        
        _filePath = [path stringByDeletingPathExtension];
        _clientabsdForWriter = clientabsd;
        _fileTypeId = [AUExtAudioFile convertFromType:typeId];
        
        if ([self setupExtAudioFile] != noErr) {
            [self closeFile];
        }
    }
    return self;
}

- (OSStatus)setupExtAudioFile {
    NSAssert([self isSurportedFileType:_fileTypeId], @"此格式还不支持");
    NSString *fileExtension = [self fileExtensionForTypeId:_fileTypeId];
    if (fileExtension == nil) {
        NSLog(@"不支持此格式 %@",fileExtension);
        return -1;
    }
    
    _filePath = [_filePath stringByAppendingPathExtension:fileExtension];
    NSURL *recordFileUrl = [NSURL fileURLWithPath:_filePath];
    NSString *fileDir = [recordFileUrl.path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    AudioStreamBasicDescription fileDataDesc={0};
    if (_fileTypeId == kAudioFileM4AType) {     // 保存为m4a格式音频文件
        
        fileDataDesc.mFormatID = kAudioFormatMPEG4AAC;        // m4a的编码方式为aac编码
        fileDataDesc.mFormatFlags = kMPEG4Object_AAC_Main;    // aac的编码级别为 main
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;  // 声道数和输入的PCM一致
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;  // 采样率和输入的PCM一致
        fileDataDesc.mFramesPerPacket = 1024; // 对于m4a格式aac编码方式，他压缩后每个packet包固定有1024个frame(这个值算法规定不可修改)
        fileDataDesc.mBytesPerFrame = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBytesPerPacket = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBitsPerChannel = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mReserved = 0;
    }   // IOS 不支持MP3的编码，尴尬
    else if(_fileTypeId == kAudioFileMP3Type) {  // 保存为mp3格式音频文件,ios不支持
        fileDataDesc.mFormatID = kAudioFormatMPEGLayer3;        // mp3的编码方式为mp3编码
        fileDataDesc.mFormatFlags = 0;    // 对于mp3来说 no flags
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;  // 声道数和输入的PCM一致
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;  // 采样率和输入的PCM一致
        fileDataDesc.mFramesPerPacket = 1152; // 对于mp3格式，他压缩后每个packet包固定有1152个frame(这个值算法规定不可修改)
        fileDataDesc.mBytesPerFrame = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBytesPerPacket = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBitsPerChannel = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mReserved = 0;
    }
    else if (_fileTypeId == kAudioFileCAFType || _fileTypeId == kAudioFileWAVEType) { // 保存为caf或者wav格式文件，不编码
        // 如果不做压缩，则原封不动的保存到音频文件中
        fileDataDesc.mFormatID = kAudioFormatLinearPCM;
        fileDataDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;//_clientabsdForWriter.mFormatFlags;
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;
        fileDataDesc.mFramesPerPacket = _clientabsdForWriter.mFramesPerPacket;
        fileDataDesc.mBytesPerFrame = _clientabsdForWriter.mBytesPerFrame;
        fileDataDesc.mBytesPerPacket = _clientabsdForWriter.mBytesPerPacket;
        fileDataDesc.mBitsPerChannel = _clientabsdForWriter.mBitsPerChannel;
        fileDataDesc.mReserved = 0;
        
        NSLog(@"---------------------- fileDataDesc --------------------------");
        printAudioStreamFormat(fileDataDesc);
    } else {
        NSAssert(YES, @"此格式还不支持");
    }
    
    AudioStreamBasicDescription destinationFormat;
    AudioFormatFlags flags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    destinationFormat = linearPCMStreamDes(flags,
                                           _clientabsdForWriter.mSampleRate,
                                           2,
                                           sizeof(Float32));
    NSLog(@"---------------------- destinationFormat --------------------------");
    printAudioStreamFormat(destinationFormat);
    
    // 根据指定的封装格式，指定的编码方式创建ExtAudioFileRef对象
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)recordFileUrl,
                                                _fileTypeId,
                                                &destinationFormat,
                                                NULL,
                                                kAudioFileFlags_EraseFile,
                                                &_audioFile);
    if (status != noErr) {
        NSLog(@"ExtAudioFileCreateWithURL faile %d",status);
        return -1;
    }
    _fileDataabsdForWriter = fileDataDesc;
    
    // 指定是硬件编码还是软件编码
    UInt32 codec = kAppleSoftwareAudioCodecManufacturer;
    status = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec);
    if (status != noErr) {
        NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_CodecManufacturer fail %d",status);
        return -1;
    }
    
    /** 遇到问题：返回1718449215错误；
     *  解决方案：_clientabsdForWriter格式不正确，比如ASDB中mFormatFlags与所对应的mBytesPerPacket等等不符合，那么会造成这种错误
     */
    // 指定输入给ExtAudioUnitRef的音频PCM数据格式(必须要有)
    status = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_clientabsdForWriter), &_clientabsdForWriter);
    if (status != noErr) {
        NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat fail %d",status);
        return -1;
    }
    
    //  ======= 检查用，非必须 ===== //
//    [self checkWriterStatus];
    
    return noErr;
    
}

- (OSStatus)writeFrames:(UInt32)framesNum
           toBufferData:(AudioBufferList*)bufferlist {
    return [self writeFrames:framesNum
                toBufferData:bufferlist
                       async:NO];
}

- (OSStatus)writeFrames:(UInt32)framesNum
           toBufferData:(AudioBufferList*)bufferlist
                  async:(BOOL)async {
    if (_audioFile == nil) {
        NSLog(@"文件创建未成功 无法写入");
        return -1;
    }
    
    OSStatus status = noErr;
    if (async) {
         status = ExtAudioFileWriteAsync(_audioFile, framesNum, bufferlist);
    } else {
        status = ExtAudioFileWrite(_audioFile, framesNum, bufferlist);
    }
    
    return status;
}

- (void)checkWriterStatus {
    AudioStreamBasicDescription fileFormat;
    UInt32 fileFmtSize = sizeof(fileFormat);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &fileFmtSize, &fileFormat);
    // fileFormat和_fileDataabsdForWriter 应该是一样的
//    printAudioStreamFormat(fileFormat);
//    printAudioStreamFormat(_fileDataabsdForWriter);
    
    // clientFormat和_clientabsdForWriter 应该是一样的
    AudioStreamBasicDescription clientFormat;
    UInt32 clientFmtSize = sizeof(clientFormat);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, &clientFmtSize, &clientFormat);
//    printAudioStreamFormat(clientFormat);
//    printAudioStreamFormat(_clientabsdForWriter);
    
    // 查看编码过程
    AudioConverterRef converter = nil;
    UInt32 dataSize = sizeof(converter);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_AudioConverter, &dataSize, &converter);
    AudioFormatListItem *formatList = nil;
    UInt32 outSize = 0;
    AudioConverterGetProperty(converter, kAudioConverterPropertyFormatList, &outSize, &formatList);
    UInt32 count = outSize / sizeof(AudioFormatListItem);
    for (int i = 0; i<count; i++) {
        AudioFormatListItem format = formatList[i];
        NSLog(@"format: %d",format.mASBD.mFormatID);
    }
}

@end
