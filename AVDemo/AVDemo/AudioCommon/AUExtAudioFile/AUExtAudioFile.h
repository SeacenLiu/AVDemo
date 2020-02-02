//
//  AUExtAudioFile.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUExtAudioFile : NSObject
{
    NSString*                   _filePath;  // 文件路径
    ExtAudioFileRef             _audioFile; // 用于读写文件的文件句柄
    
    // 用于写
    AudioFileTypeID             _fileTypeId;             // 音频文件类型
    AudioStreamBasicDescription _clientabsdForWriter;    // 来源流格式
    AudioStreamBasicDescription _fileDataabsdForWriter;  // 文件流格式
    
    // 用于读
    AudioStreamBasicDescription _clientabsdForReader;    // 目标流格式
    AudioStreamBasicDescription _fileDataabsdForReader;  // 文件流格式
    
    // ==== 用于从文件读取数据 ==== //
    UInt32 _packetSize;
    SInt64 _totalFrames;
    BOOL   _canrepeat;
    // ==== 用于从文件读取数据 ==== //
}

- (AudioStreamBasicDescription)clientABSD;
- (void)closeFile;

#pragma mark - Help
- (NSString*)fileExtensionForTypeId:(AudioFileTypeID)typeId;
- (BOOL)isSurportedFileType:(AudioFileTypeID)type;
+ (AudioFileTypeID)convertFromType:(AUAudioFileType)type;

@end

NS_ASSUME_NONNULL_END
