//
//  AUAudioRecorder.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUAudioRecorder : NSObject

@property (nonatomic, assign, getter=isEnablePlayWhenRecord) BOOL enablePlayWhenRecord;

- (instancetype)initWithPath:(NSString*)path;
- (void)startRecord;
- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
