//
//  AUExtAudioFile.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUExtAudioFile.h"

@implementation AUExtAudioFile

- (AudioStreamBasicDescription)clientABSD
{
    if (_clientabsdForReader.mBitsPerChannel != 0) {
        return _clientabsdForReader;
    }
    
    return _clientabsdForWriter;
}

- (void)closeFile
{
    if (_audioFile) {
        ExtAudioFileDispose(_audioFile);
        _audioFile = nil;
    }
}

#pragma mark - Help
/**
 * mp3和m4a属于压缩格式；wav和caf属于未压缩格式
 */
- (NSString*)fileExtensionForTypeId:(AudioFileTypeID)typeId {
    switch (typeId) {
        case kAudioFileM4AType:
            return @"m4a";
            break;
        case kAudioFileWAVEType:
            return @"wav";
            break;
        case kAudioFileCAFType:
            return @"caf";
            break;
        case kAudioFileMP3Type:
            return @"mp3";
            break;
        default:
            break;
    }
    
    return nil;
}

- (BOOL)isSurportedFileType:(AudioFileTypeID)type {
    BOOL surport = NO;
    for (NSNumber *vol in [self surportedFileTypes]) {
        if (type == [vol integerValue]) {
            surport = YES;
            break;
        }
    }
    return surport;
}

- (NSArray*)surportedFileTypes {
    return @[
        @(kAudioFileM4AType),
        @(kAudioFileWAVEType),
        @(kAudioFileCAFType),
        @(kAudioFileMP3Type)
    ];
}

+ (AudioFileTypeID)convertFromType:(AUAudioFileType)type {
    NSAssert(type != AUAudioFileTypeLPCM, @"无法处理 PCM数据");
    AudioFileTypeID resultType = kAudioFileM4AType;
    if (type == AUAudioFileTypeM4A) {
        resultType = kAudioFileM4AType;
    } else if (type == AUAudioFileTypeMP3) {
        resultType = kAudioFileMP3Type;
    } else if (type == AUAudioFileTypeCAF) {
        resultType = kAudioFileCAFType;
    } else if (type == AUAudioFileTypeWAV) {
        resultType = kAudioFileWAVEType;
    } else {
        resultType = kAudioFileWAVEType;
    }
    
    return resultType;
}

@end
