//
//  AUAudioPlayer.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUAudioPlayer : NSObject

- (instancetype)initWithFilePath:(NSString*)filePath;

- (void)start;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
